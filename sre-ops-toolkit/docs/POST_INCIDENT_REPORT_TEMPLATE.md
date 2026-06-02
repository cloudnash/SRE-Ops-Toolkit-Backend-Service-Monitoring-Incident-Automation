# Post-Incident Report

> **Fill this out within 24 hours of incident resolution.**
> The goal is to understand what happened, why it happened, and how to prevent it.
> This is a blameless review — focus on systems and processes, not individuals.

---

## Summary

| Field | Value |
|---|---|
| **Incident ID** | INC-YYYY-NNN |
| **Date** | YYYY-MM-DD |
| **Duration** | X hours Y minutes |
| **Severity** | P1 / P2 / P3 |
| **Affected Services** | e.g. API Gateway, Auth Service |
| **Author** | Your Name |
| **Reviewers** | Names |

---

## Impact

**User-facing impact:**
> _Describe what users experienced. e.g. "Login requests returned HTTP 503 for 22 minutes."_

**Business impact:**
> _Quantify where possible. e.g. "Estimated X requests failed. No data loss."_

---

## Timeline

All times in UTC.

| Time (UTC) | Event |
|---|---|
| HH:MM | Alert fired: `<AlertName>` |
| HH:MM | On-call engineer paged |
| HH:MM | Investigation started |
| HH:MM | Root cause identified: ___ |
| HH:MM | Mitigation applied: ___ |
| HH:MM | Service restored to healthy state |
| HH:MM | Alert resolved |

---

## Root Cause

> _One or two sentences describing the technical root cause._
>
> Example: "A deployment at 14:32 UTC introduced a missing environment variable
> `DB_HOST`, causing all database connections to fail with `connection refused`."

---

## Contributing Factors

> _What made this worse, or allowed it to happen?_

- e.g. No automated rollback triggered because rollout health checks were not configured
- e.g. Alert threshold was set too high, delaying detection by 8 minutes
- e.g. Missing runbook for this type of failure

---

## What Went Well

> _What helped resolve the incident quickly?_

- e.g. Incident snapshot script captured the state before the crash logs rotated
- e.g. Clear Grafana dashboard made the error rate spike immediately visible
- e.g. Good communication in the incident channel

---

## What Could Be Improved

> _Be specific — these become action items below._

- e.g. No health check on the deploy step meant the bad deploy went undetected for 8 minutes
- e.g. Pod logs were not centralized; had to SSH to each node manually
- e.g. Runbook did not cover this failure mode

---

## Action Items

| # | Action | Owner | Due Date | Status |
|---|---|---|---|---|
| 1 | Add readiness probe to `<service>` deployment | @engineer | YYYY-MM-DD | Open |
| 2 | Lower `HighErrorRate` alert threshold from 10% to 5% | @sre | YYYY-MM-DD | Open |
| 3 | Add `<failure-mode>` to incident runbook | @author | YYYY-MM-DD | Open |

---

## Metrics

| Metric | Value |
|---|---|
| Time to Detect (alert fire → first ack) | X min |
| Time to Diagnose (ack → root cause found) | X min |
| Time to Resolve (root cause → service healthy) | X min |
| Total Incident Duration | X min |

---

## Attachments

- [ ] Incident snapshot folder: `incident_<timestamp>/`
- [ ] Grafana dashboard screenshot (time window of incident)
- [ ] Relevant log excerpts from `log_grep_analyzer.py`
