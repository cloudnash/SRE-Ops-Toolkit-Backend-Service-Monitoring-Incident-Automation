#!/bin/bash
# =============================================================================
# incident_snapshot.sh
# Description : Captures a full environment snapshot when an incident fires.
#               Run this immediately when paged — it preserves state that may
#               change by the time you start investigating manually.
#
#               Output: incident_<timestamp>/ folder with:
#                 - system_metrics.txt   (CPU, memory, disk, load)
#                 - docker_state.txt     (running containers, recent logs)
#                 - network_state.txt    (open connections, listening ports)
#                 - k8s_state.txt        (pods, events — if kubectl available)
#                 - recent_syslog.txt    (last 100 syslog lines)
#                 - summary.txt          (quick-read first-look)
#
# Usage       : bash incident_snapshot.sh [--namespace <k8s-namespace>]
# =============================================================================

set -uo pipefail

# ---------- Config -----------------------------------------------------------
K8S_NAMESPACE="${2:-default}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
SNAPSHOT_DIR="incident_${TIMESTAMP}"
SUMMARY_FILE="$SNAPSHOT_DIR/summary.txt"

# ---------- Colors -----------------------------------------------------------
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

log() { echo -e "${CYAN}[snapshot]${NC} $*"; }
done_msg() { echo -e "${GREEN}[done]${NC} $*"; }

# ---------- Setup ------------------------------------------------------------
mkdir -p "$SNAPSHOT_DIR"
echo "Incident Snapshot" > "$SUMMARY_FILE"
echo "Captured: $(date)" >> "$SUMMARY_FILE"
echo "Hostname: $(hostname)" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

log "Starting incident snapshot → $SNAPSHOT_DIR/"
echo ""

# ── 1. System Metrics ────────────────────────────────────────────────────────
log "Capturing system metrics..."
{
  echo "=== Uptime & Load ==="
  uptime

  echo -e "\n=== CPU (top 8 processes) ==="
  ps aux --sort=-%cpu | head -9

  echo -e "\n=== Memory ==="
  free -h

  echo -e "\n=== Disk ==="
  df -h --exclude-type=tmpfs --exclude-type=devtmpfs

  echo -e "\n=== Top Memory Consumers ==="
  ps aux --sort=-%mem | head -9
} > "$SNAPSHOT_DIR/system_metrics.txt" 2>&1
done_msg "system_metrics.txt"

# Append brief summary
LOAD=$(uptime | awk -F'load average:' '{print $2}')
echo "Load average: $LOAD" >> "$SUMMARY_FILE"
MEM_FREE=$(free -h | awk '/^Mem:/{print $4}')
echo "Free memory:  $MEM_FREE" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# ── 2. Docker State ──────────────────────────────────────────────────────────
log "Capturing Docker state..."
{
  echo "=== Running Containers ==="
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null \
    || echo "Docker not available or daemon not running"

  echo -e "\n=== Containers with High Restart Count ==="
  docker ps -a --format "{{.Names}}\t{{.Status}}" 2>/dev/null | grep -i "restart" || echo "None"

  echo -e "\n=== Last 50 Lines of Each Running Container ==="
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    echo "--- Container: $name ---"
    docker logs --tail=50 "$name" 2>&1 | tail -50
    echo ""
  done < <(docker ps --format "{{.Names}}" 2>/dev/null)
} > "$SNAPSHOT_DIR/docker_state.txt" 2>&1
done_msg "docker_state.txt"

# ── 3. Network State ─────────────────────────────────────────────────────────
log "Capturing network state..."
{
  echo "=== Listening Ports ==="
  ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || echo "ss/netstat not available"

  echo -e "\n=== Established Connections (count by remote host) ==="
  ss -tn state established 2>/dev/null \
    | awk 'NR>1{print $5}' | cut -d: -f1 \
    | sort | uniq -c | sort -rn | head -20 \
    || echo "Could not retrieve established connections"

  echo -e "\n=== Network Interfaces ==="
  ip -brief addr show 2>/dev/null || ifconfig 2>/dev/null || echo "ip/ifconfig not available"
} > "$SNAPSHOT_DIR/network_state.txt" 2>&1
done_msg "network_state.txt"

# ── 4. Kubernetes State ───────────────────────────────────────────────────────
log "Capturing Kubernetes state (namespace: $K8S_NAMESPACE)..."
{
  if command -v kubectl &>/dev/null; then
    echo "=== Pod Status ==="
    kubectl get pods -n "$K8S_NAMESPACE" -o wide 2>&1

    echo -e "\n=== Recent Events (last 20) ==="
    kubectl get events -n "$K8S_NAMESPACE" --sort-by='.lastTimestamp' 2>&1 | tail -20

    echo -e "\n=== Node Status ==="
    kubectl get nodes -o wide 2>&1
  else
    echo "kubectl not found — skipping Kubernetes snapshot"
  fi
} > "$SNAPSHOT_DIR/k8s_state.txt" 2>&1
done_msg "k8s_state.txt"

# ── 5. Recent Syslog ─────────────────────────────────────────────────────────
log "Capturing recent syslog..."
{
  echo "=== Last 100 lines of syslog ==="
  tail -100 /var/log/syslog 2>/dev/null \
    || journalctl -n 100 --no-pager 2>/dev/null \
    || echo "Syslog not accessible"
} > "$SNAPSHOT_DIR/recent_syslog.txt" 2>&1
done_msg "recent_syslog.txt"

# ── Finalize summary ─────────────────────────────────────────────────────────
echo "Files in snapshot:" >> "$SUMMARY_FILE"
ls -lh "$SNAPSHOT_DIR/"  >> "$SUMMARY_FILE"

echo ""
echo "========================================"
echo -e "${GREEN}Snapshot complete → ./$SNAPSHOT_DIR/${NC}"
echo "  system_metrics.txt"
echo "  docker_state.txt"
echo "  network_state.txt"
echo "  k8s_state.txt"
echo "  recent_syslog.txt"
echo "  summary.txt"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Check summary.txt for load/memory overview"
echo "  2. Check k8s_state.txt for unhealthy pods"
echo "  3. Check docker_state.txt for container restarts"
echo "  4. Use log_grep_analyzer.py on the service log for error patterns"
echo ""
