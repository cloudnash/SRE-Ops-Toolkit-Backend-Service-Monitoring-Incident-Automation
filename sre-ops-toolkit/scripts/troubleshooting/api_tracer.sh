#!/bin/bash
# =============================================================================
# api_tracer.sh
# Description : Traces an API call end-to-end: DNS, TLS, connection, TTFB,
#               and total time. Prints headers + body summary.
#               Useful for investigating API latency or failure reports.
# Usage       : bash api_tracer.sh <URL> [METHOD] [BODY_JSON]
# Examples    :
#   bash api_tracer.sh https://api.example.com/v1/health
#   bash api_tracer.sh https://api.example.com/v1/users GET
#   bash api_tracer.sh https://api.example.com/v1/orders POST '{"id": "123"}'
# =============================================================================

set -uo pipefail

# ---------- Colors -----------------------------------------------------------
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ---------- Input validation -------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <URL> [METHOD] [BODY_JSON]"
  echo "Example: $0 https://httpbin.org/get GET"
  exit 1
fi

URL="$1"
METHOD="${2:-GET}"
BODY="${3:-}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo ""
echo -e "${CYAN}========================================"
echo -e "  API Trace Report"
echo -e "  $TIMESTAMP"
echo -e "========================================${NC}"
echo -e "  URL:    $URL"
echo -e "  Method: $METHOD"
[[ -n "$BODY" ]] && echo -e "  Body:   $BODY"
echo ""

# ---------- Timing format for curl -------------------------------------------
# Each variable maps to a curl timing metric
CURL_TIMING_FORMAT="\
DNS Lookup:        %{time_namelookup}s
TCP Connect:       %{time_connect}s
TLS Handshake:     %{time_appconnect}s
Time to First Byte:%{time_starttransfer}s
Total Time:        %{time_total}s
HTTP Status:       %{http_code}
Response Size:     %{size_download} bytes
"

# ---------- Build curl command -----------------------------------------------
CURL_CMD=(
  curl
  --silent
  --show-error
  --max-time 15
  --request "$METHOD"
  --dump-header /tmp/api_trace_headers_$$.txt  # write headers to temp file
  --write-out "$CURL_TIMING_FORMAT"
  --output /tmp/api_trace_body_$$.txt           # write body to temp file
)

# Add Content-Type and body for non-GET requests
if [[ -n "$BODY" ]]; then
  CURL_CMD+=(--header "Content-Type: application/json" --data "$BODY")
fi

CURL_CMD+=("$URL")

# ---------- Run trace --------------------------------------------------------
echo -e "${CYAN}── Timing Breakdown ───────────────────${NC}"
"${CURL_CMD[@]}" 2>&1 || { echo -e "${RED}[ERROR]${NC} curl failed. Check the URL and network connectivity."; exit 1; }

# ---------- Response headers -------------------------------------------------
echo ""
echo -e "${CYAN}── Response Headers ───────────────────${NC}"
if [[ -f /tmp/api_trace_headers_$$.txt ]]; then
  cat /tmp/api_trace_headers_$$.txt
fi

# ---------- Response body (first 40 lines) -----------------------------------
echo ""
echo -e "${CYAN}── Response Body (first 40 lines) ─────${NC}"
if [[ -f /tmp/api_trace_body_$$.txt ]]; then
  head -40 /tmp/api_trace_body_$$.txt
  BODY_LINES=$(wc -l < /tmp/api_trace_body_$$.txt)
  if (( BODY_LINES > 40 )); then
    echo -e "${YELLOW}... ($((BODY_LINES - 40)) more lines truncated)${NC}"
  fi
fi

# ---------- Cleanup ----------------------------------------------------------
rm -f /tmp/api_trace_headers_$$.txt /tmp/api_trace_body_$$.txt

echo ""
echo -e "${GREEN}Trace complete.${NC}"
echo ""
