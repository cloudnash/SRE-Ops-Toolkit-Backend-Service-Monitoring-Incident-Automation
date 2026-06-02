# Incident Response Runbook

> **Purpose**: Step-by-step guide for triaging and resolving backend service incidents.
> Use this document when you receive an alert or are paged for a service issue.

---

## Step 0 — First 2 Minutes: Capture State

**Before touching anything**, run the snapshot script. It freezes the evidence.

```bash
bash scripts/automation/incident_snapshot.sh --namespace <your-namespace>
```

This creates `incident_<timestamp>/` with system metrics, pod states, logs, and network info.

---

## Step 1 — Understand the Alert

Answer these three questions before acting:

| Question | Where to check |
|---|---|
| Which service is affected? | Alert label `job=` or `service=` |
| What is the symptom? | Alert name + description (e.g. "HighErrorRate", "PodCrashLooping") |
| How long has it been firing? | Alert `for:` duration + Grafana time range |

---

## Step 2 — Service Health Check

```bash
# Check if the HTTP endpoint is responding
bash scripts/monitoring/check_service_health.sh https://<service-host>/health

# Trace a single API call end-to-end
bash scripts/troubleshooting/api_tracer.sh https://<service-host>/api/v1/status
```

**What to look for:**
- `[UNREACHABLE]` → Network or DNS problem → go to Step 4
- HTTP `5xx` → Application error → go to Step 5
- High response time → Go to Step 3 (Kubernetes) or Step 5 (application logs)

---

## Step 3 — Check Kubernetes Pod Health

```bash
# One-time check
python3 scripts/monitoring/k8s_pod_monitor.py --namespace <namespace>

# Watch mode (re-checks every 30s)
python3 scripts/monitoring/k8s_pod_monitor.py --namespace <namespace> --watch
```

**Common findings and actions:**

| Finding | Action |
|---|---|
| `CrashLoopBackOff` | Check pod logs: `kubectl logs <pod> -n <ns> --previous` |
| Pod stuck in `Pending` | Check node resources: `kubectl describe pod <pod>` |
| High restart count (>5) | Check logs for OOM or unhandled exception |
| Pod `NotReady` | Check readiness probe failure in `kubectl describe pod` |

**Safe pod restart** (only when confirmed safe):

```bash
bash scripts/automation/auto_restart_pod.sh <pod-name> --namespace <namespace>
```

---

## Step 4 — Network Debugging

```bash
bash scripts/troubleshooting/network_debug.sh <host> <port> --http
```

**Checklist:**
- [ ] DNS resolves correctly?
- [ ] Host is reachable via ping?
- [ ] TCP port accepts connections?
- [ ] HTTP returns expected status?

If DNS fails → check CoreDNS pods in `kube-system` namespace.  
If TCP fails → check Security Groups / Network Policies / firewall rules.

---

## Step 5 — Log Analysis

```bash
# Scan application logs for error patterns
python3 scripts/troubleshooting/log_grep_analyzer.py \
  --files /var/log/app.log \
  --last-n 1000

# Or from a Kubernetes pod
kubectl logs <pod-name> -n <namespace> --tail=500 > /tmp/pod.log
python3 scripts/troubleshooting/log_grep_analyzer.py --files /tmp/pod.log
```

**Key patterns to look for:**
- `CrashLoopBackOff` + OOM → Memory limit too low → increase `resources.limits.memory`
- `timeout` errors → Downstream service slow → check that service's health
- `connection refused` → Target service down → check that service
- `401/403` → Auth token expired or misconfigured

---

## Step 6 — Escalation

Escalate to the development team if:
- The root cause is in application code (not infrastructure)
- A database migration or deployment is needed
- The incident has been ongoing for >30 minutes with no resolution path

**When escalating, share:**
1. The `incident_<timestamp>/` snapshot folder
2. Output from `log_grep_analyzer.py`
3. Grafana dashboard link with the relevant time window
4. Your hypothesis of the root cause

---

## Step 7 — Resolution Checklist

- [ ] Service is returning healthy HTTP responses
- [ ] No pods in CrashLoopBackOff or Pending
- [ ] Error rate below 1%
- [ ] Latency back to baseline
- [ ] Alert has resolved (or been manually silenced with justification)
- [ ] Post-incident report started (see template)

---

## Common Commands Reference

```bash
# Get all pods across all namespaces
kubectl get pods --all-namespaces

# Describe a pod (events, probe failures, resource pressure)
kubectl describe pod <pod-name> -n <namespace>

# Get logs from a crashed container
kubectl logs <pod-name> -n <namespace> --previous

# Force delete a stuck pod
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force

# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods -n <namespace>

# Restart a deployment (rolls all pods)
kubectl rollout restart deployment/<deployment-name> -n <namespace>

# Check rollout status
kubectl rollout status deployment/<deployment-name> -n <namespace>
```
