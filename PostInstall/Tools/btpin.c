// Keeps the bluetoothd pages that BlueToolFixup and BTLEAdvFixup patch resident.
//
// Both kexts patch /usr/sbin/bluetoothd in place from cs_validate_page,
// so the patched bytes live in the shared file cache. bluetoothd is stored
// APFS-compressed on the sealed system volume, in 16 KiB chunks that are hashed
// as a whole. When memory pressure evicts part of a chunk and it is paged back
// in, APFS verifies the chunk against the seal with the still-resident patched
// page in it, reports "Data hash mismatch", and bluetoothd dies with SIGBUS.
// Wiring every chunk that holds a patch keeps the chunk resident as a unit, so
// it is never paged in again while patched.
//
// Build: clang -O2 -Wall btpin.c -o btpin && codesign -s - btpin
// Run as a LaunchDaemon (see btpin.plist); `btpin -n` only lists the chunks.
#include <errno.h>
#include <fcntl.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <libkern/OSByteOrder.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#define TARGET "/usr/sbin/bluetoothd"
#define CHUNK 16384
#define MAX_CHUNKS 64
#define MAX_PATTERN 32

// bluetoothd patch sites as found on disk and as patched in the cache. "??"
// matches any byte: the rel32 of a call, which differs between builds.
static const struct { const char *name, *hex; } kPatterns[] = {
	// BlueToolFixup 2.7.2 on Sequoia (the 15.4 chipset patch becomes eight NOPs).
	{"vendor",       "81 FA 5C 0A 00 00 74"},
	{"vendor*",      "81 FA 5C 0A 00 00 EB"},
	{"chipset",      "81 F9 CF 07 00 00 72"},
	{"chipset*",     "81 F9 CF 07 00 00 EB"},
	{"chipset15.4",  "81 F9 6F 17 00 00 77 30"},
	{"chipset15.4*", "90 90 90 90 90 90 90 90"},
	// BTLEAdvFixup 0.9.1 (ForbiddenItlwm, -btleadv): LE advertising and scanning
	// gates, random address and extended connection checks.
	{"btle-adv",     "84 C0 0F 84 38 01 00 00 E8 ?? ?? ?? ?? 48 8B 08 48 89 C7 FF 91 C0 07 00 00 41 89 C6"},
	{"btle-scan",    "84 C0 0F 84 38 01 00 00 E8 ?? ?? ?? ?? 48 8B 08 48 89 C7 FF 91 48 08 00 00 41 89 C6"},
	{"btle-gate*",   "84 C0 90 90 90 90 90 90 E8 ?? ?? ?? ?? 48 8B 08 48 89 C7 B8 01 00 00 00 90 41 89 C6"},
	{"btle-rand",    "83 B8 F8 02 00 00 03 77 23 31 FF E8 ?? ?? ?? ??"},
	{"btle-rand*",   "83 B8 F8 02 00 00 03 77 23 90 90 90 90 90 90 90"},
	{"btle-ext",     "0F B6 BD 5E FF FF FF E8 ?? ?? ?? ??"},
	{"btle-ext*",    "BF 01 00 00 00 90 90 E8 ?? ?? ?? ??"},
};
#define NPATTERNS (sizeof(kPatterns) / sizeof(kPatterns[0]))
static uint8_t patBytes[NPATTERNS][MAX_PATTERN], patMask[NPATTERNS][MAX_PATTERN];
static size_t patLen[NPATTERNS];

static void parsePatterns(void) {
	for (size_t p = 0; p < NPATTERNS; p++)
		for (const char *h = kPatterns[p].hex; *h && patLen[p] < MAX_PATTERN; h += h[2] ? 3 : 2) {
			const bool wild = h[0] == '?';
			patBytes[p][patLen[p]] = wild ? 0 : (uint8_t)strtoul((char[]){h[0], h[1], 0}, NULL, 16);
			patMask[p][patLen[p]++] = wild ? 0 : 0xFF;
		}
}

