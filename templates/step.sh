#!/usr/bin/env bash
# Step: __STEP_NUMBER__
# Name: __STEP_NAME__
# Version: 1.0.0
# Description: (describe what this step does)

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() {
    printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"
}

die() {
    printf '[%s] error: %s\n' "$(date -u +%H:%M:%S)" "$*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Guards (idempotency checks)
# ---------------------------------------------------------------------------

# Example: exit early if the work is already done.
# if already_configured; then
#     log "Already configured -- nothing to do."
#     exit 0
# fi

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

log "Starting step __STEP_NUMBER__ (__STEP_NAME__)."

# TODO: implement step logic here.
# Keep steps idempotent: running the same step twice should be safe.
# Fail hard on unexpected conditions: set -euo pipefail is active.

log "Step __STEP_NUMBER__ (__STEP_NAME__) complete."
