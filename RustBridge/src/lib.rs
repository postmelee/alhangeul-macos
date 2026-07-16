use std::ffi::{c_char, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;

use rhwp::document_core::queries::rendering::PngExportOptions;
use rhwp::wasm_api::HwpDocument;

macro_rules! ffi_guard {
    ($handle:expr, $default:expr, $body:expr) => {{
        if $handle.is_null() {
            return $default;
        }
        match catch_unwind(AssertUnwindSafe(|| $body)) {
            Ok(v) => v,
            Err(_) => $default,
        }
    }};
}

pub struct RhwpHandle {
    doc: HwpDocument,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct RhwpPageSize {
    pub width_pt: f64,
    pub height_pt: f64,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[allow(non_camel_case_types)]
pub enum RhwpRenderStatus {
    RHWP_RENDER_OK = 0,
    RHWP_RENDER_INVALID_HANDLE = 1,
    RHWP_RENDER_INVALID_OUTPUT = 2,
    RHWP_RENDER_INVALID_PAGE_INDEX = 3,
    RHWP_RENDER_INVALID_OPTIONS = 4,
    RHWP_RENDER_FAILURE = 5,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
#[allow(non_camel_case_types)]
pub enum RhwpExternalImageStatus {
    RHWP_EXTERNAL_IMAGE_OK = 0,
    RHWP_EXTERNAL_IMAGE_INVALID_HANDLE = 1,
    RHWP_EXTERNAL_IMAGE_INVALID_INPUT = 2,
    RHWP_EXTERNAL_IMAGE_INVALID_UTF8 = 3,
    RHWP_EXTERNAL_IMAGE_REFERENCE_NOT_FOUND = 4,
    RHWP_EXTERNAL_IMAGE_ALREADY_LOADED = 5,
    RHWP_EXTERNAL_IMAGE_FAILURE = 6,
}

#[no_mangle]
pub extern "C" fn rhwp_extract_thumbnail(
    data: *const u8,
    len: usize,
    out_data: *mut *mut u8,
    out_len: *mut usize,
    out_width: *mut u32,
    out_height: *mut u32,
    out_format: *mut *mut c_char,
) -> bool {
    if data.is_null()
        || len == 0
        || out_data.is_null()
        || out_len.is_null()
        || out_width.is_null()
        || out_height.is_null()
        || out_format.is_null()
    {
        return false;
    }

    unsafe {
        *out_data = ptr::null_mut();
        *out_len = 0;
        *out_width = 0;
        *out_height = 0;
        *out_format = ptr::null_mut();
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let bytes = unsafe { std::slice::from_raw_parts(data, len) };
        let thumb = match rhwp::parser::extract_thumbnail_only(bytes) {
            Some(thumb) => thumb,
            None => return false,
        };

        let format = match CString::new(thumb.format) {
            Ok(format) => format,
            Err(_) => return false,
        };
        let mut owned = thumb.data.into_boxed_slice();
        let owned_len = owned.len();
        let owned_ptr = owned.as_mut_ptr();
        std::mem::forget(owned);

        unsafe {
            *out_data = owned_ptr;
            *out_len = owned_len;
            *out_width = thumb.width;
            *out_height = thumb.height;
            *out_format = format.into_raw();
        }
        true
    }));

    result.unwrap_or(false)
}

#[no_mangle]
pub extern "C" fn rhwp_open(data: *const u8, len: usize) -> *mut RhwpHandle {
    if data.is_null() || len == 0 {
        return ptr::null_mut();
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let bytes = unsafe { std::slice::from_raw_parts(data, len) };
        match HwpDocument::from_bytes(bytes) {
            Ok(doc) => Box::into_raw(Box::new(RhwpHandle { doc })),
            Err(_) => ptr::null_mut(),
        }
    }));

    result.unwrap_or(ptr::null_mut())
}

#[no_mangle]
pub extern "C" fn rhwp_set_file_name_utf8(
    handle: *mut RhwpHandle,
    name: *const u8,
    name_len: usize,
) -> RhwpExternalImageStatus {
    if handle.is_null() {
        return RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_HANDLE;
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let name = match unsafe { borrowed_input_utf8(name, name_len, true) } {
            Ok(name) => name,
            Err(status) => return status,
        };
        let h = unsafe { &mut *handle };
        h.doc.set_file_name(name);
        RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_OK
    }));

    result.unwrap_or(RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_FAILURE)
}

#[no_mangle]
pub extern "C" fn rhwp_external_image_refs_json(handle: *const RhwpHandle) -> *mut c_char {
    ffi_guard!(handle, ptr::null_mut(), {
        let h = unsafe { &*handle };
        string_to_c(h.doc.get_external_image_references())
    })
}

