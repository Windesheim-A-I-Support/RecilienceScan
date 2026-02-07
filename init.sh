#!/bin/bash

# =============================================================================
# ResilienceScan Web Interface Development Environment Setup
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Wait for service function
wait_for_service() {
    local port=$1
    local name=$2
    local max=30
    local count=0

    echo -e "${BLUE}Waiting for $name on port $port...${NC}"
    while ! nc -z localhost $port 2>/dev/null; do
        count=$((count + 1))
        if [ $count -ge $max ]; then
            echo -e "${RED}$name failed to start${NC}"
            return 1
        fi
        sleep 1
    done
    echo -e "${GREEN}$name ready${NC}"
}

# =============================================================================
# START SERVICES
# =============================================================================

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Starting ResilienceScan Web Development${NC}"
echo -e "${BLUE}=======================================${NC}"

# Start web server
cd .auto-claude/worktrees/tasks/002-p4-resiliencescan-web-interface
if [ -f "requirements.txt" ]; then
    echo -e "${YELLOW}Installing Python dependencies...${NC}"
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
fi

echo -e "${YELLOW}Starting FastAPI web server...${NC}"
uvicorn app.web.main:app --host 0.0.0.0 --port 8080 --reload &
WEB_PID=$!
wait_for_service 8080 "FastAPI Web Server"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Development Environment Ready!${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""
echo -e "${GREEN}Services:${NC}"
echo -e "  Web:      http://localhost:8080"
echo ""
echo -e "${YELLOW}Available Endpoints:${NC}"
echo -e "  Health:   http://localhost:8080/health"
echo -e "  Runs:     http://localhost:8080/runs"
echo -e "  Reports:  http://localhost:8080/reports"
echo ""
echo -e "${GREEN}To access the web interface:${NC}"
echo -e "  Open http://localhost:8080 in your browser"
echo ""
echo -e "${YELLOW}To run tests:${NC}"
echo -e "  source venv/bin/activate"
echo -e "  pytest tests/web/"
echo ""
echo -e "${GREEN}To stop services:${NC}"
echo -e "  kill $WEB_PID"
echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}Development workflow:${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${YELLOW}1. Make changes to web interface${NC}"
echo -e "${YELLOW}2. Tests will auto-reload with --reload flag${NC}"
echo -e "${YELLOW}3. Access http://localhost:8080 to test${NC}"
echo -e "${YELLOW}4. Run pytest to verify all tests pass${NC}"
echo ""

# Keep script running to maintain services
wait $WEB_PID