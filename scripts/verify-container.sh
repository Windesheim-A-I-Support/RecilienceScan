#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# ResilienceScan Container Integration Verification Script
# Run this script from the project root to verify the container foundation.
# Prerequisites: Docker Desktop running, port 8080 available
# =============================================================================

PASS=0
FAIL=0
SERVICE="resiliencescan"

green() { echo -e "\033[32m✓ PASS: $1\033[0m"; PASS=$((PASS + 1)); }
red()   { echo -e "\033[31m✗ FAIL: $1\033[0m"; FAIL=$((FAIL + 1)); }

echo "============================================="
echo "ResilienceScan Container Verification"
echo "============================================="
echo ""

# -------------------------------------------------------
# Step 1: Build and start container
# -------------------------------------------------------
echo ">>> Step 1: Building and starting container..."
docker compose up --build -d 2>&1
if [ $? -eq 0 ]; then
  green "Container built and started"
else
  red "Container build/start failed"
  exit 1
fi

# -------------------------------------------------------
# Step 2: Wait for healthy status (max 120s)
# -------------------------------------------------------
echo ""
echo ">>> Step 2: Waiting for container to become healthy (max 120s)..."
SECONDS_WAITED=0
MAX_WAIT=120
while [ $SECONDS_WAITED -lt $MAX_WAIT ]; do
  STATUS=$(docker compose ps --format json 2>/dev/null | python3 -c "
import sys, json
for line in sys.stdin:
    data = json.loads(line)
    if data.get('Service') == '$SERVICE':
        print(data.get('Health', 'unknown'))
        break
" 2>/dev/null || echo "unknown")

  if [ "$STATUS" = "healthy" ]; then
    green "Container reached healthy status in ${SECONDS_WAITED}s"
    break
  fi
  sleep 5
  SECONDS_WAITED=$((SECONDS_WAITED + 5))
  echo "   ...waiting (${SECONDS_WAITED}s, status: ${STATUS})"
done

if [ "$STATUS" != "healthy" ]; then
  red "Container did not reach healthy status within ${MAX_WAIT}s (status: ${STATUS})"
  echo "   Container logs:"
  docker compose logs --tail 30
fi

# -------------------------------------------------------
# Step 3: Health endpoint check
# -------------------------------------------------------
echo ""
echo ">>> Step 3: Checking health endpoint..."
HTTP_CODE=$(curl -s -o /tmp/health_response.json -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  green "Health endpoint returned HTTP 200"
  RESPONSE=$(cat /tmp/health_response.json)
  echo "   Response: ${RESPONSE}"
  # Verify it's valid JSON with status field
  echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('status')=='healthy'" 2>/dev/null \
    && green "Health response is valid JSON with status=healthy" \
    || red "Health response is not valid JSON or missing status=healthy"
else
  red "Health endpoint returned HTTP ${HTTP_CODE} (expected 200)"
fi

# -------------------------------------------------------
# Step 4: R version check (>= 4.3)
# -------------------------------------------------------
echo ""
echo ">>> Step 4: Checking R version..."
R_VER=$(docker compose exec -T $SERVICE R --version 2>&1 | head -1)
echo "   ${R_VER}"
echo "$R_VER" | grep -qE "R version [4-9]\.[3-9]" \
  && green "R version >= 4.3" \
  || red "R version check failed: ${R_VER}"

# -------------------------------------------------------
# Step 5: Python version check (>= 3.10)
# -------------------------------------------------------
echo ""
echo ">>> Step 5: Checking Python version..."
PY_VER=$(docker compose exec -T $SERVICE python3 --version 2>&1)
echo "   ${PY_VER}"
echo "$PY_VER" | grep -qE "Python 3\.(1[0-9]|[2-9][0-9])" \
  && green "Python version >= 3.10" \
  || red "Python version check failed: ${PY_VER}"

# -------------------------------------------------------
# Step 6: Quarto version check
# -------------------------------------------------------
echo ""
echo ">>> Step 6: Checking Quarto version..."
Q_VER=$(docker compose exec -T $SERVICE quarto --version 2>&1)
echo "   Quarto: ${Q_VER}"
echo "$Q_VER" | grep -qE "^[0-9]+\.[0-9]+" \
  && green "Quarto version is valid" \
  || red "Quarto version check failed: ${Q_VER}"

# -------------------------------------------------------
# Step 7: Locale check (en_US.UTF-8)
# -------------------------------------------------------
echo ""
echo ">>> Step 7: Checking locale..."
LOCALE_OUT=$(docker compose exec -T $SERVICE locale 2>&1)
echo "   ${LOCALE_OUT}" | head -3
echo "$LOCALE_OUT" | grep -q "en_US.UTF-8" \
  && green "Locale is en_US.UTF-8" \
  || red "Locale check failed"

# -------------------------------------------------------
# Step 8: Volume mount test
# -------------------------------------------------------
echo ""
echo ">>> Step 8: Testing volume mount..."
docker compose exec -T $SERVICE bash -c 'echo "volume-test" > /data/verify_mount_test.txt' 2>&1
if [ -f "./data/verify_mount_test.txt" ]; then
  CONTENTS=$(cat ./data/verify_mount_test.txt)
  if [ "$CONTENTS" = "volume-test" ]; then
    green "Volume mount works (write inside container, read on host)"
  else
    red "Volume mount file has unexpected contents: ${CONTENTS}"
  fi
  rm -f ./data/verify_mount_test.txt
else
  red "Volume mount test failed - file not found on host"
fi

# -------------------------------------------------------
# Step 9: Quarto PDF rendering test
# -------------------------------------------------------
echo ""
echo ">>> Step 9: Testing Quarto PDF rendering..."
docker compose exec -T $SERVICE bash -c '
cat > /tmp/test_render.qmd << "QMDEOF"
---
title: "Verification Test"
format: pdf
---

Hello from ResilienceScan container verification.
QMDEOF
quarto render /tmp/test_render.qmd --to pdf 2>&1
' 2>&1
if docker compose exec -T $SERVICE test -f /tmp/test_render.pdf 2>/dev/null; then
  green "Quarto PDF rendering works"
else
  red "Quarto PDF rendering failed"
fi

# -------------------------------------------------------
# Step 10: Cleanup
# -------------------------------------------------------
echo ""
echo ">>> Step 10: Cleaning up..."
docker compose down 2>&1
green "Container stopped and removed"

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo ""
echo "============================================="
echo "Verification Summary"
echo "============================================="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"
echo ""
if [ $FAIL -eq 0 ]; then
  echo -e "\033[32mAll checks passed!\033[0m"
  exit 0
else
  echo -e "\033[31m${FAIL} check(s) failed. Review output above.\033[0m"
  exit 1
fi
