#!/usr/bin/env python3
"""
k8s_pod_monitor.py
------------------
Watches Kubernetes pods in a given namespace and reports:
  - Pods NOT in Running/Completed state
  - Pods with high restart counts (default threshold: 5)
  - CrashLoopBackOff pods (immediate red flag)

Requires: kubectl configured with access to the target cluster.

Usage:
  python3 k8s_pod_monitor.py --namespace default --restart-threshold 5
  python3 k8s_pod_monitor.py --namespace production --watch

Options:
  --namespace         Kubernetes namespace to inspect (default: default)
  --restart-threshold Flag pods with restarts above this count (default: 5)
  --watch             Re-check every 30 seconds (loop mode)
"""

import subprocess
import json
import time
import argparse
import sys
from datetime import datetime

# ──────────────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────────────
HEALTHY_PHASES = {"Running", "Succeeded"}
CHECK_INTERVAL_SECONDS = 30

# ANSI colors
RED    = "\033[0;31m"
YELLOW = "\033[1;33m"
GREEN  = "\033[0;32m"
CYAN   = "\033[0;36m"
RESET  = "\033[0m"


# ──────────────────────────────────────────────────────────────────────────────
# kubectl helpers
# ──────────────────────────────────────────────────────────────────────────────

def run_kubectl(args: list[str]) -> dict | None:
    """Run a kubectl command and return parsed JSON output, or None on error."""
    cmd = ["kubectl"] + args + ["-o", "json"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        if result.returncode != 0:
            print(f"{RED}[ERROR]{RESET} kubectl failed: {result.stderr.strip()}")
            return None
        return json.loads(result.stdout)
    except FileNotFoundError:
        print(f"{RED}[ERROR]{RESET} kubectl not found. Is it installed and in PATH?")
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print(f"{RED}[ERROR]{RESET} kubectl timed out.")
        return None
    except json.JSONDecodeError as e:
        print(f"{RED}[ERROR]{RESET} Failed to parse kubectl output: {e}")
        return None


def get_pods(namespace: str) -> list[dict]:
    """Fetch all pods in the given namespace."""
    data = run_kubectl(["get", "pods", "-n", namespace])
    if not data:
        return []
    return data.get("items", [])


# ──────────────────────────────────────────────────────────────────────────────
# Analysis
# ──────────────────────────────────────────────────────────────────────────────

def get_container_restarts(pod: dict) -> int:
    """Sum restart counts across all containers in a pod."""
    restarts = 0
    container_statuses = pod.get("status", {}).get("containerStatuses", [])
    for cs in container_statuses:
        restarts += cs.get("restartCount", 0)
    return restarts


def is_crashloop(pod: dict) -> bool:
    """Return True if any container in the pod is in CrashLoopBackOff."""
    container_statuses = pod.get("status", {}).get("containerStatuses", [])
    for cs in container_statuses:
        waiting = cs.get("state", {}).get("waiting", {})
        if waiting.get("reason") == "CrashLoopBackOff":
            return True
    return False


def analyze_pods(pods: list[dict], restart_threshold: int) -> dict:
    """
    Categorize pods into:
      - unhealthy:  not in a healthy phase
      - high_restarts: restart count above threshold
      - crashloop: CrashLoopBackOff containers
      - healthy: everything else
    """
    results = {"unhealthy": [], "high_restarts": [], "crashloop": [], "healthy": []}

    for pod in pods:
        name      = pod["metadata"]["name"]
        namespace = pod["metadata"]["namespace"]
        phase     = pod.get("status", {}).get("phase", "Unknown")
        restarts  = get_container_restarts(pod)
        crashloop = is_crashloop(pod)

        info = {
            "name":      name,
            "namespace": namespace,
            "phase":     phase,
            "restarts":  restarts,
        }

        if crashloop:
            results["crashloop"].append(info)
        elif phase not in HEALTHY_PHASES:
            results["unhealthy"].append(info)
        elif restarts >= restart_threshold:
            results["high_restarts"].append(info)
        else:
            results["healthy"].append(info)

    return results


# ──────────────────────────────────────────────────────────────────────────────
# Reporting
# ──────────────────────────────────────────────────────────────────────────────

def print_report(results: dict, namespace: str, restart_threshold: int):
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    total = sum(len(v) for v in results.values())

    print(f"\n{CYAN}{'─'*60}{RESET}")
    print(f"{CYAN}  Pod Health Report — namespace: {namespace}{RESET}")
    print(f"{CYAN}  Checked at: {now} | Total pods: {total}{RESET}")
    print(f"{CYAN}{'─'*60}{RESET}")

    if results["crashloop"]:
        print(f"\n{RED}🔴 CrashLoopBackOff ({len(results['crashloop'])} pods):{RESET}")
        for p in results["crashloop"]:
            print(f"   {p['name']}  [restarts: {p['restarts']}]")

    if results["unhealthy"]:
        print(f"\n{YELLOW}🟡 Unhealthy Phase ({len(results['unhealthy'])} pods):{RESET}")
        for p in results["unhealthy"]:
            print(f"   {p['name']}  [phase: {p['phase']}]  [restarts: {p['restarts']}]")

    if results["high_restarts"]:
        print(f"\n{YELLOW}⚠️  High Restarts >{restart_threshold} ({len(results['high_restarts'])} pods):{RESET}")
        for p in results["high_restarts"]:
            print(f"   {p['name']}  [restarts: {p['restarts']}]")

    if results["healthy"]:
        print(f"\n{GREEN}✅ Healthy ({len(results['healthy'])} pods){RESET}")

    print()


# ──────────────────────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Kubernetes pod health monitor")
    parser.add_argument("--namespace",         default="default",  help="K8s namespace (default: default)")
    parser.add_argument("--restart-threshold", default=5, type=int, help="Restart count alert threshold (default: 5)")
    parser.add_argument("--watch",             action="store_true", help="Run in a loop every 30 seconds")
    args = parser.parse_args()

    print(f"Starting pod monitor | namespace={args.namespace} | restart-threshold={args.restart_threshold}")

    while True:
        pods    = get_pods(args.namespace)
        results = analyze_pods(pods, args.restart_threshold)
        print_report(results, args.namespace, args.restart_threshold)

        if not args.watch:
            break

        print(f"Next check in {CHECK_INTERVAL_SECONDS}s ... (Ctrl+C to stop)")
        time.sleep(CHECK_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
