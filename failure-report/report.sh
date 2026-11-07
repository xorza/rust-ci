#!/usr/bin/env bash
# The log of a job holds the whole story, in thousands of lines: the summary holds its headlines.
set -euo pipefail

here="$(dirname "${BASH_SOURCE[0]}")"
# The OS writes a crash's file some time after the crash, and this step can start at once. Only a
# failed job waits, and only when it has no crash to show.
wait_s_max=30

crash_count=0
if [ -z "${RUST_CI_CRASH_DIR:-}" ]; then
    echo 'the job failed before `crash-capture`, so no crash can show'
else
    stacks=""
    while [ -z "$stacks" ] && [ "$SECONDS" -lt "$wait_s_max" ]; do
        stacks="$(bash "$here/../scripts/stacks.sh")"
        if [ -z "$stacks" ]; then
            sleep 1
        fi
    done
    if [ -n "$stacks" ]; then
        crash_count="$(grep -c '^::group::' <<<"$stacks")"
        echo "$stacks"
        {
            echo '## Crashes'
            grep '^::group::' <<<"$stacks" | sed 's/^::group::/- /'
            echo 'The log of the step "Print the stack of each crash" holds each stack.'
        } >>"$GITHUB_STEP_SUMMARY"
    fi
    echo "$crash_count crash(es) after ${SECONDS} s"
fi
echo "crash-count=$crash_count" >>"$GITHUB_OUTPUT"

if [ -f "${RUST_CI_TEST_LOG:-}" ]; then
    # Cargo colors its own lines.
    failed="$(sed 's/\x1b\[[0-9;]*m//g' "$RUST_CI_TEST_LOG" |
        grep -E '^test .* FAILED$|^error: test failed|signal: [0-9]+|exit code: 0x' || true)"
    if [ -n "$failed" ]; then
        {
            echo '## Failed tests'
            echo '```'
            echo "$failed"
            echo '```'
        } >>"$GITHUB_STEP_SUMMARY"
    fi
fi
