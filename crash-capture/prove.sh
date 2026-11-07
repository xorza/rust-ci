#!/usr/bin/env bash
# Crashes one program and requires its own frame in the stack, then leaves no trace of the crash.
set -euo pipefail

here="$(dirname "${BASH_SOURCE[0]}")"
# The OS writes the file some time after the crash: this bounds the wait.
wait_s_max=60

# `.exe` on every OS, as Windows needs it and the others ignore it.
exe="$RUNNER_TEMP/rust-ci-self-test.exe"
rustc --edition 2024 -g -o "$exe" "$here/self_test.rs"

status=0
"$exe" || status=$?
echo "the crash exits with $status"
if [ "$status" -eq 0 ]; then
    echo '::error::the crash program exited cleanly'
    exit 1
fi

stacks=""
while [ "$SECONDS" -lt "$wait_s_max" ]; do
    stacks="$(bash "$here/../scripts/stacks.sh")"
    if grep -q rust_ci_self_test_crash <<<"$stacks"; then
        echo "$stacks"
        echo "the stack took ${SECONDS} s"
        case "$RUNNER_OS" in
        macOS) rm -f "$RUST_CI_CRASH_DIR"/rust-ci-self-test* ;;
        *) rm -f "$RUST_CI_CRASH_DIR"/* ;;
        esac
        exit 0
    fi
    sleep 1
done

echo "$stacks"
echo "::error::no stack of the crash in ${wait_s_max} s"
exit 1
