#!/usr/bin/env bash
# Step: 0200
# Name: example-file
# Version: 1.0.0
# Description: Write a marker file to /tmp to demonstrate step execution and
#              idempotency. Non-destructive; touches only /tmp.

set -euo pipefail

MARKER_FILE="/tmp/bootstrap-example-marker"

log() {
    printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"
}

# ---------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------

# This step is written to be idempotent: if the marker already exists and
# contains the expected content, report it and exit cleanly.
if [[ -f "${MARKER_FILE}" ]] && grep -q "bootstrap-example" "${MARKER_FILE}" 2>/dev/null; then
    log "Marker file already present: ${MARKER_FILE}"
    log "Contents: $(cat "${MARKER_FILE}")"
    log "Nothing to do -- step 0200 already applied."
    exit 0
fi

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

log "Starting step 0200 (example-file)."

log "Writing marker file: ${MARKER_FILE}"
printf 'bootstrap-example\nwritten-at=%s\nhostname=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$(hostname)" \
    > "${MARKER_FILE}"

log "Marker file contents:"
cat "${MARKER_FILE}"

log "Step 0200 (example-file) complete."