#[no_mangle]
pub extern "C" fn rhwp_inject_external_image_by_key(
    handle: *mut RhwpHandle,
    key: *const u8,
    key_len: usize,
    data: *const u8,
    data_len: usize,
    display_path: *const u8,
    display_path_len: usize,
) -> RhwpExternalImageStatus {
    if handle.is_null() {
        return RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_HANDLE;
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let key = match unsafe { borrowed_input_utf8(key, key_len, false) } {
            Ok(key) => key,
            Err(status) => return status,
        };
        let data = match unsafe { borrowed_input_bytes(data, data_len, false) } {
            Ok(data) => data,
            Err(status) => return status,
        };
        let display_path =
            match unsafe { borrowed_input_utf8(display_path, display_path_len, true) } {
                Ok(display_path) => display_path,
                Err(status) => return status,
            };

        let h = unsafe { &mut *handle };
        let refs_json = h.doc.get_external_image_references();
        let loaded = match external_image_reference_loaded(&refs_json, key) {
            Ok(Some(loaded)) => loaded,
            Ok(None) => {
                return RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_REFERENCE_NOT_FOUND;
            }
            Err(()) => return RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_FAILURE,
        };
        if loaded {
            return RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_ALREADY_LOADED;
        }

        if h.doc.inject_external_image_by_key(key, data, display_path) == 1 {
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_OK
        } else {
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_FAILURE
        }
    }));

    result.unwrap_or(RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_FAILURE)
}

#[no_mangle]
pub extern "C" fn rhwp_page_count(handle: *const RhwpHandle) -> u32 {
    if handle.is_null() {
        return 0;
    }
    let h = unsafe { &*handle };
    h.doc.page_count()
}

#[no_mangle]
pub extern "C" fn rhwp_page_size(handle: *const RhwpHandle, page: u32) -> RhwpPageSize {
    const ZERO: RhwpPageSize = RhwpPageSize {
        width_pt: 0.0,
        height_pt: 0.0,
    };
    ffi_guard!(handle, ZERO, {
        let h = unsafe { &*handle };
        let json = match h.doc.get_page_info_native(page) {
            Ok(json) => json,
            Err(_) => return ZERO,
        };
        page_size_from_json(&json).unwrap_or(ZERO)
    })
}

#[no_mangle]
pub extern "C" fn rhwp_render_page_svg(handle: *const RhwpHandle, page: u32) -> *mut c_char {
    ffi_guard!(handle, ptr::null_mut(), {
        let h = unsafe { &*handle };
        match h.doc.render_page_svg_native(page) {
            Ok(svg) => string_to_c(svg),
            Err(_) => ptr::null_mut(),
        }
    })
}

#[no_mangle]
pub extern "C" fn rhwp_render_page_tree(handle: *const RhwpHandle, page: u32) -> *mut c_char {
    ffi_guard!(handle, ptr::null_mut(), {
        let h = unsafe { &*handle };
        match h.doc.build_page_render_tree(page) {
            Ok(tree) => match serde_json::to_string(&tree.root) {
                Ok(json) => string_to_c(json),
                Err(_) => ptr::null_mut(),
            },
            Err(_) => ptr::null_mut(),
        }
    })
}

#[no_mangle]
pub extern "C" fn rhwp_page_overlay_images(handle: *const RhwpHandle, page: u32) -> *mut c_char {
    ffi_guard!(handle, ptr::null_mut(), {
        let h = unsafe { &*handle };
        match h.doc.get_page_overlay_images_native(page) {
            Ok(json) => string_to_c(json),
            Err(_) => ptr::null_mut(),
        }
    })
}

