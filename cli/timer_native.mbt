///|
#cfg(target="native")
pub extern "C" fn now_ms() -> Int64 = "markitdown_cli_now_ms"

///|
#cfg(target="native")
extern "C" fn now_us() -> Int64 = "markitdown_cli_now_us"
