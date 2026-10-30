//! 仅通过现有C ABI验证错误返回及字符串所有权，不公开MLS内部模块。
use std::{ffi::CStr, os::raw::c_char};
extern "C" {
    fn tatachat_sdk_mls_identity_json(
        request: *const c_char,
        error: *mut *mut c_char,
    ) -> *mut c_char;
}
#[test]
fn invalid_request_returns_owned_error_without_crossing_the_abi() {
    tatachat_sdk::retain_ffi();
    let mut error = std::ptr::null_mut();
    let response = unsafe { tatachat_sdk_mls_identity_json(std::ptr::null(), &mut error) };
    assert!(response.is_null());
    assert!(!error.is_null());
    assert!(unsafe { CStr::from_ptr(error) }
        .to_str()
        .unwrap()
        .contains("request_json"));
    unsafe {
        tatachat_sdk::tatachat_sdk_free_string(error);
    }
}
#[test]
fn null_string_release_is_safe() {
    unsafe {
        tatachat_sdk::tatachat_sdk_free_string(std::ptr::null_mut());
    }
}
