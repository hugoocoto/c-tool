#!/usr/bin/env bash
# Build and run every test/*.c in random order. Each one is a self-contained
# program that exits 0 if it passes and non-zero if it fails. This script exits
# non-zero if any test fails to build or run.
#
# Run it as `make test` (or directly: it calls make itself), which builds the
# program and the tests with sanitizers and sets TEST_CC, TEST_CFLAGS,
# TEST_LDLIBS, TEST_OUT (where the test binaries go) and TEST_BIN (the program,
# for tests that run it). TEST_TIMEOUT (seconds, default 10) limits each test.
set -u
cd "$(dirname "$0")/.." || exit 1
[ -n "${TEST_CC:-}" ] || exec make --no-print-directory test

mkdir -p "$TEST_OUT"
mapfile -t tests < <(find test -maxdepth 1 -name '*.c' | shuf)
failed=()

for t in "${tests[@]}"; do
        name=$(basename "$t" .c)
        bin=$TEST_OUT/$name
        # The flags are word-split on purpose
        # shellcheck disable=SC2086
        if ! $TEST_CC $TEST_CFLAGS "$t" -o "$bin" $TEST_LDLIBS 2>"$bin.log"; then
                echo "FAIL $name (build)"
                sed 's/^/    /' "$bin.log"
                failed+=("$name")
        elif timeout "${TEST_TIMEOUT:-10}" "$bin" >"$bin.log" 2>&1; then
                echo "ok   $name"
        else
                status=$?
                [ $status -eq 124 ] && status="timeout" || status="exit $status"
                echo "FAIL $name ($status)"
                sed 's/^/    /' "$bin.log"
                failed+=("$name")
        fi
done

echo "${#tests[@]} tests, ${#failed[@]} failed${failed[*]:+: ${failed[*]}}"
[ ${#failed[@]} -eq 0 ]
