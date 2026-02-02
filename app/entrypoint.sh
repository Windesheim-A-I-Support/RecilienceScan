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
log "Starting health server on port ${HEALTH_PORT}..."
log "============================================="

# ---------------------------------------------------------------------------
# Minimal HTTP health server using Python http.server
# Responds to /health with JSON status
# Runs in foreground to keep container alive
# ---------------------------------------------------------------------------
exec python3 -c "
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

HEALTH_RESPONSE = json.dumps({
    'status': 'healthy',
    'runtimes': {
        'r': True,
        'python': True,
        'quarto': True
    }
})

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(HEALTH_RESPONSE.encode('utf-8'))
        else:
            self.send_response(404)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'error': 'not found'}).encode('utf-8'))

    def log_message(self, format, *args):
        # Suppress default access logging to keep stdout clean
        pass

server = HTTPServer(('0.0.0.0', ${HEALTH_PORT}), HealthHandler)
print(f'Health server listening on port ${HEALTH_PORT}')
server.serve_forever()
"
