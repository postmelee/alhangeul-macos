use std::ffi::{c_char, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;

use rhwp::document_core::queries::rendering::PngExportOptions;
use rhwp::DocumentCore;

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
    doc: DocumentCore,
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
        match DocumentCore::from_bytes(bytes) {
            Ok(doc) => Box::into_raw(Box::new(RhwpHandle { doc })),
            Err(_) => ptr::null_mut(),
        }
    }));

    result.unwrap_or(ptr::null_mut())
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
    const ZERO: RhwpPageSize = RhwpPageSize { width_pt: 0.0, height_pt: 0.0 };
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

        match h.doc.render_page_png_native_with_export_options(page, &options) {
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
            unsafe { *out_len = 0; }
        }
        return ptr::null();
    }
    let h = unsafe { &*handle };
    let idx = (bin_data_id - 1) as usize;
    match h.doc.get_bin_data(idx) {
        Some(data) => {
            unsafe { *out_len = data.len(); }
            data.as_ptr()
        }
        None => {
            unsafe { *out_len = 0; }
            ptr::null()
        }
    }
}

#[no_mangle]
pub extern "C" fn rhwp_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe { drop(CString::from_raw(ptr)); }
    }
}

#[no_mangle]
pub extern "C" fn rhwp_free_bytes(ptr: *mut u8, len: usize) {
    if !ptr.is_null() {
        unsafe { drop(Vec::from_raw_parts(ptr, len, len)); }
    }
}

#[no_mangle]
pub extern "C" fn rhwp_close(handle: *mut RhwpHandle) {
    if !handle.is_null() {
        unsafe { drop(Box::from_raw(handle)); }
    }
}

fn string_to_c(value: String) -> *mut c_char {
    match CString::new(value) {
        Ok(cstr) => cstr.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

fn page_size_from_json(json: &str) -> Option<RhwpPageSize> {
    let value: serde_json::Value = serde_json::from_str(json).ok()?;
    Some(RhwpPageSize {
        width_pt: value.get("width")?.as_f64()?,
        height_pt: value.get("height")?.as_f64()?,
    })
}
