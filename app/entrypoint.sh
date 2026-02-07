#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# ResilienceScan Container Entrypoint
# Verifies runtimes, logs versions, and starts health endpoint server
# =============================================================================

LOG_FILE="/logs/container_startup.log"
HEALTH_PORT=8080

# ---------------------------------------------------------------------------
# Runtime version logging (stdout + log file)
# ---------------------------------------------------------------------------
log() {
  echo "$1" | tee -a "${LOG_FILE}"
}

log "============================================="
log "ResilienceScan Container Startup"
log "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
log "============================================="

# Verify and log R version
R_VERSION=$(R --version | head -1)
log "R: ${R_VERSION}"

# Verify and log Python version
PYTHON_VERSION=$(python3 --version 2>&1)
log "Python: ${PYTHON_VERSION}"

# Verify and log Quarto version
QUARTO_VERSION=$(quarto --version 2>&1)
log "Quarto: ${QUARTO_VERSION}"

# Log locale
LOCALE_INFO=$(locale 2>&1 | head -3)
log "Locale:"
log "${LOCALE_INFO}"

log "============================================="
log "All runtimes verified successfully"
log "Starting FastAPI web server on port ${HEALTH_PORT}..."
log "============================================="

# ---------------------------------------------------------------------------
# Start FastAPI web server using uvicorn
# Provides web control panel for P2/P3 pipeline orchestration
# Runs in foreground to keep container alive
# ---------------------------------------------------------------------------
cd /app
exec uvicorn app.web.main:app --host 0.0.0.0 --port ${HEALTH_PORT}
