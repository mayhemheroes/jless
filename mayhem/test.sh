#!/usr/bin/env bash
#
# jless/mayhem/test.sh — RUN jless's OWN upstream test suite (`cargo test`) and emit a CTRF
# summary. exit 0 iff no test failed.
#
# PATCH-grade oracle: jless ships a real assertion suite in #[cfg(test)] modules across
# src/ (flatjson, jsonparser, jsonstringunescaper, lineprinter, search, truncatedstrview,
# viewer, yamlparser) — 100+ tests asserting exact parse trees, pretty-printed golden
# output (indoc), unescape results, search match ranges, and viewer movement semantics.
# These assert concrete values, so a no-op / "exit(0)" patch CANNOT pass. This script only
# RUNS the suite; build.sh pre-compiled it with `cargo test --no-run` (normal flags), so
# this run reuses the cached test binaries.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not available — cannot run the test suite" >&2
  emit_ctrf "cargo-test" 0 1 0; exit 2
fi

echo "=== running cargo test (jless upstream unit suite) ==="
# Image default toolchain (Dockerfile pins it) — no `+toolchain` override. --no-fail-fast so
# every test is counted; RUSTFLAGS cleared so nothing leaks in from the sanitizer fuzz build
# (build.sh pre-compiled with the same clean flags, so this only runs the cached binaries).
out="$(env -u RUSTFLAGS cargo test --no-fail-fast --jobs "$MAYHEM_JOBS" 2>&1)"; rc=$?
echo "$out"

# libtest prints one line per test binary:
#   test result: ok. 12 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; ...
PASSED=0; FAILED=0; IGNORED=0
while read -r p f i; do
  PASSED=$(( PASSED + p )); FAILED=$(( FAILED + f )); IGNORED=$(( IGNORED + i ))
done < <(printf '%s\n' "$out" \
  | sed -n 's/^test result:.* \([0-9][0-9]*\) passed; \([0-9][0-9]*\) failed; \([0-9][0-9]*\) ignored.*/\1 \2 \3/p')

# Honesty guards: a cargo that dies (or is neutered) parses as 0 tests — that is a failure,
# and a non-zero cargo exit with 0 parsed failures is forced to a failure too.
if [ "$(( PASSED + FAILED + IGNORED ))" -eq 0 ]; then
  echo "no 'test result:' lines parsed — test binaries missing or runner neutered" >&2
  FAILED=1
fi
if [ "$rc" -ne 0 ] && [ "$FAILED" -eq 0 ]; then FAILED=1; fi

emit_ctrf "cargo-test" "$PASSED" "$FAILED" "$IGNORED"
