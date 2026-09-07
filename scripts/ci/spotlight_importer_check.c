// 실제 CFPlugIn factory/COM interface/metadata callback 검증. 본문은 출력하지 않는다.
#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    assert(argc == 4 && "usage: spotlight_importer_check <bundle> <input> <needle|--no-text>");
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)argv[1], strlen(argv[1]), true);
    CFPlugInRef plugin = CFPlugInCreate(NULL, url);
    assert(plugin);
    CFArrayRef factories = CFPlugInFindFactoriesForPlugInTypeInPlugIn(kMDImporterTypeID, plugin);
    assert(factories && CFArrayGetCount(factories) == 1);
    CFUUIDRef factory = CFArrayGetValueAtIndex(factories, 0);
    IUnknownVTbl **unknown = CFPlugInInstanceCreate(NULL, factory, kMDImporterTypeID);
    assert(unknown);
    void *rejected = (void *)1;
    assert((*unknown)->QueryInterface(unknown, CFUUIDGetUUIDBytes(factory), &rejected) == E_NOINTERFACE);
    assert(rejected == NULL);
    MDImporterInterfaceStruct **importer = NULL;
    assert((*unknown)->QueryInterface(unknown, CFUUIDGetUUIDBytes(kMDImporterInterfaceID), (void **)&importer) == S_OK);
    assert(importer);
    assert((*unknown)->Release(unknown) == 1);
    CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attributes, kMDItemTextContent, CFSTR("StaleSyntheticBody"));
    CFStringRef path = CFStringCreateWithFileSystemRepresentation(NULL, argv[2]);
    assert(path);
    assert((*importer)->ImporterImportData(importer, attributes, CFSTR("com.postmelee.alhangeul.hwp"), path));
    CFTypeRef text = CFDictionaryGetValue(attributes, kMDItemTextContent);
    assert(CFDictionaryGetValue(attributes, kMDItemTitle));
    assert(CFDictionaryGetValue(attributes, kMDItemKind));
    if (strcmp(argv[3], "--no-text") == 0) {
        assert(text && CFEqual(text, kCFNull));
        puts("PASS: previous text explicitly cleared");
    } else {
        assert(text && CFGetTypeID(text) == CFStringGetTypeID());
        CFStringRef needle = CFStringCreateWithCString(NULL, argv[3], kCFStringEncodingUTF8);
        assert(needle && CFStringGetLength(text) > 0);
        if (CFStringGetLength(needle) > 0) {
            assert(CFStringFind(text, needle, 0).location != kCFNotFound);
        }
        CFRelease(needle);
        printf("PASS: factory, interface, body (%ld UTF-16 units)\n", CFStringGetLength(text));
    }
    CFRelease(path);
    CFRelease(attributes);
    assert((*importer)->Release(importer) == 0);
    CFRelease(factories);
    CFRelease(plugin);
    CFRelease(url);
    return 0;
}
