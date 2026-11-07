# rust-ci

Composite GitHub Actions that give each Rust repository the same CI lane on Linux, macOS and Windows,
and a failure that says what broke. A repository pins the commit of a tag, here `<sha>`, with the tag
in a comment for Dependabot:

```yaml
defaults:
  run:
    shell: bash

jobs:
  gate:
    name: gate (${{ matrix.os }})
    runs-on: ${{ matrix.os }}
    timeout-minutes: 120
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-26.04, macos-26, windows-2025]
    steps:
      - uses: actions/checkout@<sha> # v1
        with:
          persist-credentials: false
      - uses: xorza/rust-ci/setup@<sha> # v1
        with:
          apt-packages: libclang-dev
      - uses: xorza/rust-ci/lavapipe@<sha> # v1
      - uses: xorza/rust-ci/crash-capture@<sha> # v1
      - uses: xorza/rust-ci/test@<sha> # v1
        if: ${{ !cancelled() }}
        timeout-minutes: 60
        with:
          command: cargo --locked test
      - uses: xorza/rust-ci/failure-report@<sha> # v1
        if: failure()
        with:
          paths: test_output/**

  workflows:
    name: workflow checks
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/checkout@<sha> # v1
        with:
          persist-credentials: false
      - uses: xorza/rust-ci/workflow-check@<sha> # v1
```

| Action | What it does |
|---|---|
| `setup` | Installs the toolchain of `rust-toolchain.toml` and the `apt-packages`, sets `RUST_BACKTRACE=full`, and restores the build cache |
| `lavapipe` | Installs Mesa lavapipe on Linux and Windows, and prints the adapter on each OS |
| `crash-capture` | Arms the OS's route from a crash to a stack, and proves it with one crash |
| `test` | Runs a test command and keeps its output for `failure-report` |
| `failure-report` | Prints each crash's stack, lists crashes and failed tests in the job summary, and uploads `paths` |
| `workflow-check` | Runs `actionlint` and `zizmor` |

## Decisions

- **The shared steps live in this repository**, which each caller pins by a tag's commit, as
  [rust-lang/simpleinfra](https://github.com/rust-lang/simpleinfra) holds shared actions. Refused:
  actions in one caller, which the others cannot see in a standalone checkout; a copy in each caller,
  which drifts.
- **`cargo test` in each caller.** Tests keep one process and any device they share, and a crash's
  stack names the test by its frames, and by its thread name, which Linux cuts to 15 characters.
  Refused: nextest, which runs slower with a process per test and can hide a crash that needs two
  tests in one process; nextest in CI alone, as CI and a local gate would then differ. Cost: no JUnit
  and no per-test timeout.
- **A `rust-toolchain.toml` in each caller**, so CI and a local build use one compiler, and a new lint
  arrives in a commit. Refused: `stable`, which can turn a master red with no commit that caused it; a
  version in `setup`, as a local gate could then pass where CI fails. Cost: a bump in each caller, and
  rustup installs that version on each machine.
- **A push cancels the older run on master too.** Refused: cancelling pull request runs alone, as
  [wgpu](https://github.com/gfx-rs/wgpu/blob/trunk/.github/workflows/ci.yml) does, for its CI minutes.
  Cost: a cancelled commit has no result.
- **`actionlint`, `zizmor` and Dependabot in each caller.** Refused: no checks, as a workflow error
  then shows only on a run. Cost: Dependabot pull requests, and findings to fix or waive.
- **A step limit ends a hang, with no stack.** Refused for now: a signal on timeout, as cirunner sends
  it, until a hang shows.
- **A proof in each lane.** `crash-capture` fails unless one crash gives a stack with the program's own
  frame, so "no crash" in a report means none. Refused: arming alone, as in
  [ci-core-dumper](https://github.com/mdavidsaver/ci-core-dumper), where a missed limit reads as no
  crash.
- **Each OS's own route to one report.** Linux: `core_pattern` and `gdb`. macOS: CrashReporter's `.ips`
  report, which needs no sudo and no entitlement, where a core needs
  [`get-task-allow`](https://nasa.github.io/trick/howto_guides/How-to-dump-core-file-on-MacOS). Windows:
  [WER `LocalDumps`](https://learn.microsoft.com/windows/win32/wer/collecting-user-mode-dumps) and
  `cdb`, as [cirunner](https://github.com/pjsip/cirunner) uses them, with `MSYS=winjitdebug`, as bash
  otherwise [stops WER](https://gist.github.com/jeremyd2019/3069ae1d44e86f4695087b98271af5d9) for its
  children.
- **A stack in the log, not a dump in an artifact.** A core can take gigabytes, and a stack is what a
  person reads first.
- **A hash on each download.** Refused: the retry alone, as
  [wgpu's install-mesa](https://github.com/gfx-rs/wgpu/blob/trunk/.github/actions/install-mesa/action.yml)
  has it, where a changed archive runs unseen.
