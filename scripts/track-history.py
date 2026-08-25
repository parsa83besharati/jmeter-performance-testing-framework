#!/usr/bin/env python3
"""
Run History Tracker - SQLite-backed performance test history.

Stores every test run's metrics for trend analysis and regression detection.
Generates trend charts and comparison reports.

Usage:
    python3 track-history.py record <jtl-file> --test-type load --env staging
    python3 track-history.py show [--last 10] [--test-type load]
    python3 track-history.py trend --endpoint "GET /api/users" --metric p95
    python3 track-history.py compare <run-id-1> <run-id-2>
"""

import csv
import json
import sqlite3
import sys
import os
import argparse
from collections import defaultdict
from datetime import datetime
from pathlib import Path


DB_DIR = Path(__file__).parent.parent / "jmeter" / "results"
DB_PATH = DB_DIR / "run_history.db"


def get_db():
    """Get database connection, creating tables if needed."""
    DB_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row

    conn.execute("""
        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            test_type TEXT NOT NULL,
            environment TEXT DEFAULT 'development',
            jtl_file TEXT,
            total_requests INTEGER,
            total_errors INTEGER,
            error_rate REAL,
            avg_response_ms REAL,
            p50_ms INTEGER,
            p90_ms INTEGER,
            p95_ms INTEGER,
            p99_ms INTEGER,
            min_response_ms INTEGER,
            max_response_ms INTEGER,
            duration_seconds REAL,
            throughput_rps REAL,
            git_commit TEXT,
            notes TEXT
        )
    """)

    conn.execute("""
        CREATE TABLE IF NOT EXISTS endpoint_metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id INTEGER NOT NULL,
            label TEXT NOT NULL,
            total_requests INTEGER,
            total_errors INTEGER,
            error_rate REAL,
            avg_response_ms REAL,
            p50_ms INTEGER,
            p90_ms INTEGER,
            p95_ms INTEGER,
            p99_ms INTEGER,
            min_response_ms INTEGER,
            max_response_ms INTEGER,
            FOREIGN KEY (run_id) REFERENCES runs(id)
        )
    """)

    conn.commit()
    return conn


