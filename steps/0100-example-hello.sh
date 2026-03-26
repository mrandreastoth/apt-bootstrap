#!/usr/bin/env bash
# Step: 0100
# Name: example-hello
# Version: 1.0.0
# Description: Print a greeting and basic system information. Non-destructive.

set -euo pipefail

log() {
    printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

log "Starting step 0100 (example-hello)."

log "Hostname: $(hostname)"
log "Kernel:   $(uname -r)"
log "Uptime:   $(uptime)"
log "User:     $(id)"

log "Step 0100 (example-hello) complete."
