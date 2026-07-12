#!/usr/bin/env bash
#
# jless/mayhem/build.sh — build the cargo-fuzz target as a sanitized libFuzzer binary
# (OSS-Fuzz Rust path: cargo-fuzz + ASan via RUSTFLAGS), then pre-compile the upstream
# test suite (normal flags) so mayhem/test.sh only RUNS it.
#
# Runs inside the commit image (RUST mayhem/Dockerfile) as `mayhem` in /mayhem.
# The Rust toolchain + cargo registry live at $CARGO_HOME=/opt/toolchains/rust/cargo
# (pinned by the Dockerfile ENV — absolute, $HOME-independent).
#
# AIR-GAPPED CONTRACT (SPEC §6.5): the PATCH tier re-runs THIS script OFFLINE.
#   - This FIRST build (in CI, online) populates the cargo registry under $CARGO_HOME.
#   - The PATCH re-run resolves crates from that cache. The rlenv runtime exports
#     CARGO_NET_OFFLINE=true for the re-run, so do NOT hard-code `--offline` here.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${MAYHEM_JOBS:=$(nproc)}"
# cargo-fuzz has no --jobs flag; cargo reads parallelism from CARGO_BUILD_JOBS.
export CARGO_BUILD_JOBS="$MAYHEM_JOBS"

cd "$SRC"

# SANITIZER off-switch (SPEC): the Dockerfile threads $SANITIZER_FLAGS (default asan+ubsan,
# halting). rustc ignores clang flags, so we DERIVE the rustc sanitizer flag from it: if
# $SANITIZER_FLAGS mentions "address" we add -Zsanitizer=address; an EMPTY value (built with
# --build-arg SANITIZER_FLAGS=) yields a natural, un-instrumented crash build.
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all}"
RUST_SAN=""
CFZ_SANITIZER="none"   # cargo-fuzz's own -s flag; overridden below when ASan is requested
case "$SANITIZER_FLAGS" in
  *address*) RUST_SAN="-Zsanitizer=address"; CFZ_SANITIZER="address" ;;
esac

# DWARF < 4 contract (§6.2 item 10): recent rustc defaults to DWARF-5, which Mayhem's triage
# can't read. Thread $RUST_DEBUG_FLAGS (default: DWARF-3 + frame pointers + debuginfo) so the
# fuzz binary carries DWARF < 4 symbols. The rlenv PATCH tier may override it.
: "${RUST_DEBUG_FLAGS:=-Cdebuginfo=1 -Zdwarf-version=3 -Cforce-frame-pointers}"

# libfuzzer-sys compiles its C++ libFuzzer runtime through the `cc` crate (clang), which
# defaults to DWARF-5. rustc's -Zdwarf-version only covers Rust CUs, so pin the C/C++ side
# to DWARF-3 too via CFLAGS/CXXFLAGS.
export CFLAGS="${CFLAGS:-} -gdwarf-3"
export CXXFLAGS="${CXXFLAGS:-} -gdwarf-3"

# Upstream ships no lib target (binary-only crate), so the harness drives the additive
# mayhem/jless-lib shim (unmodified upstream sources re-exposed as a library) via the
# ADDITIVE mayhem/fuzz crate — upstream stays untouched.
FUZZ_DIR="mayhem/fuzz"
TRIPLE="x86_64-unknown-linux-gnu"

# Discover every target from the crate's fuzz_targets/ dir (one binary per target).
FUZZ_TARGETS=()
for f in "$FUZZ_DIR"/fuzz_targets/*.rs; do
  FUZZ_TARGETS+=("$(basename "${f%.*}")")
done
[ "${#FUZZ_TARGETS[@]}" -gt 0 ] || { echo "ERROR: no fuzz targets under $FUZZ_DIR/fuzz_targets/" >&2; exit 1; }

echo "=== cargo fuzz build (image nightly, ASan via RUSTFLAGS) ==="
FUZZ_RUSTFLAGS="${RUSTFLAGS:-} --cfg fuzzing $RUST_SAN $RUST_DEBUG_FLAGS"
echo "RUSTFLAGS=$FUZZ_RUSTFLAGS"
echo "targets: ${FUZZ_TARGETS[*]}"

for t in "${FUZZ_TARGETS[@]}"; do
  echo "--- building fuzz target: $t ---"
  RUSTFLAGS="$FUZZ_RUSTFLAGS" cargo fuzz build --fuzz-dir "$FUZZ_DIR" -s "$CFZ_SANITIZER" -O --debug-assertions "$t"
  bin="$SRC/$FUZZ_DIR/target/$TRIPLE/release/$t"
  [ -x "$bin" ] || { echo "ERROR: expected fuzz binary not found at $bin" >&2; exit 1; }
  cp "$bin" "/mayhem/$t"
  echo "built /mayhem/$t"
done

# Pre-compile the upstream test suite (the project's NORMAL flags — no sanitizer, no
# fuzzing cfg) so mayhem/test.sh only RUNS the cached binaries. The whole upstream unit
# suite lives in #[cfg(test)] modules of the jless binary crate.
echo "=== pre-compiling the upstream test suite (cargo test --no-run, normal flags) ==="
env -u RUSTFLAGS cargo test --no-run --jobs "$MAYHEM_JOBS"

echo "build.sh complete"