static bool matches(const uint8_t *at, size_t p) {
	for (size_t i = 0; i < patLen[p]; i++)
		if ((at[i] & patMask[p][i]) != patBytes[p][i]) return false;
	return true;
}

static off_t chunks[MAX_CHUNKS];
static bool locked[MAX_CHUNKS];
static int nchunks;

static void addChunk(off_t off, const char *why) {
	off &= ~(off_t)(CHUNK - 1);
	for (int i = 0; i < nchunks; i++)
		if (chunks[i] == off) return;
	if (nchunks == MAX_CHUNKS) return;
	chunks[nchunks++] = off;
	fprintf(stderr, "btpin: chunk 0x%llx (%s)\n", (unsigned long long)off, why);
}

// Returns the file range of the x86_64 slice (the whole file if thin).
static bool x86Slice(int fd, off_t size, off_t *start, off_t *end) {
	struct fat_header fh;
	if (pread(fd, &fh, sizeof(fh), 0) != sizeof(fh)) return false;
	if (OSSwapBigToHostInt32(fh.magic) != FAT_MAGIC) {
		*start = 0; *end = size;
		return true;
	}
	uint32_t n = OSSwapBigToHostInt32(fh.nfat_arch);
	for (uint32_t i = 0; i < n && i < 8; i++) {
		struct fat_arch fa;
		if (pread(fd, &fa, sizeof(fa), sizeof(fh) + i * sizeof(fa)) != sizeof(fa)) return false;
		if ((cpu_type_t)OSSwapBigToHostInt32(fa.cputype) == CPU_TYPE_X86_64) {
			*start = OSSwapBigToHostInt32(fa.offset);
			*end = *start + OSSwapBigToHostInt32(fa.size);
			return true;
		}
	}
	return false;
}

// Finds the chunks holding a patch site. A chunk that cannot be read is
// already failing verification, so it is wired as well once it can be.
static void scan(int fd, off_t start, off_t end) {
	static uint8_t buf[CHUNK + MAX_PATTERN];
	for (off_t off = start & ~(off_t)(CHUNK - 1); off < end; off += CHUNK) {
		ssize_t got = pread(fd, buf, CHUNK + MAX_PATTERN, off);
		if (got < 0) {
			addChunk(off, strerror(errno));
			continue;
		}
		for (ssize_t i = 0; i < got && i < CHUNK; i++)
			for (size_t p = 0; p < NPATTERNS; p++)
				if (i + (ssize_t)patLen[p] <= got && matches(buf + i, p) &&
					(patBytes[p][0] != 0x90 || (i > 0 && buf[i - 1] != 0x90)))
					addChunk(off + i, kPatterns[p].name);
	}
}

int main(int argc, char **argv) {
	const bool listOnly = argc > 1 && !strcmp(argv[1], "-n");
	int fd = open(TARGET, O_RDONLY);
	struct stat st;
	if (fd < 0 || fstat(fd, &st)) { perror(TARGET); return 1; }
	off_t start, end;
	parsePatterns();
	if (!x86Slice(fd, st.st_size, &start, &end)) { fprintf(stderr, "btpin: no x86_64 slice\n"); return 1; }
	scan(fd, start, end);
	if (listOnly || !nchunks) return nchunks ? 0 : 1;

	uint8_t *base = mmap(NULL, st.st_size, PROT_READ, MAP_SHARED, fd, 0);
	if (base == MAP_FAILED) { perror("mmap"); return 1; }
	for (;;) {
		int pending = 0;
		for (int i = 0; i < nchunks; i++) {
			if (locked[i]) continue;
			if (mlock(base + chunks[i], CHUNK) == 0) {
				locked[i] = true;
				fprintf(stderr, "btpin: wired 0x%llx\n", (unsigned long long)chunks[i]);
			} else {
				pending++;
			}
		}
		// A chunk whose patched page is resident while the rest was evicted
		// cannot be paged in until that page goes too; keep retrying.
		sleep(pending ? 10 : 3600);
	}
}
