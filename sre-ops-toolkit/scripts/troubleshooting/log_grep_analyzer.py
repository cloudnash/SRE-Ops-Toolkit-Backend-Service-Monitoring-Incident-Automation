#!/usr/bin/env python3
"""
log_grep_analyzer.py
--------------------
Scans one or more log files for error patterns, summarizes findings,
and prints a concise incident-investigation report.

Designed for triage: quickly answer "What is failing and how often?"

Usage:
  python3 log_grep_analyzer.py --files /var/log/app.log
  python3 log_grep_analyzer.py --files /var/log/*.log --last-n 500
  python3 log_grep_analyzer.py --files app.log --pattern "timeout|5[0-9]{2}" --save

Options:
  --files       One or more log file paths (glob supported via shell)
  --last-n      Only analyze the last N lines per file (default: all)
  --pattern     Custom regex pattern to search for (default: built-in error patterns)
  --save        Save the report to a timestamped .txt file
"""

import re
import argparse
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

# ──────────────────────────────────────────────────────────────────────────────
# Default patterns — common backend/infrastructure error signals
# ──────────────────────────────────────────────────────────────────────────────
DEFAULT_PATTERNS = {
    "HTTP 5xx Errors":        r"\bHTTP[/ ]\d\.\d\s+5\d{2}\b|\" 5\d{2} ",
    "Timeouts":               r"\btimeout\b|\bTIMEOUT\b|\btimed out\b",
    "Connection Refused":     r"connection refused|Connection refused|ECONNREFUSED",
    "Out of Memory":          r"out of memory|OOM|Killed process",
    "Exception / Stacktrace": r"Exception|Traceback|panic:|FATAL|fatal error",
    "Database Errors":        r"could not connect to server|deadlock|lock wait timeout|relation .* does not exist",
    "Disk / IO Errors":       r"no space left|Input/output error|Read-only file system",
    "Auth Failures":          r"401|403|unauthorized|Unauthorized|Permission denied",
}

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

def read_lines(filepath: str, last_n: int | None) -> list[str]:
    """Read lines from a file, optionally only the last N."""
    path = Path(filepath)
    if not path.exists():
        print(f"[WARN] File not found: {filepath}")
        return []
    try:
        lines = path.read_text(errors="replace").splitlines()
        return lines[-last_n:] if last_n else lines
    except PermissionError:
        print(f"[WARN] Permission denied: {filepath}")
        return []


def scan_lines(lines: list[str], patterns: dict[str, str]) -> dict:
    """
    Scan lines against each pattern.
    Returns: { pattern_name: { "count": int, "sample_lines": [str, ...] } }
    """
    results = {name: {"count": 0, "samples": []} for name in patterns}

    compiled = {name: re.compile(pat, re.IGNORECASE) for name, pat in patterns.items()}

    for line in lines:
        for name, regex in compiled.items():
            if regex.search(line):
                results[name]["count"] += 1
                # Keep up to 3 sample lines per pattern
                if len(results[name]["samples"]) < 3:
                    results[name]["samples"].append(line.strip())

    return results


def print_report(results_by_file: dict, total_lines: int, patterns: dict):
    """Print a formatted investigation summary."""
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    lines_out = []
    lines_out.append("=" * 64)
    lines_out.append("  Log Analysis Report")
    lines_out.append(f"  Generated: {now}")
    lines_out.append(f"  Total lines scanned: {total_lines}")
    lines_out.append("=" * 64)

    # Aggregate counts across all files
    aggregate: dict[str, dict] = {name: {"count": 0, "samples": []} for name in patterns}
    for _filepath, scan_result in results_by_file.items():
        for name, data in scan_result.items():
            aggregate[name]["count"] += data["count"]
            aggregate[name]["samples"].extend(data["samples"])

    # Sort by hit count descending
    sorted_patterns = sorted(aggregate.items(), key=lambda x: x[1]["count"], reverse=True)

    found_any = False
    for name, data in sorted_patterns:
        if data["count"] == 0:
            continue
        found_any = True
        lines_out.append(f"\n🔴 {name}: {data['count']} occurrence(s)")
        for i, sample in enumerate(data["samples"][:3], 1):
            # Truncate long lines
            truncated = sample[:120] + "..." if len(sample) > 120 else sample
            lines_out.append(f"   [{i}] {truncated}")

    if not found_any:
        lines_out.append("\n✅ No matching error patterns found in the scanned lines.")
    else:
        lines_out.append("\n" + "-" * 64)
        lines_out.append("Recommendation: Focus on the highest-count patterns first.")
        lines_out.append("Search the full log file for the sample lines above to see context.")

    lines_out.append("=" * 64)
    return "\n".join(lines_out)


# ──────────────────────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Log pattern analyzer for incident triage")
    parser.add_argument("--files",   nargs="+", required=True,       help="Log file path(s)")
    parser.add_argument("--last-n",  type=int,  default=None,        help="Analyze only last N lines per file")
    parser.add_argument("--pattern", type=str,  default=None,        help="Custom regex pattern (overrides defaults)")
    parser.add_argument("--save",    action="store_true",            help="Save report to timestamped file")
    args = parser.parse_args()

    # Build pattern set
    if args.pattern:
        patterns = {"Custom Pattern": args.pattern}
    else:
        patterns = DEFAULT_PATTERNS

    results_by_file = {}
    total_lines = 0

    for filepath in args.files:
        lines = read_lines(filepath, args.last_n)
        total_lines += len(lines)
        results_by_file[filepath] = scan_lines(lines, patterns)

    if total_lines == 0:
        print("[ERROR] No lines were read. Check file paths and permissions.")
        sys.exit(1)

    report = print_report(results_by_file, total_lines, patterns)
    print(report)

    if args.save:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        outfile = f"log_analysis_{timestamp}.txt"
        Path(outfile).write_text(report)
        print(f"\nReport saved → {outfile}")


if __name__ == "__main__":
    main()
