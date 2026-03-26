# apt-bootstrap

A local-first, filesystem-based step runner for server provisioning and hardening.

Steps are numbered shell scripts. The runner executes them in order, tracks state per step, and uses file checksums to detect when a script has changed since it last ran successfully. Everything is transparent plain text — no database, no daemon.

---

## Layout

```
apt-bootstrap/
  bin/
    apt-bootstrap         # Main executable
  steps/              # Step scripts (NNNN-name.sh)
  state/              # Per-step state files (NNNN-name.state)
  logs/               # Per-run log files (NNNN-name.YYYYMMDD-HHMMSS.log)
  templates/
    step.sh           # Template used by `apt-bootstrap create`
```

The `bin/apt-bootstrap` script resolves all paths relative to its own parent directory, so the project can be placed anywhere.

---

## Step file naming

```
NNNN-name.sh
```

- `NNNN` — 4-digit zero-padded integer (e.g. `0100`, `0250`, `1000`)
- `name` — lowercase kebab-case (e.g. `hostname`, `packages-base`)

Execution order is determined by `NNNN` ascending. Gaps in numbering are intentional and supported; do not assume contiguous steps.

### Step header

Each step file must include this header block immediately after the shebang:

```bash
#!/usr/bin/env bash
# Step: 0100
# Name: hostname
# Version: 1.0.0
# Description: Set the system hostname.

set -euo pipefail
```

The runner does not parse the `Version` field for any logic. It is human metadata only. Step identity for state and checksum purposes is the file contents, not the version string.

---

## State model

State is tracked per step in `state/NNNN-name.state`. Each file uses plain `key=value` format:

```
step=0100
filename=0100-hostname.sh
checksum=a3f9...c8d1
status=success
started_at=2024-01-15T10:30:00Z
completed_at=2024-01-15T10:30:02Z
exit_code=0
log_path=logs/0100-hostname.20240115-103000.log
```

### Allowed statuses

| Status    | Meaning                                          |
|-----------|--------------------------------------------------|
| `pending` | Step has a state file but has not been run yet   |
| `running` | Step is currently executing (or was interrupted) |
| `success` | Step completed with exit code 0                  |
| `failed`  | Step completed with a non-zero exit code         |

State files are written and maintained automatically by the runner. You should not need to edit them by hand. Use `apt-bootstrap state clear` if you need to reset a step.

---

## Checksum and change detection

The runner computes a SHA-256 checksum of each step file's contents before execution. This checksum is stored in the state file.

On subsequent runs:

- **No state** → the step is eligible to run.
- **`status=success` and checksum matches** → skip (already done).
- **`status=success` and checksum differs** → the step has changed. By default it is skipped with a warning. Use `--changed` or `--force` to rerun.
- **`status=failed`** → stop with an error. Use `--failed` or `--force` to retry.
- **`status=running`** → a previous execution was interrupted. Stop with an error. Use `--force` to override.

The checksum is based on file contents only, not the filename. Renaming or moving a step does not invalidate the checksum.

---

## Log files

Each step run produces a timestamped log file:

```
logs/NNNN-name.YYYYMMDD-HHMMSS.log
```

Multiple runs of the same step produce separate log files. The state file's `log_path` field points to the most recent run. Older logs are retained until you remove them manually (or use `apt-bootstrap delete --purge`).

---

## Rename and move behaviour

### `apt-bootstrap rename NNNN new-name`

Changes the descriptive name portion of the filename, keeping the number the same.

- The step file is renamed: `0100-old-name.sh` → `0100-new-name.sh`
- The state file is renamed: `state/0100-old-name.state` → `state/0100-new-name.state`
- The `filename` field inside the state file is updated.
- All log files matching the old name prefix are renamed.
- A `# Renamed from: ...` comment is appended to each migrated log file.
- The recorded checksum remains valid (contents did not change).

### `apt-bootstrap move OLD_NNNN NEW_NNNN`

Changes the numeric prefix, keeping the descriptive name the same.

- The step file is moved: `0100-name.sh` → `0200-name.sh`
- The state file is moved and its `step` and `filename` fields are updated.
- All log files are renamed to the new prefix.
- A `# Moved from step: ...` comment is appended to each migrated log file.
- The recorded checksum remains valid (contents did not change).
- Refuses if the destination number already has a step file.

---

## Commands

### `apt-bootstrap list`

