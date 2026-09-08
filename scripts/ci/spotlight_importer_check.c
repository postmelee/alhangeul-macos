// 실제 CFPlugIn factory/COM interface/metadata callback 검증. 본문은 출력하지 않는다.
#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

// assert 내부의 callback 호출은 NDEBUG에서 사라진다. 검증과 부수 효과를 항상 실행한다.
#define REQUIRE(condition) do { \
    if (!(condition)) { \
        fprintf(stderr, "FAIL: line %d: %s\n", __LINE__, #condition); \
        return EXIT_FAILURE; \
    } \
} while (0)

int main(int argc, char **argv) {
    REQUIRE(argc == 4 && "usage: spotlight_importer_check <bundle> <input> <needle|--no-text>");
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)argv[1], strlen(argv[1]), true);
    CFPlugInRef plugin = CFPlugInCreate(NULL, url);
    REQUIRE(plugin);
    CFArrayRef factories = CFPlugInFindFactoriesForPlugInTypeInPlugIn(kMDImporterTypeID, plugin);
    REQUIRE(factories && CFArrayGetCount(factories) == 1);
    CFUUIDRef factory = CFArrayGetValueAtIndex(factories, 0);
    IUnknownVTbl **unknown = CFPlugInInstanceCreate(NULL, factory, kMDImporterTypeID);
    REQUIRE(unknown);
    void *rejected = (void *)1;
    REQUIRE((*unknown)->QueryInterface(unknown, CFUUIDGetUUIDBytes(factory), &rejected) == E_NOINTERFACE);
    REQUIRE(rejected == NULL);
    MDImporterInterfaceStruct **importer = NULL;
    REQUIRE((*unknown)->QueryInterface(unknown, CFUUIDGetUUIDBytes(kMDImporterInterfaceID), (void **)&importer) == S_OK);
    REQUIRE(importer);
    REQUIRE((*unknown)->Release(unknown) == 1);
    CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attributes, kMDItemTextContent, CFSTR("StaleSyntheticBody"));
    CFStringRef path = CFStringCreateWithFileSystemRepresentation(NULL, argv[2]);
    REQUIRE(path);
    REQUIRE((*importer)->ImporterImportData(importer, attributes, CFSTR("com.postmelee.alhangeul.hwp"), path));
    CFTypeRef text = CFDictionaryGetValue(attributes, kMDItemTextContent);
    REQUIRE(CFDictionaryGetValue(attributes, kMDItemTitle));
    REQUIRE(CFDictionaryGetValue(attributes, kMDItemKind));
    if (strcmp(argv[3], "--no-text") == 0) {
        REQUIRE(text && CFEqual(text, kCFNull));
        puts("PASS: previous text explicitly cleared");
    } else {
        REQUIRE(text && CFGetTypeID(text) == CFStringGetTypeID());
        CFStringRef needle = CFStringCreateWithCString(NULL, argv[3], kCFStringEncodingUTF8);
        REQUIRE(needle && CFStringGetLength(text) > 0);
        if (CFStringGetLength(needle) > 0) {
            REQUIRE(CFStringFind(text, needle, 0).location != kCFNotFound);
        }
        CFRelease(needle);
        printf("PASS: factory, interface, body (%ld UTF-16 units)\n", CFStringGetLength(text));
    }
    CFRelease(path);
    CFRelease(attributes);
    REQUIRE((*importer)->Release(importer) == 0);
    CFRelease(factories);
    CFRelease(plugin);
    CFRelease(url);
    return 0;
}
