// Keeps the bluetoothd pages that BlueToolFixup patches resident.
//
// BlueToolFixup patches /usr/sbin/bluetoothd in place from cs_validate_page,
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

// BlueToolFixup 2.7.2 bluetoothd patches on Sequoia, as found on disk and as
// patched in the cache (the 15.4 chipset patch becomes eight NOPs).
static const struct { const char *name; uint8_t len; uint8_t bytes[8]; } kPatterns[] = {
	{"vendor",       7, {0x81, 0xFA, 0x5C, 0x0A, 0x00, 0x00, 0x74}},
	{"vendor*",      7, {0x81, 0xFA, 0x5C, 0x0A, 0x00, 0x00, 0xEB}},
	{"chipset",      7, {0x81, 0xF9, 0xCF, 0x07, 0x00, 0x00, 0x72}},
	{"chipset*",     7, {0x81, 0xF9, 0xCF, 0x07, 0x00, 0x00, 0xEB}},
	{"chipset15.4",  8, {0x81, 0xF9, 0x6F, 0x17, 0x00, 0x00, 0x77, 0x30}},
	{"chipset15.4*", 8, {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90}},
};

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
	static uint8_t buf[CHUNK + 16];
	for (off_t off = start & ~(off_t)(CHUNK - 1); off < end; off += CHUNK) {
		ssize_t got = pread(fd, buf, CHUNK + 16, off);
		if (got < 0) {
			addChunk(off, strerror(errno));
			continue;
		}
		for (ssize_t i = 0; i < got && i < CHUNK; i++)
			for (size_t p = 0; p < sizeof(kPatterns) / sizeof(kPatterns[0]); p++)
				if (i + kPatterns[p].len <= got && !memcmp(buf + i, kPatterns[p].bytes, kPatterns[p].len) &&
					(kPatterns[p].bytes[0] != 0x90 || (i > 0 && buf[i - 1] != 0x90)))
					addChunk(off + i, kPatterns[p].name);
	}
}

int main(int argc, char **argv) {
	const bool listOnly = argc > 1 && !strcmp(argv[1], "-n");
	int fd = open(TARGET, O_RDONLY);
	struct stat st;
	if (fd < 0 || fstat(fd, &st)) { perror(TARGET); return 1; }
	off_t start, end;
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