Shows all steps in execution order with their current status and any change indicators.

```
STEP    FILENAME                        STATUS      NOTE
──────────────────────────────────────────────────────────────────────────
0100    0100-example-hello.sh           success
0200    0200-example-file.sh            success     [CHANGED] checksum differs from last success
0300    0300-hostname.sh                pending
```

### `apt-bootstrap create NNNN name`

Creates a new step file from the template. Validates that the number is unique. Fills in the `Step` and `Name` header fields automatically.

```
apt-bootstrap create 0300 hostname
```

### `apt-bootstrap rename NNNN new-name`

```
apt-bootstrap rename 0300 set-hostname
```

### `apt-bootstrap move OLD_NNNN NEW_NNNN`

```
apt-bootstrap move 0300 0350
```

### `apt-bootstrap delete NNNN [--force] [--purge]`

Removes the step file. Prompts for confirmation unless `--force` is given.

By default, state and log files are **preserved** so you retain a history of what ran. Use `--purge` to also remove state and logs.

```
apt-bootstrap delete 0300           # prompt, preserve state/logs
apt-bootstrap delete 0300 --force   # no prompt, preserve state/logs
apt-bootstrap delete 0300 --purge --force   # no prompt, remove everything
```

### `apt-bootstrap run SELECTOR [--force] [--list-only]`

#### Selectors

| Selector          | What it runs                                                              |
|-------------------|---------------------------------------------------------------------------|
| `--all`           | All steps. Skips succeeded+unchanged. Stops on failed or changed.         |
| `--first`         | The lowest-numbered step present.                                         |
| `--last`          | The highest-numbered step present.                                        |
| `--step NNNN`     | Exactly one step.                                                         |
| `--range NNNN:NNNN` | All steps with number between A and B inclusive.                        |
| `--changed`       | Steps with no state, or whose checksum differs from last recorded success.|
| `--failed`        | Steps in `failed` state.                                                  |

#### Modifiers

| Modifier       | Effect                                                                   |
|----------------|--------------------------------------------------------------------------|
| `--force`      | Ignore existing success/failed state; run the selected steps regardless. Still records new state correctly. |
| `--list-only`  | Show what would run without executing anything.                          |

#### `--all` vs `--changed`

`--all` is for a clean sequential run. It stops if it encounters a changed or failed step, forcing you to make a deliberate decision about it.

`--changed` is for incremental updates: run only what has changed since last success. It does not rerun failed steps (use `--failed` for that).

### `apt-bootstrap state show [NNNN]`

Print state details for all steps, or a specific step.

### `apt-bootstrap state clear NNNN`

Remove the state file for a step. The step will be treated as never-run on the next `apt-bootstrap run`.

### `apt-bootstrap state clear-range NNNN NNNN`

Clear state for all steps in the inclusive numeric range.

### `apt-bootstrap state clear-all`

Remove all state files.

### `apt-bootstrap doctor`

Check for common problems:

- Steps left in `running` state (interrupted executions)
- Steps in `failed` state
- Steps whose file has changed since last success
- Step files that are not executable
- Orphaned state files with no matching step file

---

## Execution model

For each step that is eligible to run:

1. Compute the current file checksum.
2. Write `status=running` to the state file (with `started_at` and `log_path`).
3. Execute `bash NNNN-name.sh`, capturing combined stdout+stderr via `tee` to the log file.
4. Capture the exit code.
5. Write the final state: `status=success` or `status=failed`, with `completed_at` and `exit_code`.

The `set -euo pipefail` in each step script means any unhandled error causes the step to exit non-zero, which the runner will record as `failed`.

Steps are run sequentially. Execution stops on the first failure (by default).

---

## Writing steps

Steps must be idempotent: running them twice should be safe and correct. Use guard conditions to detect whether work has already been done and exit cleanly if so.

```bash
#!/usr/bin/env bash
# Step: 0300
# Name: hostname
# Version: 1.0.0
# Description: Set the system hostname.

set -euo pipefail

DESIRED_HOSTNAME="myserver"

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

if [[ "$(hostname)" == "${DESIRED_HOSTNAME}" ]]; then
    log "Hostname already set to ${DESIRED_HOSTNAME} -- nothing to do."
    exit 0
fi

log "Setting hostname to ${DESIRED_HOSTNAME}."
hostnamectl set-hostname "${DESIRED_HOSTNAME}"
log "Done."
```

