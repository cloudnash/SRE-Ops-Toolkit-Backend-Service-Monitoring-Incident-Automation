#!/bin/bash
# =============================================================================
# auto_restart_pod.sh
# Description : Safely restarts a Kubernetes pod with pre-flight checks
#               and post-restart validation.
#               Refuses to restart if the deployment has only 1 replica
#               (would cause downtime) unless --force is passed.
# Usage       : bash auto_restart_pod.sh <pod-name> --namespace <ns> [--force]
# Examples    :
#   bash auto_restart_pod.sh api-server-7d9f8b-xkl2p --namespace production
#   bash auto_restart_pod.sh worker-abc123 --namespace staging --force
# =============================================================================

set -uo pipefail

# ---------- Colors -----------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
pass()  { echo -e "${GREEN}[PASS]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
abort() { echo -e "${RED}[ABORT]${NC} $*"; exit 1; }

# ---------- Input parsing ----------------------------------------------------
POD_NAME=""
NAMESPACE="default"
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace|-n) NAMESPACE="$2"; shift 2 ;;
    --force)        FORCE=true; shift ;;
    -*)             echo "Unknown flag: $1"; exit 1 ;;
    *)              POD_NAME="$1"; shift ;;
  esac
done

if [[ -z "$POD_NAME" ]]; then
  echo "Usage: $0 <pod-name> --namespace <namespace> [--force]"
  exit 1
fi

echo ""
echo "========================================"
echo "  Pod Restart: $POD_NAME"
echo "  Namespace:   $NAMESPACE"
echo "========================================"
echo ""

# ---------- Pre-flight 1: kubectl available ----------------------------------
if ! command -v kubectl &>/dev/null; then
  abort "kubectl not found. Install kubectl and configure cluster access."
fi

# ---------- Pre-flight 2: Pod exists -----------------------------------------
info "Checking pod exists..."
if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
  abort "Pod '$POD_NAME' not found in namespace '$NAMESPACE'."
fi
pass "Pod found"

# ---------- Pre-flight 3: Get owning deployment ------------------------------
info "Finding owning deployment..."
OWNER_REF=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null)

if [[ "$OWNER_REF" == "ReplicaSet" ]]; then
  DEPLOYMENT=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.metadata.ownerReferences[0].name}' 2>/dev/null \
    | sed 's/-[^-]*$//')  # strip ReplicaSet hash to get deployment name
  info "Owned by deployment: $DEPLOYMENT"

  # Check replica count — avoid taking the service down
  REPLICAS=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

  if [[ "$REPLICAS" -le 1 ]] && ! $FORCE; then
    abort "Deployment '$DEPLOYMENT' has only $REPLICAS replica(s). Restarting would cause downtime. Use --force to override."
  elif [[ "$REPLICAS" -le 1 ]] && $FORCE; then
    warn "Only $REPLICAS replica(s) — proceeding anyway (--force passed)"
  else
    pass "Replica count: $REPLICAS (safe to restart one pod)"
  fi
else
  warn "Pod is not managed by a Deployment (owner: ${OWNER_REF:-none}). Restarting will not create a replacement."
  if ! $FORCE; then
    abort "Use --force to restart unmanaged pods."
  fi
fi

# ---------- Pre-flight 4: Current pod state ----------------------------------
info "Current pod state:"
kubectl get pod "$POD_NAME" -n "$NAMESPACE" \
  -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount,AGE:.metadata.creationTimestamp"

echo ""
read -r -p "Proceed with restart? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Cancelled."
  exit 0
fi

# ---------- Restart ----------------------------------------------------------
info "Deleting pod $POD_NAME (Kubernetes will reschedule it)..."
kubectl delete pod "$POD_NAME" -n "$NAMESPACE"

# ---------- Post-restart validation ------------------------------------------
info "Waiting for replacement pod to appear (up to 60s)..."
sleep 5

ATTEMPTS=0
MAX_ATTEMPTS=12  # 12 × 5s = 60s

while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
  NEW_POD_STATUS=$(kubectl get pods -n "$NAMESPACE" \
    -l "$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" \
      --ignore-not-found \
      -o jsonpath='{range .metadata.labels}{@k}={@v},{end}' 2>/dev/null | sed 's/,$//')" \
    --field-selector="status.phase=Running" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$NEW_POD_STATUS" ]]; then
    pass "New pod is Running: $NEW_POD_STATUS"
    break
  fi

  ATTEMPTS=$((ATTEMPTS + 1))
  echo "   Waiting... ($((ATTEMPTS * 5))s elapsed)"
  sleep 5
done

if [[ $ATTEMPTS -ge $MAX_ATTEMPTS ]]; then
  warn "New pod did not reach Running state within 60s. Check with: kubectl get pods -n $NAMESPACE"
fi

echo ""
info "Final pod list in namespace '$NAMESPACE':"
kubectl get pods -n "$NAMESPACE"
echo ""
