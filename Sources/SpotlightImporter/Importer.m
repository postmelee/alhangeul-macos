// CFPlugIn importer는 UI/앱 수명과 독립 실행한다.
#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreServices/CoreServices.h>
#include <rhwp.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

static CFUUIDRef FactoryID(void) {
    return CFUUIDGetConstantUUIDWithBytes(NULL,
        0x0B, 0x16, 0x01, 0xBF, 0x03, 0x40, 0x4A, 0x83, 0x99, 0x24, 0xE1, 0x48, 0x5E, 0x2D, 0xDD, 0x55);
}

typedef struct {
    MDImporterInterfaceStruct *interface;
    atomic_uint references;
} Importer;

static ULONG AddRef(void *thisInstance) {
    Importer *instance = thisInstance;
    return atomic_fetch_add_explicit(&instance->references, 1, memory_order_relaxed) + 1;
}

static ULONG Release(void *thisInstance) {
    Importer *instance = thisInstance;
    unsigned int previous = atomic_fetch_sub_explicit(&instance->references, 1, memory_order_acq_rel);
    if (previous == 1) {
        CFPlugInRemoveInstanceForFactory(FactoryID());
        free(instance);
    }
    return previous - 1;
}

static HRESULT QueryInterface(void *thisInstance, REFIID iid, LPVOID *output) {
    if (!output) return E_POINTER;
    *output = NULL;
    CFUUIDRef requested = CFUUIDCreateFromUUIDBytes(NULL, iid);
    Boolean supported = requested && (CFEqual(requested, kMDImporterInterfaceID) || CFEqual(requested, IUnknownUUID));
    if (requested) CFRelease(requested);
    if (!supported) return E_NOINTERFACE;
    AddRef(thisInstance);
    *output = thisInstance;
    return S_OK;
}

// regular file을 관찰한 크기까지만 읽으며 변경/초과/특수 파일은 거부한다.
static uint8_t *ReadDocument(CFStringRef path, size_t *length) {
    *length = 0;
    char filename[PATH_MAX];
    if (!CFStringGetFileSystemRepresentation(path, filename, sizeof(filename))) return NULL;
    int fd = open(filename, O_RDONLY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW);
    if (fd < 0) return NULL;
    struct stat before, after;
    uint8_t *bytes = NULL;
    if (fstat(fd, &before) != 0 || !S_ISREG(before.st_mode) || before.st_size <= 0 ||
        (uint64_t)before.st_size > RHWP_TEXT_MAX_INPUT_BYTES) goto finish;
    size_t expected = (size_t)before.st_size;
    bytes = malloc(expected);
    if (!bytes) goto finish;
    size_t count = 0;
    while (count < expected) {
        ssize_t amount = read(fd, bytes + count, expected - count);
        if (amount < 0 && errno == EINTR) continue;
        if (amount <= 0) goto failed;
        count += (size_t)amount;
    }
    uint8_t extra;
    ssize_t more;
    do { more = read(fd, &extra, 1); } while (more < 0 && errno == EINTR);
    if (more != 0 || fstat(fd, &after) != 0 || before.st_size != after.st_size ||
        before.st_mtimespec.tv_sec != after.st_mtimespec.tv_sec ||
        before.st_mtimespec.tv_nsec != after.st_mtimespec.tv_nsec) goto failed;
    *length = count;
    goto finish;
failed:
    free(bytes);
    bytes = NULL;
finish:
    close(fd);
    return bytes;
}

static Boolean ImportData(void *thisInstance, CFMutableDictionaryRef attributes,
                          CFStringRef contentTypeUTI, CFStringRef path) {
    (void)thisInstance;
    (void)contentTypeUTI; // 등록 UTI와 무관하게 실제 bytes로 형식/보호를 판별한다.
    if (!attributes || !path || CFGetTypeID(path) != CFStringGetTypeID()) return false;
    // 실패·보호·빈 결과를 다시 색인할 때 이전 평문을 제거한다 (MDImporter.h 계약).
    CFDictionarySetValue(attributes, kMDItemTextContent, kCFNull);
    CFDictionarySetValue(attributes, kMDItemKind, CFSTR("한글 문서"));
    CFURLRef url = CFURLCreateWithFileSystemPath(NULL, path, kCFURLPOSIXPathStyle, false);
    if (url) {
        CFURLRef stem = CFURLCreateCopyDeletingPathExtension(NULL, url);
        CFStringRef title = stem ? CFURLCopyLastPathComponent(stem) : NULL;
        if (title) { CFDictionarySetValue(attributes, kMDItemTitle, title); CFRelease(title); }
        if (stem) CFRelease(stem);
        CFRelease(url);
    }
    size_t inputLength = 0;
    uint8_t *input = ReadDocument(path, &inputLength);
    if (!input) return true;
    uint8_t *output = NULL;
    size_t outputLength = 0;
    enum RhwpTextStatus status = rhwp_extract_text_utf8(input, inputLength, &output, &outputLength);
    free(input);
    if ((status == RHWP_TEXT_OK || status == RHWP_TEXT_TRUNCATED) && output && outputLength) {
        CFStringRef text = CFStringCreateWithBytes(NULL, output, (CFIndex)outputLength, kCFStringEncodingUTF8, false);
        if (text) { CFDictionarySetValue(attributes, kMDItemTextContent, text); CFRelease(text); }
    }
    if (output) rhwp_free_bytes(output, outputLength);
    return true;
}

static MDImporterInterfaceStruct Interface = {
    NULL, QueryInterface, AddRef, Release, ImportData
};

__attribute__((visibility("default")))
void *AlhangeulImporterFactory(CFAllocatorRef allocator, CFUUIDRef typeID) {
    (void)allocator;
    if (!typeID || !CFEqual(typeID, kMDImporterTypeID)) return NULL;
    Importer *instance = calloc(1, sizeof(Importer));
    if (!instance) return NULL;
    instance->interface = &Interface;
    atomic_init(&instance->references, 1);
    CFPlugInAddInstanceForFactory(FactoryID());
    return instance;
}