---

## Installation

```bash
chmod +x apt-bootstrap/bin/apt-bootstrap
# Optionally symlink into your PATH:
ln -s "$(pwd)/apt-bootstrap/bin/apt-bootstrap" /usr/local/bin/apt-bootstrap
```

---

## Local test plan

The following sequence verifies all major features. Run from inside the `apt-bootstrap/` directory.

### 1. Create

```bash
bin/apt-bootstrap create 0300 test-step
# Expected: steps/0300-test-step.sh created from template.
```

### 2. List

```bash
bin/apt-bootstrap list
# Expected: 0100, 0200, 0300 shown; all pending or with existing state.
```

### 3. Run first

```bash
bin/apt-bootstrap run --first
# Expected: step 0100 (example-hello) runs and prints system info.
bin/apt-bootstrap list
# Expected: 0100 shows status=success.
```

### 4. Run last

```bash
bin/apt-bootstrap run --last
# Expected: step 0300 (test-step) runs (or fails since it has a TODO).
# Edit steps/0300-test-step.sh to add a real body first:
#   echo "hello from test-step"
# Then:
bin/apt-bootstrap run --last
```

### 5. Run a range

```bash
bin/apt-bootstrap run --range 0100:0200
# Expected: both 0100 and 0200 run in order.
# On second run: both are skipped (success, unchanged).
```

### 6. Run all (verify skip behaviour)

```bash
bin/apt-bootstrap run --all
# Expected: 0100 and 0200 are skipped (already succeeded).
# 0300 runs if it has not run yet.
```

### 7. Changed detection

```bash
# Modify a step file:
echo "# changed" >> steps/0100-example-hello.sh

bin/apt-bootstrap list
# Expected: 0100 shows [CHANGED].

bin/apt-bootstrap run --all
# Expected: 0100 is SKIPPED with a warning (changed).
# Other steps run normally.

bin/apt-bootstrap run --changed
# Expected: 0100 runs (changed since last success).

bin/apt-bootstrap run --all --list-only
# Expected: shows [WOULD RUN] / [SKIP] / [SKIP/WARN] without executing.
```

### 8. Failed state

```bash
# Create a step that fails:
bin/apt-bootstrap create 0150 always-fail
echo 'exit 1' >> steps/0150-always-fail.sh

bin/apt-bootstrap run --step 0150
# Expected: step fails; status=failed recorded.

bin/apt-bootstrap run --all
# Expected: stops with error at step 0150.

bin/apt-bootstrap run --failed
# Expected: only step 0150 is retried.

bin/apt-bootstrap run --step 0150 --force
# Expected: step 0150 is retried regardless of failed state.
```

### 9. Rename

```bash
bin/apt-bootstrap rename 0300 renamed-step
# Expected: steps/0300-test-step.sh -> steps/0300-renamed-step.sh
#           state/0300-test-step.state -> state/0300-renamed-step.state (if exists)

bin/apt-bootstrap list
# Expected: 0300 shows new name.
```

### 10. Move

```bash
bin/apt-bootstrap move 0300 0350
# Expected: steps/0300-renamed-step.sh -> steps/0350-renamed-step.sh
#           state migrated; logs migrated.

bin/apt-bootstrap list
# Expected: step appears at 0350.
```

### 11. Delete

```bash
bin/apt-bootstrap delete 0150
# Expected: prompts for confirmation; deletes step file; state/logs preserved.

bin/apt-bootstrap delete 0350 --force --purge
# Expected: no prompt; deletes step file, state file, and log files.

bin/apt-bootstrap list
# Expected: 0150 and 0350 no longer appear.
```

### 12. State management

```bash
bin/apt-bootstrap state show
# Expected: details for all steps.

bin/apt-bootstrap state show 0100
# Expected: details for step 0100 including checksum match status.

bin/apt-bootstrap state clear 0100
# Expected: state file removed; 0100 is pending again.

bin/apt-bootstrap run --all
# Expected: 0100 runs again.

bin/apt-bootstrap state clear-range 0100 0200
# Expected: state cleared for both 0100 and 0200.

bin/apt-bootstrap state clear-all
# Expected: all state files removed.
```

### 13. Doctor

```bash
bin/apt-bootstrap doctor
# Expected: reports any failed, running, or changed steps.
# With clean state and no issues: "All clear."
```
