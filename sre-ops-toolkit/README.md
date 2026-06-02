# 🛠️ SRE Ops Toolkit

> A practical Site Reliability Engineering toolkit for monitoring, troubleshooting, and automating backend service investigations — built around real-world incident response workflows.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.9%2B-blue.svg)](https://python.org)
[![Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED.svg)](https://docker.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-compatible-326CE5.svg)](https://kubernetes.io)

---

## 📌 Overview

This project simulates a real **SRE / DevOps on-call toolkit** that an engineer would use to:

- Monitor cloud-based backend services in real time
- Investigate and triage incidents (high latency, pod crashes, disk pressure, API failures)
- Automate common troubleshooting steps
- Generate post-incident reports

It is designed to reflect the daily responsibilities of a backend infrastructure support engineer working with **Linux, Docker, Kubernetes, Prometheus, and cloud APIs**.

---

## 🗂️ Project Structure

```
sre-ops-toolkit/
│
├── scripts/
│   ├── monitoring/
│   │   ├── check_service_health.sh      # HTTP health check for backend services
│   │   ├── system_metrics.sh            # CPU, memory, disk snapshot
│   │   └── k8s_pod_monitor.py           # Kubernetes pod status watcher
│   │
│   ├── troubleshooting/
│   │   ├── network_debug.sh             # TCP/UDP connectivity diagnostics
│   │   ├── log_grep_analyzer.py         # Log pattern search & error summarizer
│   │   └── api_tracer.sh                # Trace API calls with curl + timing
│   │
│   └── automation/
│       ├── incident_snapshot.sh         # Full environment snapshot on alert
│       └── auto_restart_pod.sh          # Safe Kubernetes pod restart script
│
├── dashboards/
│   └── grafana_dashboard.json           # Importable Grafana dashboard (API latency, errors)
│
├── alerts/
│   └── prometheus_alerts.yml            # Prometheus alerting rules
│
├── configs/
│   ├── docker-compose.yml               # Local stack: Prometheus + Grafana + demo app
│   └── k8s_demo_deployment.yaml         # Sample Kubernetes deployment for testing
│
├── docs/
│   ├── INCIDENT_RUNBOOK.md              # Step-by-step incident response guide
│   └── POST_INCIDENT_REPORT_TEMPLATE.md # Post-mortem report template
│
├── .github/
│   └── workflows/
│       └── lint_and_test.yml            # CI: shellcheck + python lint on push
│
└── README.md
```

---

## ✅ Skills Demonstrated

| Area | Tools / Concepts |
|---|---|
| Linux Administration | Bash scripting, cron, systemd, process management |
| Networking | TCP/IP debugging, DNS, curl tracing, port checks |
| Containerization | Docker, docker-compose |
| Orchestration | Kubernetes (kubectl, pod lifecycle) |
| Monitoring | Prometheus metrics, Grafana dashboards |
| Log Analysis | grep/awk pipelines, Python log parsing |
| Incident Response | Runbooks, snapshots, post-mortems |
| CI/CD | GitHub Actions (lint + test on push) |
| Scripting | Bash + Python automation scripts |

---

## 🚀 Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/sre-ops-toolkit.git
cd sre-ops-toolkit
```

### 2. Spin up the local monitoring stack

```bash
docker compose -f configs/docker-compose.yml up -d
```

This starts:
- **Prometheus** → http://localhost:9090
- **Grafana** → http://localhost:3000 (admin / admin)
- **Demo app** → http://localhost:8080

### 3. Import the Grafana dashboard

In Grafana: `Dashboards → Import → Upload JSON` → select `dashboards/grafana_dashboard.json`

### 4. Run a health check

```bash
bash scripts/monitoring/check_service_health.sh http://localhost:8080/health
```

### 5. Simulate an incident snapshot

```bash
bash scripts/automation/incident_snapshot.sh
```

This captures: system metrics, running containers, recent logs, and network state — all written to a timestamped `incident_<timestamp>/` folder.

---

## 📖 Documentation

- [Incident Response Runbook](docs/INCIDENT_RUNBOOK.md) — How to triage a live incident step by step
- [Post-Incident Report Template](docs/POST_INCIDENT_REPORT_TEMPLATE.md) — Template for writing post-mortems

---

## 📸 Screenshots

> _After cloning and running `docker compose up`, you'll see a live Prometheus + Grafana stack. Import the dashboard JSON to visualize service health metrics._

---

## 🧪 Testing / CI

Every push runs:
- `shellcheck` on all `.sh` scripts
- `flake8` lint on all `.py` scripts

See [`.github/workflows/lint_and_test.yml`](.github/workflows/lint_and_test.yml)

---

## 📄 License

MIT — free to use and adapt.
