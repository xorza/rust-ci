#!/usr/bin/env bash
# Sets RUST_CI_CRASH_DIR, where a crash leaves its file, for each later step.
set -euo pipefail

case "$RUNNER_OS" in
Linux)
    dir="$RUNNER_TEMP/crashes"
    mkdir -p "$dir"
    # Ubuntu's default pipes a core to apport. `%E` holds the binary's path, with `!` for each `/`.
    sudo sysctl -w "kernel.core_pattern=$dir/core.%p.%E"
    # A step starts at core limit 0, and `BASH_ENV` raises it in each later one. 4 GiB in KiB keeps
    # a core from filling the disk that later steps build on. A refused limit must not fail each
    # step under `bash -e`: the proof finds it.
    limit="$RUNNER_TEMP/core-limit.sh"
    echo 'ulimit -c 4194304 || true' >"$limit"
    echo "BASH_ENV=$limit" >>"$GITHUB_ENV"
    # Now, not on failure: the proof needs it, and a failure's report then needs no network.
    sudo apt-get install -y --no-install-recommends gdb
    ;;
macOS)
    # CrashReporter writes a report here with no setup. No core: a binary needs the `get-task-allow`
    # entitlement for one. The marker leaves out reports from before this job.
    dir="$HOME/Library/Logs/DiagnosticReports"
    mkdir -p "$dir"
    touch "$RUNNER_TEMP/crash-marker"
    ;;
Windows)
    dir="$(cygpath -u "$RUNNER_TEMP")/crashes"
    mkdir -p "$dir"
    # A minidump holds each thread's stack, at a small size.
    # https://learn.microsoft.com/windows/win32/wer/collecting-user-mode-dumps
    key='HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps'
    MSYS_NO_PATHCONV=1 reg.exe add "$key" /v DumpFolder /t REG_EXPAND_SZ /d "$(cygpath --windows "$dir")" /f
    MSYS_NO_PATHCONV=1 reg.exe add "$key" /v DumpType /t REG_DWORD /d 1 /f
    ;;
*)
    echo "::error::no crash route for $RUNNER_OS"
    exit 1
    ;;
esac

echo "RUST_CI_CRASH_DIR=$dir" >>"$GITHUB_ENV"