#[no_mangle]
pub extern "C" fn rhwp_render_page_png(
    handle: *const RhwpHandle,
    page: u32,
    scale: f64,
    max_dimension: u32,
    out_data: *mut *mut u8,
    out_len: *mut usize,
) -> RhwpRenderStatus {
    if out_data.is_null() || out_len.is_null() {
        unsafe {
            if !out_data.is_null() {
                *out_data = ptr::null_mut();
            }
            if !out_len.is_null() {
                *out_len = 0;
            }
        }
        return RhwpRenderStatus::RHWP_RENDER_INVALID_OUTPUT;
    }

    unsafe {
        *out_data = ptr::null_mut();
        *out_len = 0;
    }

    if handle.is_null() {
        return RhwpRenderStatus::RHWP_RENDER_INVALID_HANDLE;
    }
    if !scale.is_finite() || scale < 0.0 || max_dimension > i32::MAX as u32 {
        return RhwpRenderStatus::RHWP_RENDER_INVALID_OPTIONS;
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let h = unsafe { &*handle };
        if page >= h.doc.page_count() {
            return RhwpRenderStatus::RHWP_RENDER_INVALID_PAGE_INDEX;
        }

        let options = PngExportOptions {
            scale: if scale == 0.0 { None } else { Some(scale) },
            max_dimension: if max_dimension == 0 {
                None
            } else {
                Some(max_dimension as i32)
            },
            vlm_target: None,
            dpi: None,
            font_paths: Vec::new(),
        };

        match h
            .doc
            .render_page_png_native_with_export_options(page, &options)
        {
            Ok(bytes) if !bytes.is_empty() => {
                let mut owned = bytes.into_boxed_slice();
                let owned_len = owned.len();
                let owned_ptr = owned.as_mut_ptr();
                std::mem::forget(owned);

                unsafe {
                    *out_data = owned_ptr;
                    *out_len = owned_len;
                }
                RhwpRenderStatus::RHWP_RENDER_OK
            }
            Ok(_) | Err(_) => RhwpRenderStatus::RHWP_RENDER_FAILURE,
        }
    }));

    result.unwrap_or(RhwpRenderStatus::RHWP_RENDER_FAILURE)
}

#[no_mangle]
pub extern "C" fn rhwp_image_data(
    handle: *const RhwpHandle,
    bin_data_id: u16,
    out_len: *mut usize,
) -> *const u8 {
    if handle.is_null() || out_len.is_null() || bin_data_id == 0 {
        if !out_len.is_null() {
            unsafe {
                *out_len = 0;
            }
        }
        return ptr::null();
    }
    let h = unsafe { &*handle };
    let idx = (bin_data_id - 1) as usize;
    match h.doc.get_bin_data(idx) {
        Some(data) => {
            unsafe {
                *out_len = data.len();
            }
            data.as_ptr()
        }
        None => {
            unsafe {
                *out_len = 0;
            }
            ptr::null()
        }
    }
}

#[no_mangle]
pub extern "C" fn rhwp_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}

#[no_mangle]
pub extern "C" fn rhwp_free_bytes(ptr: *mut u8, len: usize) {
    if !ptr.is_null() {
        unsafe {
            drop(Vec::from_raw_parts(ptr, len, len));
        }
    }
}

#[no_mangle]
pub extern "C" fn rhwp_close(handle: *mut RhwpHandle) {
    if !handle.is_null() {
        unsafe {
            drop(Box::from_raw(handle));
        }
    }
}

fn string_to_c(value: String) -> *mut c_char {
    match CString::new(value) {
        Ok(cstr) => cstr.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

fn external_image_reference_loaded(refs_json: &str, key: &str) -> Result<Option<bool>, ()> {
    let refs: serde_json::Value = serde_json::from_str(refs_json).map_err(|_| ())?;
    let references = refs.as_array().ok_or(())?;
    let Some(reference) = references
        .iter()
        .find(|reference| reference.get("key").and_then(|value| value.as_str()) == Some(key))
    else {
        return Ok(None);
    };
    let loaded = reference
        .get("loaded")
        .and_then(|value| value.as_bool())
        .ok_or(())?;
    Ok(Some(loaded))
}

/// Borrows a caller-owned FFI buffer for the duration of the current call.
///
/// # Safety
/// When `len > 0`, `data` must point to at least `len` readable bytes that
/// remain valid for the returned lifetime.
unsafe fn borrowed_input_bytes<'a>(
    data: *const u8,
    len: usize,
    allow_empty: bool,
) -> Result<&'a [u8], RhwpExternalImageStatus> {
    if len == 0 {
        return if allow_empty {
            Ok(&[])
        } else {
            Err(RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_INPUT)
        };
    }
    if data.is_null() {
        return Err(RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_INPUT);
    }

    Ok(unsafe { std::slice::from_raw_parts(data, len) })
}

unsafe fn borrowed_input_utf8<'a>(
    data: *const u8,
    len: usize,
    allow_empty: bool,
) -> Result<&'a str, RhwpExternalImageStatus> {
    let bytes = unsafe { borrowed_input_bytes(data, len, allow_empty) }?;
    std::str::from_utf8(bytes)
        .map_err(|_| RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_UTF8)
}

