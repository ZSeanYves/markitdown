///|
/// JavaScript and Wasm-GC are compile-only targets for this CLI package.
/// Keep their host boundary explicit instead of importing a target-missing
/// stdio value. The product release targets are Native and linear Wasm.
#cfg(not(any(target="native", target="wasm")))
pub fn write_stdout(_message : String) -> Unit {

}

///|
#cfg(not(any(target="native", target="wasm")))
pub fn write_stderr(_message : String) -> Unit {

}
