//! TataChatSDK native OpenMLS engine.

use std::ffi::CString;
use std::os::raw::c_char;

mod mls;

/// Keeps every C ABI entry in a host static library that embeds TataChatSDK.
///
/// 宿主应用 iOS links one Rust static library to avoid loading two copies of
/// Rust's runtime and compiler builtins into the same Mach-O image.
#[doc(hidden)]
#[inline(never)]
pub fn retain_ffi() {
    // 中文注释：black_box 只形成链接期可见引用，不执行任何聊天操作，也不分配状态。
    let _ = std::hint::black_box([
        tatachat_sdk_free_string as *const () as usize,
        mls::tatachat_sdk_mls_create_key_package_json as *const () as usize,
        mls::tatachat_sdk_mls_two_party_smoke_json as *const () as usize,
        mls::tatachat_sdk_mls_rekey_state_json as *const () as usize,
        mls::tatachat_sdk_mls_group_create_json as *const () as usize,
        mls::tatachat_sdk_mls_group_add_members_json as *const () as usize,
        mls::tatachat_sdk_mls_group_remove_members_json as *const () as usize,
        mls::tatachat_sdk_mls_group_create_message_json as *const () as usize,
        mls::tatachat_sdk_mls_group_process_json as *const () as usize,
        mls::tatachat_sdk_mls_group_state_json as *const () as usize,
    ]);
}

pub(crate) fn set_error(error_out: *mut *mut c_char, message: &str) {
    if error_out.is_null() {
        return;
    }
    let sanitized = message.replace('\0', " ");
    let value = CString::new(sanitized).expect("sanitized FFI error");
    unsafe {
        *error_out = value.into_raw();
    }
}

pub(crate) fn string_into_raw(value: String, error_out: *mut *mut c_char) -> *mut c_char {
    match CString::new(value) {
        Ok(value) => {
            if !error_out.is_null() {
                unsafe {
                    *error_out = std::ptr::null_mut();
                }
            }
            value.into_raw()
        }
        Err(_) => {
            set_error(error_out, "FFI response contains an embedded null byte");
            std::ptr::null_mut()
        }
    }
}

/// Releases a string returned by any TataChatSDK native function.
///
/// # Safety
///
/// `value` must be null or a pointer returned by this library that has not
/// already been released.
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_free_string(value: *mut c_char) {
    if !value.is_null() {
        drop(CString::from_raw(value));
    }
}
