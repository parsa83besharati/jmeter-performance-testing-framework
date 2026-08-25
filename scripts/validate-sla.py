#!/usr/bin/env python3
"""
SLA Validator - Per-endpoint performance threshold enforcement.

Parses JTL results and validates against SLA config (sla-config.json).
Exits non-zero if any SLA is breached.

Usage:
    python3 validate-sla.py <jtl-file> [--sla-config sla-config.json] [--test-type load]
"""

import csv
import json
import sys
import os
import argparse
from collections import defaultdict
from pathlib import Path


def parse_jtl(jtl_path):
    """Parse JTL CSV file and return per-label metrics."""
    metrics = defaultdict(lambda: {"times": [], "errors": 0, "total": 0})

    with open(jtl_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            label = row.get("label", "unknown")
            elapsed = int(row.get("elapsed", 0))
            success = row.get("success", "true").lower() == "true"

            metrics[label]["times"].append(elapsed)
            metrics[label]["total"] += 1
            if not success:
                metrics[label]["errors"] += 1

    return dict(metrics)


def calculate_percentile(times, percentile):
    """Calculate the Nth percentile of a list of times."""
    if not times:
        return 0
    sorted_times = sorted(times)
    index = int(len(sorted_times) * percentile / 100)
    index = min(index, len(sorted_times) - 1)
    return sorted_times[index]


def calculate_stats(times):
    """Calculate comprehensive stats for a list of times."""
    if not times:
        return {"avg": 0, "min": 0, "max": 0, "p50": 0, "p90": 0, "p95": 0, "p99": 0}

    sorted_times = sorted(times)
    return {
        "avg": sum(times) / len(times),
        "min": sorted_times[0],
        "max": sorted_times[-1],
        "p50": calculate_percentile(times, 50),
        "p90": calculate_percentile(times, 90),
        "p95": calculate_percentile(times, 95),
        "p99": calculate_percentile(times, 99),
    }


def load_sla_config(config_path):
    """Load SLA configuration from JSON file."""
    with open(config_path, "r") as f:
        return json.load(f)


def validate_endpoint(label, stats, error_rate, sla_config):
    """Validate a single endpoint against its SLA."""
    violations = []

    # Check endpoint-specific SLAs
    endpoint_sla = sla_config.get("endpoints", {}).get(label, {})
    global_sla = sla_config.get("global", {})

    # Use endpoint-specific if available, otherwise global
    max_avg = endpoint_sla.get("max_avg_response_ms", global_sla.get("max_avg_response_ms", 999999))
    max_p95 = endpoint_sla.get("max_p95_response_ms", global_sla.get("max_p95_response_ms", 999999))
    max_p99 = endpoint_sla.get("max_p99_response_ms", global_sla.get("max_p99_response_ms", 999999))
    max_error = endpoint_sla.get("max_error_rate_percent", global_sla.get("max_error_rate_percent", 100))

    if stats["avg"] > max_avg:
        violations.append(f"  Avg {stats['avg']:.0f}ms > {max_avg}ms")

    if stats["p95"] > max_p95:
        violations.append(f"  P95 {stats['p95']}ms > {max_p95}ms")

    if stats["p99"] > max_p99:
        violations.append(f"  P99 {stats['p99']}ms > {max_p99}ms")

    if error_rate > max_error:
        violations.append(f"  Error rate {error_rate:.1f}% > {max_error}%")

    return violations


def main():
    parser = argparse.ArgumentParser(description="Validate JTL results against SLA config")
    parser.add_argument("jtl_file", help="Path to JTL results file")
    parser.add_argument("--sla-config", default=None, help="Path to SLA config JSON")
    parser.add_argument("--test-type", default=None, help="Test type override (smoke/load/stress/spike/soak)")
    parser.add_argument("--json-output", default=None, help="Output results as JSON to file")
    args = parser.parse_args()

    if not os.path.exists(args.jtl_file):
        print(f"ERROR: JTL file not found: {args.jtl_file}")
        sys.exit(1)

    # Find SLA config
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    sla_config_path = args.sla_config or str(project_dir / "jmeter" / "config" / "sla-config.json")

    if not os.path.exists(sla_config_path):
        print(f"WARNING: SLA config not found at {sla_config_path}, using defaults")
        sla_config = {"global": {"max_error_rate_percent": 5, "max_p95_response_ms": 1000, "max_p99_response_ms": 2000}}
    else:
        sla_config = load_sla_config(sla_config_path)

    print("=" * 50)
    print("  SLA Validation Report")
    print("=" * 50)
    print(f"\nJTL File: {args.jtl_file}")
    print(f"SLA Config: {sla_config_path}")
    if args.test_type:
        print(f"Test Type: {args.test_type}")
    print()

    # Parse JTL
    metrics = parse_jtl(args.jtl_file)

    if not metrics:
        print("ERROR: No data found in JTL file")
        sys.exit(1)

    all_violations = []
    results = {}

    for label, data in sorted(metrics.items()):
        stats = calculate_stats(data["times"])
        error_rate = (data["errors"] / data["total"] * 100) if data["total"] > 0 else 0

        results[label] = {
            "total": data["total"],
            "errors": data["errors"],
            "error_rate": round(error_rate, 2),
            "stats": stats,
        }

        print(f"Endpoint: {label}")
        print(f"  Requests: {data['total']} | Errors: {data['errors']} ({error_rate:.1f}%)")
        print(f"  Avg: {stats['avg']:.0f}ms | P50: {stats['p50']}ms | P95: {stats['p95']}ms | P99: {stats['p99']}ms")
        print(f"  Min: {stats['min']}ms | Max: {stats['max']}ms")

        violations = validate_endpoint(label, stats, error_rate, sla_config)
        if violations:
            print(f"  [FAIL] SLA Violations:")
            for v in violations:
                print(v)
            all_violations.append({"endpoint": label, "violations": violations})
        else:
            print(f"  [PASS] All SLAs met")
        print()

    # Overall result
    print("=" * 50)
    if all_violations:
        print(f"  SLA VALIDATION FAILED - {len(all_violations)} endpoint(s) breached")
        print("=" * 50)

        # JSON output for CI
        if args.json_output:
            output = {
                "status": "FAIL",
                "violations": all_violations,
                "results": results,
            }
            with open(args.json_output, "w") as f:
                json.dump(output, f, indent=2)

        sys.exit(1)
    else:
        print(f"  SLA VALIDATION PASSED - All endpoints within thresholds")
        print("=" * 50)

        if args.json_output:
            output = {
                "status": "PASS",
                "violations": [],
                "results": results,
            }
            with open(args.json_output, "w") as f:
                json.dump(output, f, indent=2)

        sys.exit(0)


if __name__ == "__main__":
    main()
