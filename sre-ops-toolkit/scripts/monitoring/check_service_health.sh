#!/bin/bash
# =============================================================================
# check_service_health.sh
# Description : HTTP health check for backend services with status reporting.
#               Sends a GET request to the given endpoint and reports HTTP
#               status, response time, and whether the service is healthy.
# Usage       : bash check_service_health.sh <URL> [timeout_seconds]
# Example     : bash check_service_health.sh http://localhost:8080/health 5
# =============================================================================

set -euo pipefail

# ---------- Defaults ---------------------------------------------------------
DEFAULT_TIMEOUT=5
HEALTHY_STATUS_CODES=(200 201 204)

# ---------- Colors -----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ---------- Input validation -------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <URL> [timeout_seconds]"
  echo "Example: $0 http://localhost:8080/health 5"
  exit 1
fi

URL="$1"
TIMEOUT="${2:-$DEFAULT_TIMEOUT}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# ---------- Run the health check ---------------------------------------------
echo "[$TIMESTAMP] Checking: $URL (timeout: ${TIMEOUT}s)"

# curl flags:
#   -o /dev/null      → discard response body
#   -s                → silent (no progress bar)
#   -w "..."          → write out custom format
#   --max-time        → total timeout
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" \
  --max-time "$TIMEOUT" \
  "$URL" 2>/dev/null || echo "000")

RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" \
  --max-time "$TIMEOUT" \
  "$URL" 2>/dev/null || echo "N/A")

# ---------- Evaluate result --------------------------------------------------
IS_HEALTHY=false
for code in "${HEALTHY_STATUS_CODES[@]}"; do
  if [[ "$HTTP_STATUS" == "$code" ]]; then
    IS_HEALTHY=true
    break
  fi
done

if [[ "$HTTP_STATUS" == "000" ]]; then
  echo -e "${RED}[UNREACHABLE]${NC} $URL — Could not connect (timeout or DNS failure)"
  exit 2
elif $IS_HEALTHY; then
  echo -e "${GREEN}[HEALTHY]${NC}   HTTP $HTTP_STATUS | Response time: ${RESPONSE_TIME}s | $URL"
  exit 0
else
  echo -e "${YELLOW}[DEGRADED]${NC}  HTTP $HTTP_STATUS | Response time: ${RESPONSE_TIME}s | $URL"
  exit 1
fi
