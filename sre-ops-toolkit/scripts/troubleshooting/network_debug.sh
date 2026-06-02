#!/bin/bash
# =============================================================================
# network_debug.sh
# Description : TCP/UDP connectivity diagnostic tool.
#               Checks DNS resolution, ICMP ping, TCP port reachability,
#               and HTTP response for a given host.
#               Useful first step when investigating "service unreachable" alerts.
# Usage       : bash network_debug.sh <host> [port] [--http]
# Examples    :
#   bash network_debug.sh google.com 443 --http
#   bash network_debug.sh 10.0.0.5 5432
# =============================================================================

set -uo pipefail

# ---------- Colors -----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# ---------- Input validation -------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <host> [port] [--http]"
  echo "Examples:"
  echo "  $0 my-service.internal 8080 --http"
  echo "  $0 10.0.0.5 5432"
  exit 1
fi

HOST="$1"
PORT="${2:-}"
CHECK_HTTP=false
[[ "${3:-}" == "--http" ]] && CHECK_HTTP=true

TIMEOUT=5

echo ""
echo "========================================"
echo "  Network Debug Report"
echo "  Host: $HOST | Port: ${PORT:-N/A}"
echo "  $(date)"
echo "========================================"

# ---------- 1. DNS Resolution ------------------------------------------------
echo ""
info "Step 1: DNS Resolution"
if RESOLVED_IPS=$(dig +short "$HOST" 2>/dev/null || nslookup "$HOST" 2>/dev/null | grep Address | tail -n +2); then
  if [[ -n "$RESOLVED_IPS" ]]; then
    pass "Resolved $HOST →"
    echo "$RESOLVED_IPS" | sed 's/^/         /'
  else
    warn "No A/AAAA records found for $HOST (may be IP already)"
  fi
else
  fail "DNS resolution failed for $HOST"
fi

# ---------- 2. ICMP Ping -----------------------------------------------------
echo ""
info "Step 2: ICMP Ping (3 packets)"
if ping -c 3 -W "$TIMEOUT" "$HOST" > /dev/null 2>&1; then
  RTT=$(ping -c 3 -W "$TIMEOUT" "$HOST" 2>/dev/null | tail -1 | awk -F '/' '{print $5}')
  pass "Host is reachable via ICMP | avg RTT: ${RTT}ms"
else
  warn "ICMP ping failed (firewall may block ICMP — not necessarily a problem)"
fi

# ---------- 3. TCP Port Check ------------------------------------------------
if [[ -n "$PORT" ]]; then
  echo ""
  info "Step 3: TCP Port Check → $HOST:$PORT"
  if timeout "$TIMEOUT" bash -c ">/dev/tcp/$HOST/$PORT" 2>/dev/null; then
    pass "TCP connection to $HOST:$PORT succeeded"
  else
    fail "TCP connection to $HOST:$PORT FAILED (port closed or filtered)"
  fi

  # ---------- 4. HTTP Trace (optional) ---------------------------------------
  if $CHECK_HTTP; then
    echo ""
    info "Step 4: HTTP Trace → http://$HOST:$PORT"
    curl -sv --max-time "$TIMEOUT" "http://$HOST:$PORT" 2>&1 \
      | grep -E "^[<>*]|HTTP/|Connected|Trying|SSL" \
      | head -30 || warn "curl trace failed"
  fi
else
  warn "No port specified — skipping TCP and HTTP checks"
fi

# ---------- 5. Route to host -------------------------------------------------
echo ""
info "Step 5: Routing path to $HOST"
traceroute -n -m 10 "$HOST" 2>/dev/null \
  || tracepath -n "$HOST" 2>/dev/null \
  || warn "traceroute/tracepath not available"

echo ""
info "Done. Check [FAIL] lines above for actionable issues."
echo ""
