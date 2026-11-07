#!/usr/bin/env bash
# Prints the stack of every thread of each crash in RUST_CI_CRASH_DIR. Prints nothing with no crash.
set -euo pipefail
shopt -s nullglob

here="$(dirname "${BASH_SOURCE[0]}")"

case "$RUNNER_OS" in
Linux)
    for core in "$RUST_CI_CRASH_DIR"/core.*; do
        exe="$(basename "$core" | sed 's/^core\.[0-9]*\.//' | tr '!' '/')"
        echo "::group::$exe"
        timeout 300 gdb --batch -ex 'thread apply all bt' "$exe" "$core" || true
        echo "::endgroup::"
    done
    ;;
macOS)
    while IFS= read -r report; do
        echo "::group::$(basename "$report")"
        # A report still in writing does not parse yet.
        python3 "$here/ips_stacks.py" "$report" || true
        echo "::endgroup::"
    done < <(find "$RUST_CI_CRASH_DIR" -name '*.ips' -newer "$RUNNER_TEMP/crash-marker")
    ;;
Windows)
    cdb='/c/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe'
    for dump in "$RUST_CI_CRASH_DIR"/*.dmp; do
        echo "::group::$(basename "$dump")"
        timeout 300 "$cdb" -z "$(cygpath --windows "$dump")" -c '~*k; q' || true
        echo "::endgroup::"
    done
    ;;
esac
