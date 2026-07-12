// Ported unchanged from the original mayhemheroes fork's fuzz/fuzz_targets/jsonparser.rs:
// fuzzes jless's JSON parser (jsonparser::parse over an arbitrary String).
#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: String| {
    _ = jless::jsonparser::parse(data);
});