fn page_size_from_json(json: &str) -> Option<RhwpPageSize> {
    let value: serde_json::Value = serde_json::from_str(json).ok()?;
    Some(RhwpPageSize {
        width_pt: value.get("width")?.as_f64()?,
        height_pt: value.get("height")?.as_f64()?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;
    use std::fs;
    use std::path::PathBuf;

    struct TestHandle(*mut RhwpHandle);

    impl Drop for TestHandle {
        fn drop(&mut self) {
            rhwp_close(self.0);
        }
    }

    fn open_fixture() -> TestHandle {
        let fixture = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../samples/basic/KTX.hwp");
        let data = fs::read(fixture).expect("KTX fixture should be readable");
        let handle = rhwp_open(data.as_ptr(), data.len());
        assert!(!handle.is_null());
        TestHandle(handle)
    }

    #[test]
    fn filename_context_validates_handle_and_utf8() {
        assert_eq!(
            rhwp_set_file_name_utf8(ptr::null_mut(), ptr::null(), 0),
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_HANDLE
        );

        let handle = open_fixture();
        assert_eq!(
            rhwp_set_file_name_utf8(handle.0, ptr::null(), 0),
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_OK
        );

        let name = b"KTX.hwp";
        assert_eq!(
            rhwp_set_file_name_utf8(handle.0, name.as_ptr(), name.len()),
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_OK
        );

        let invalid_utf8 = [0xff];
        assert_eq!(
            rhwp_set_file_name_utf8(handle.0, invalid_utf8.as_ptr(), invalid_utf8.len()),
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_UTF8
        );
        assert_eq!(
            rhwp_set_file_name_utf8(handle.0, ptr::null(), 1),
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_INPUT
        );
    }

    #[test]
    fn external_refs_json_has_owned_string_lifecycle() {
        assert!(rhwp_external_image_refs_json(ptr::null()).is_null());

        let handle = open_fixture();
        assert!(rhwp_page_count(handle.0) > 0);
        let json_ptr = rhwp_external_image_refs_json(handle.0);
        assert!(!json_ptr.is_null());
        let json = unsafe { CStr::from_ptr(json_ptr) }
            .to_str()
            .expect("external refs should be UTF-8")
            .to_owned();
        rhwp_free_string(json_ptr);

        let value: serde_json::Value =
            serde_json::from_str(&json).expect("external refs should be valid JSON");
        assert!(value.is_array());
    }

    #[test]
    fn injection_validates_inputs_and_missing_reference() {
        let key = b"not-a-reference";
        let data = [0_u8];
        assert_eq!(
            rhwp_inject_external_image_by_key(
                ptr::null_mut(),
                key.as_ptr(),
                key.len(),
                data.as_ptr(),
                data.len(),
                ptr::null(),
                0,
            ),
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_HANDLE
        );

        let handle = open_fixture();
        assert_eq!(
            rhwp_inject_external_image_by_key(
                handle.0,
                ptr::null(),
                0,
                data.as_ptr(),
                data.len(),
                ptr::null(),
                0,
            ),
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_INPUT
        );
        assert_eq!(
            rhwp_inject_external_image_by_key(
                handle.0,
                key.as_ptr(),
                key.len(),
                ptr::null(),
                0,
                ptr::null(),
                0,
            ),
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_INPUT
        );

        let invalid_utf8 = [0xff];
        assert_eq!(
            rhwp_inject_external_image_by_key(
                handle.0,
                invalid_utf8.as_ptr(),
                invalid_utf8.len(),
                data.as_ptr(),
                data.len(),
                ptr::null(),
                0,
            ),
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_UTF8
        );
        assert_eq!(
            rhwp_inject_external_image_by_key(
                handle.0,
                key.as_ptr(),
                key.len(),
                data.as_ptr(),
                data.len(),
                invalid_utf8.as_ptr(),
                invalid_utf8.len(),
            ),
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_INVALID_UTF8
        );
        assert_eq!(
            rhwp_inject_external_image_by_key(
                handle.0,
                key.as_ptr(),
                key.len(),
                data.as_ptr(),
                data.len(),
                ptr::null(),
                0,
            ),
            RhwpExternalImageStatus::RHWP_EXTERNAL_IMAGE_REFERENCE_NOT_FOUND
        );
    }

    #[test]
    fn external_reference_lookup_reads_loaded_state() {
        let refs = r#"[
            {"key":"binData:1","loaded":false},
            {"key":"binData:2","loaded":true}
        ]"#;

        assert_eq!(
            external_image_reference_loaded(refs, "binData:1"),
            Ok(Some(false))
        );
        assert_eq!(
            external_image_reference_loaded(refs, "binData:2"),
            Ok(Some(true))
        );
        assert_eq!(external_image_reference_loaded(refs, "binData:3"), Ok(None));
        assert_eq!(
            external_image_reference_loaded(r#"[{"key":"binData:1"}]"#, "binData:1"),
            Err(())
        );
        assert_eq!(external_image_reference_loaded("{}", "binData:1"), Err(()));
    }
}
