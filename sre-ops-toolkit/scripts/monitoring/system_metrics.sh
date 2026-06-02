#!/bin/bash
# =============================================================================
# system_metrics.sh
# Description : Captures a point-in-time snapshot of key system metrics:
#               CPU usage, memory, disk, top processes, and load average.
#               Useful as a first step during incident investigation.
# Usage       : bash system_metrics.sh [--save]
#               --save  → write output to a timestamped file instead of stdout
# =============================================================================

set -euo pipefail

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
SAVE_TO_FILE=false

for arg in "$@"; do
  [[ "$arg" == "--save" ]] && SAVE_TO_FILE=true
done

OUTPUT_FILE="metrics_${TIMESTAMP}.txt"

# ---------- Helper -----------------------------------------------------------
section() {
  echo ""
  echo "========================================"
  echo "  $1"
  echo "========================================"
}

collect_metrics() {
  echo "System Metrics Snapshot"
  echo "Captured at: $(date)"
  echo "Hostname:    $(hostname)"
  echo "Kernel:      $(uname -r)"

  section "CPU — Load Average (1m / 5m / 15m)"
  uptime

  section "CPU — Usage (top 5 processes)"
  # ps flags: sort by %CPU descending, show top 5 (skip header)
  ps aux --sort=-%cpu | head -6

  section "Memory Usage"
  free -h

  section "Disk Usage"
  df -h --exclude-type=tmpfs --exclude-type=devtmpfs

  section "Top Memory Consumers (top 5 processes)"
  ps aux --sort=-%mem | head -6

  section "Network Interfaces"
  ip -brief address show 2>/dev/null || ifconfig -s 2>/dev/null || echo "ip/ifconfig not available"

  section "Listening Ports"
  ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || echo "ss/netstat not available"

  section "Recent Kernel / OOM Messages (last 20 lines)"
  dmesg --level=err,warn 2>/dev/null | tail -20 || echo "dmesg not accessible"
}

# ---------- Output -----------------------------------------------------------
if $SAVE_TO_FILE; then
  collect_metrics | tee "$OUTPUT_FILE"
  echo ""
  echo "Snapshot saved → $OUTPUT_FILE"
else
  collect_metrics
fi