def parse_jtl(jtl_path):
    """Parse JTL file and return metrics."""
    by_label = defaultdict(list)

    with open(jtl_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            label = row.get("label", "unknown")
            elapsed = int(row.get("elapsed", 0))
            success = row.get("success", "true").lower() == "true"
            timestamp = int(row.get("timeStamp", 0))

            by_label[label].append({
                "elapsed": elapsed,
                "success": success,
                "timestamp": timestamp,
            })

    # Calculate overall metrics
    all_samples = []
    for samples in by_label.values():
        all_samples.extend(samples)

    if not all_samples:
        return None, {}

    all_times = sorted([s["elapsed"] for s in all_samples])
    total = len(all_samples)
    errors = sum(1 for s in all_samples if not s["success"])

    # Duration
    timestamps = [s["timestamp"] for s in all_samples]
    duration_ms = max(timestamps) - min(timestamps) if len(timestamps) > 1 else 1
    duration_sec = duration_ms / 1000

    overall = {
        "total_requests": total,
        "total_errors": errors,
        "error_rate": round(errors / total * 100, 2) if total > 0 else 0,
        "avg_response_ms": round(sum(all_times) / len(all_times), 1),
        "p50_ms": all_times[len(all_times) // 2],
        "p90_ms": all_times[int(len(all_times) * 0.9)],
        "p95_ms": all_times[int(len(all_times) * 0.95)],
        "p99_ms": all_times[int(len(all_times) * 0.99)],
        "min_response_ms": all_times[0],
        "max_response_ms": all_times[-1],
        "duration_seconds": round(duration_sec, 1),
        "throughput_rps": round(total / max(1, duration_sec), 2),
    }

    # Per-endpoint
    endpoint_metrics = {}
    for label, samples in by_label.items():
        times = sorted([s["elapsed"] for s in samples])
        errs = sum(1 for s in samples if not s["success"])
        endpoint_metrics[label] = {
            "total_requests": len(samples),
            "total_errors": errs,
            "error_rate": round(errs / len(samples) * 100, 2),
            "avg_response_ms": round(sum(times) / len(times), 1),
            "p50_ms": times[len(times) // 2],
            "p90_ms": times[int(len(times) * 0.9)],
            "p95_ms": times[int(len(times) * 0.95)],
            "p99_ms": times[int(len(times) * 0.99)],
            "min_response_ms": times[0],
            "max_response_ms": times[-1],
        }

    return overall, endpoint_metrics


def cmd_record(args):
    """Record a test run."""
    if not os.path.exists(args.jtl_file):
        print(f"ERROR: JTL file not found: {args.jtl_file}")
        sys.exit(1)

    print(f"Parsing: {args.jtl_file}")
    overall, endpoint_metrics = parse_jtl(args.jtl_file)

    if not overall:
        print("ERROR: No data in JTL file")
        sys.exit(1)

    conn = get_db()

    # Get git commit if available
    git_commit = None
    try:
        import subprocess
        result = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True)
        if result.returncode == 0:
            git_commit = result.stdout.strip()
    except Exception:
        pass

    cursor = conn.execute("""
        INSERT INTO runs (
            timestamp, test_type, environment, jtl_file,
            total_requests, total_errors, error_rate,
            avg_response_ms, p50_ms, p90_ms, p95_ms, p99_ms,
            min_response_ms, max_response_ms, duration_seconds,
            throughput_rps, git_commit, notes
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        datetime.now().isoformat(),
        args.test_type,
        args.env,
        os.path.basename(args.jtl_file),
        overall["total_requests"],
        overall["total_errors"],
        overall["error_rate"],
        overall["avg_response_ms"],
        overall["p50_ms"],
        overall["p90_ms"],
        overall["p95_ms"],
        overall["p99_ms"],
        overall["min_response_ms"],
        overall["max_response_ms"],
        overall["duration_seconds"],
        overall["throughput_rps"],
        git_commit,
        args.notes,
    ))

    run_id = cursor.lastrowid

    # Insert endpoint metrics
    for label, ep in endpoint_metrics.items():
        conn.execute("""
            INSERT INTO endpoint_metrics (
                run_id, label, total_requests, total_errors, error_rate,
                avg_response_ms, p50_ms, p90_ms, p95_ms, p99_ms,
                min_response_ms, max_response_ms
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            run_id, label,
            ep["total_requests"], ep["total_errors"], ep["error_rate"],
            ep["avg_response_ms"], ep["p50_ms"], ep["p90_ms"], ep["p95_ms"], ep["p99_ms"],
            ep["min_response_ms"], ep["max_response_ms"],
        ))

    conn.commit()
    conn.close()

    print(f"\nRun recorded: #{run_id}")
    print(f"  Test Type: {args.test_type}")
    print(f"  Requests: {overall['total_requests']:,}")
    print(f"  Error Rate: {overall['error_rate']}%")
    print(f"  Avg Response: {overall['avg_response_ms']}ms")
    print(f"  P95: {overall['p95_ms']}ms | P99: {overall['p99_ms']}ms")
    print(f"  Throughput: {overall['throughput_rps']} rps")
    if git_commit:
        print(f"  Git Commit: {git_commit}")


def cmd_show(args):
    """Show recent runs."""
    conn = get_db()

    query = "SELECT * FROM runs"
    params = []

    if args.test_type:
        query += " WHERE test_type = ?"
        params.append(args.test_type)

    query += " ORDER BY id DESC LIMIT ?"
    params.append(args.last)

    rows = conn.execute(query, params).fetchall()
    conn.close()

    if not rows:
        print("No runs recorded yet.")
        return

    print(f"\n{'ID':>4} {'Date':>12} {'Type':>8} {'Env':>10} {'Requests':>10} {'Errors':>8} {'Avg':>8} {'P95':>8} {'P99':>8} {'RPS':>8}")
    print("-" * 110)

    for r in rows:
        date = r["timestamp"][:10] if r["timestamp"] else "N/A"
        print(f"{r['id']:>4} {date:>12} {r['test_type']:>8} {r['environment']:>10} {r['total_requests']:>10,} {r['error_rate']:>7.1f}% {r['avg_response_ms']:>7.0f}ms {r['p95_ms']:>7}ms {r['p99_ms']:>7}ms {r['throughput_rps']:>7.1f}")


def cmd_trend(args):
    """Show trend for a specific endpoint and metric."""
    conn = get_db()

    rows = conn.execute("""
        SELECT r.timestamp, r.test_type, e.p95_ms, e.p99_ms, e.avg_response_ms, e.error_rate, e.total_requests
        FROM endpoint_metrics e
        JOIN runs r ON e.run_id = r.id
        WHERE e.label = ?
        ORDER BY r.id
    """, (args.endpoint,)).fetchall()

    conn.close()

    if not rows:
        print(f"No data found for endpoint: {args.endpoint}")
        return

    print(f"\nTrend for: {args.endpoint}")
    print(f"{'Date':>12} {'Type':>8} {'Avg':>8} {'P95':>8} {'P99':>8} {'Errors':>8} {'Requests':>10}")
    print("-" * 75)

    for r in rows:
        date = r["timestamp"][:10] if r["timestamp"] else "N/A"
        print(f"{date:>12} {r['test_type']:>8} {r['avg_response_ms']:>7.0f}ms {r['p95_ms']:>7}ms {r['p99_ms']:>7}ms {r['error_rate']:>7.1f}% {r['total_requests']:>10,}")


def cmd_compare(args):
    """Compare two runs."""
    conn = get_db()

    run1 = conn.execute("SELECT * FROM runs WHERE id = ?", (args.run_id_1,)).fetchone()
    run2 = conn.execute("SELECT * FROM runs WHERE id = ?", (args.run_id_2,)).fetchone()

    if not run1 or not run2:
        print("ERROR: One or both runs not found")
        sys.exit(1)

    print(f"\nComparison: Run #{run1['id']} vs Run #{run2['id']}")
    print(f"  Run #{run1['id']}: {run1['timestamp'][:10]} ({run1['test_type']})")
    print(f"  Run #{run2['id']}: {run2['timestamp'][:10]} ({run2['test_type']})")
    print()

    metrics = ["total_requests", "error_rate", "avg_response_ms", "p95_ms", "p99_ms", "throughput_rps"]
    labels = ["Total Requests", "Error Rate", "Avg Response", "P95", "P99", "Throughput"]

    print(f"{'Metric':>20} {'Run #' + str(args.run_id_1):>15} {'Run #' + str(args.run_id_2):>15} {'Delta':>15} {'Status':>8}")
    print("-" * 80)

    for metric, label in zip(metrics, labels):
        v1 = run1[metric]
        v2 = run2[metric]
        delta = v2 - v1
        if "rate" in metric or "error" in metric:
            status = "WORSE" if delta > 0 else "BETTER" if delta < 0 else "SAME"
        elif "throughput" in metric:
            status = "BETTER" if delta > 0 else "WORSE" if delta < 0 else "SAME"
        else:
            status = "WORSE" if delta > 0 else "BETTER" if delta < 0 else "SAME"

        unit = "%" if "rate" in metric else "ms" if "response" in metric or "p95" in metric or "p99" in metric else "rps" if "throughput" in metric else ""
        print(f"{label:>20} {v1:>14} {v2:>14} {delta:>+14.1f} {status:>8}")

    conn.close()


def main():
    parser = argparse.ArgumentParser(description="Performance test run history tracker")
    subparsers = parser.add_subparsers(dest="command", help="Command to run")

    # record
    record_parser = subparsers.add_parser("record", help="Record a test run")
    record_parser.add_argument("jtl_file", help="JTL file to record")
    record_parser.add_argument("--test-type", required=True, help="Test type (smoke/load/stress/spike/soak)")
    record_parser.add_argument("--env", default="development", help="Environment name")
    record_parser.add_argument("--notes", default=None, help="Optional notes")

    # show
    show_parser = subparsers.add_parser("show", help="Show recent runs")
    show_parser.add_argument("--last", type=int, default=10, help="Number of runs to show")
    show_parser.add_argument("--test-type", default=None, help="Filter by test type")

    # trend
    trend_parser = subparsers.add_parser("trend", help="Show trend for an endpoint")
    trend_parser.add_argument("--endpoint", required=True, help="Endpoint label")
    trend_parser.add_argument("--metric", default="p95", help="Metric to trend")

    # compare
    compare_parser = subparsers.add_parser("compare", help="Compare two runs")
    compare_parser.add_argument("run_id_1", type=int, help="First run ID")
    compare_parser.add_argument("run_id_2", type=int, help="Second run ID")

    args = parser.parse_args()

    if args.command == "record":
        cmd_record(args)
    elif args.command == "show":
        cmd_show(args)
    elif args.command == "trend":
        cmd_trend(args)
    elif args.command == "compare":
        cmd_compare(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
