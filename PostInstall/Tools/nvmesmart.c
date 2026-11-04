// Prints NVMe SMART/health data for internal NVMe drives.
// Build: clang -O2 nvmesmart.c -framework IOKit -framework CoreFoundation -o nvmesmart
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/storage/nvme/NVMeSMARTLibExternal.h>
#include <stdio.h>

int main(void) {
	io_iterator_t it;
	if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IONVMeBlockStorageDevice"), &it)) return 1;
	int found = 0;
	for (io_service_t s; (s = IOIteratorNext(it)); IOObjectRelease(s)) {
		IOCFPlugInInterface **plugin = NULL;
		SInt32 score;
		if (IOCreatePlugInInterfaceForService(s, kIONVMeSMARTUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score) || !plugin)
			continue;
		IONVMeSMARTInterface **smart = NULL;
		(*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIONVMeSMARTInterfaceID), (LPVOID *)&smart);
		NVMeSMARTData d = {0};
		if (smart && (*smart)->SMARTReadData(smart, &d) == kIOReturnSuccess) {
			found = 1;
			// Data units are 1000 x 512 bytes.
			printf("critical warning: 0x%02x\n", d.CRITICAL_WARNING);
			printf("temperature:      %d C\n", d.TEMPERATURE - 273);
			printf("available spare:  %u%% (threshold %u%%)\n", d.AVAILABLE_SPARE, d.AVAILABLE_SPARE_THRESHOLD);
			printf("percentage used:  %u%%\n", d.PERCENTAGE_USED);
			printf("data read:        %.2f TB\n", d.DATA_UNITS_READ[0] * 512000.0 / 1e12);
			printf("data written:     %.2f TB\n", d.DATA_UNITS_WRITTEN[0] * 512000.0 / 1e12);
			printf("power cycles:     %llu\n", d.POWER_CYCLES[0]);
			printf("power-on hours:   %llu\n", d.POWER_ON_HOURS[0]);
			printf("unsafe shutdowns: %llu\n", d.UNSAFE_SHUTDOWNS[0]);
			printf("media errors:     %llu\n", d.MEDIA_ERRORS[0]);
			printf("error log entries:%llu\n", d.NUM_ERROR_INFO_LOG_ENTRIES[0]);
		}
		if (smart) (*smart)->Release(smart);
		IODestroyPlugInInterface(plugin);
	}
	IOObjectRelease(it);
	return found ? 0 : 1;
}
