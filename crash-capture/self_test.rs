//! Crashes on purpose, so that a CI run proves it can read the stack of a crash.

#[unsafe(no_mangle)]
#[inline(never)]
pub extern "C" fn rust_ci_self_test_crash() {
    unsafe { core::ptr::null_mut::<u8>().write_volatile(1) }
}

fn main() {
    rust_ci_self_test_crash();
}
