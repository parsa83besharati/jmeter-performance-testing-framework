#!/usr/bin/env python3
"""
HTML5 Report Generator - Rich visual performance report from JTL data.

Generates a self-contained HTML file with charts, tables, and SLA status.
No external dependencies - uses inline SVG/Canvas charts.

Usage:
    python3 generate-report.py <jtl-file> [--output report.html] [--title "Load Test Report"]
"""

import csv
import json
import sys
import os
import argparse
from collections import defaultdict
from datetime import datetime
from pathlib import Path


def parse_jtl(jtl_path):
    """Parse JTL CSV and return structured data."""
    samples = []
    with open(jtl_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            samples.append({
                "timestamp": int(row.get("timeStamp", 0)),
                "label": row.get("label", "unknown"),
                "elapsed": int(row.get("elapsed", 0)),
                "success": row.get("success", "true").lower() == "true",
                "response_code": row.get("responseCode", ""),
                "response_message": row.get("responseMessage", ""),
                "thread_name": row.get("threadName", ""),
                "latency": int(row.get("Latency", 0)),
                "connect_time": int(row.get("Connect", 0)),
            })
    return samples


def calculate_metrics(samples):
    """Calculate comprehensive metrics from samples."""
    by_label = defaultdict(list)
    by_time = defaultdict(list)

    for s in samples:
        by_label[s["label"]].append(s)
        # Group by second
        ts_second = s["timestamp"] // 1000
        by_time[ts_second].append(s)

    metrics = {}
    for label, label_samples in by_label.items():
        times = [s["elapsed"] for s in label_samples]
        errors = [s for s in label_samples if not s["success"]]
        sorted_times = sorted(times)

        metrics[label] = {
            "total": len(label_samples),
            "errors": len(errors),
            "error_rate": round(len(errors) / len(label_samples) * 100, 2) if label_samples else 0,
            "avg": round(sum(times) / len(times), 1) if times else 0,
            "min": min(times) if times else 0,
            "max": max(times) if times else 0,
            "p50": sorted_times[len(sorted_times) // 2] if sorted_times else 0,
            "p90": sorted_times[int(len(sorted_times) * 0.9)] if sorted_times else 0,
            "p95": sorted_times[int(len(sorted_times) * 0.95)] if sorted_times else 0,
            "p99": sorted_times[int(len(sorted_times) * 0.99)] if sorted_times else 0,
        }

    # Timeline data
    timeline = []
    for ts in sorted(by_time.keys()):
        time_samples = by_time[ts]
        times = [s["elapsed"] for s in time_samples]
        errors = sum(1 for s in time_samples if not s["success"])
        timeline.append({
            "timestamp": ts,
            "count": len(time_samples),
            "avg": round(sum(times) / len(times), 1) if times else 0,
            "errors": errors,
        })

    return metrics, timeline


def generate_bar_chart_svg(metrics, max_val=None):
    """Generate SVG bar chart for response times."""
    if not metrics:
        return ""

    labels = list(metrics.keys())
    p95_vals = [metrics[l]["p95"] for l in labels]
    avg_vals = [metrics[l]["avg"] for l in labels]

    if max_val is None:
        max_val = max(p95_vals) * 1.2 if p95_vals else 1000

    bar_width = 40
    gap = 20
    chart_width = len(labels) * (bar_width * 2 + gap) + 100
    chart_height = 250
    base_y = chart_height - 40

    svg = f'<svg width="{chart_width}" height="{chart_height}" xmlns="http://www.w3.org/2000/svg">\n'

    # Grid lines
    for i in range(5):
        y = base_y - (base_y - 20) * i / 4
        val = int(max_val * i / 4)
        svg += f'  <line x1="60" y1="{y}" x2="{chart_width - 20}" y2="{y}" stroke="#e0e0e0" stroke-dasharray="3"/>\n'
        svg += f'  <text x="55" y="{y + 4}" text-anchor="end" font-size="10" fill="#666">{val}ms</text>\n'

    for i, label in enumerate(labels):
        x = 70 + i * (bar_width * 2 + gap)
        avg_h = (avg_vals[i] / max_val) * (base_y - 20) if max_val > 0 else 0
        p95_h = (p95_vals[i] / max_val) * (base_y - 20) if max_val > 0 else 0

        # Avg bar
        svg += f'  <rect x="{x}" y="{base_y - avg_h}" width="{bar_width}" height="{avg_h}" fill="#4CAF50" rx="3"/>\n'
        svg += f'  <text x="{x + bar_width/2}" y="{base_y - avg_h - 5}" text-anchor="middle" font-size="9" fill="#333">{avg_vals[i]:.0f}</text>\n'

        # P95 bar
        svg += f'  <rect x="{x + bar_width + 2}" y="{base_y - p95_h}" width="{bar_width}" height="{p95_h}" fill="#FF9800" rx="3"/>\n'
        svg += f'  <text x="{x + bar_width + 2 + bar_width/2}" y="{base_y - p95_h - 5}" text-anchor="middle" font-size="9" fill="#333">{p95_vals[i]}</text>\n'

        # Label
        short_label = label.replace("GET ", "").replace("POST ", "").replace("PUT ", "").replace("DELETE ", "")
        svg += f'  <text x="{x + bar_width}" y="{base_y + 15}" text-anchor="middle" font-size="9" fill="#333">{short_label}</text>\n'

    # Legend
    svg += f'  <rect x="{chart_width - 150}" y="5" width="12" height="12" fill="#4CAF50"/>\n'
    svg += f'  <text x="{chart_width - 133}" y="15" font-size="10" fill="#333">Avg</text>\n'
    svg += f'  <rect x="{chart_width - 90}" y="5" width="12" height="12" fill="#FF9800"/>\n'
    svg += f'  <text x="{chart_width - 73}" y="15" font-size="10" fill="#333">P95</text>\n'

    svg += "</svg>"
    return svg


def generate_html_report(samples, metrics, timeline, title, output_path):
    """Generate complete HTML report."""
    total_requests = len(samples)
    total_errors = sum(1 for s in samples if not s["success"])
    error_rate = round(total_errors / total_requests * 100, 2) if total_requests > 0 else 0
    all_times = [s["elapsed"] for s in samples]
    avg_response = round(sum(all_times) / len(all_times), 1) if all_times else 0

    chart_svg = generate_bar_chart_svg(metrics)

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; color: #333; }}
        .header {{ background: linear-gradient(135deg, #1a237e, #283593); color: white; padding: 30px 40px; }}
        .header h1 {{ font-size: 28px; margin-bottom: 8px; }}
        .header .meta {{ opacity: 0.8; font-size: 14px; }}
        .container {{ max-width: 1200px; margin: 0 auto; padding: 20px; }}
        .summary {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin: 20px 0; }}
        .card {{ background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        .card h3 {{ font-size: 13px; text-transform: uppercase; color: #666; margin-bottom: 8px; letter-spacing: 0.5px; }}
        .card .value {{ font-size: 32px; font-weight: 700; }}
        .card .value.pass {{ color: #4CAF50; }}
        .card .value.warn {{ color: #FF9800; }}
        .card .value.fail {{ color: #f44336; }}
        .section {{ background: white; border-radius: 8px; padding: 24px; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        .section h2 {{ font-size: 18px; margin-bottom: 16px; color: #1a237e; }}
        table {{ width: 100%; border-collapse: collapse; }}
        th {{ background: #f5f5f5; padding: 10px 12px; text-align: left; font-size: 12px; text-transform: uppercase; color: #666; letter-spacing: 0.5px; border-bottom: 2px solid #e0e0e0; }}
        td {{ padding: 10px 12px; border-bottom: 1px solid #f0f0f0; font-size: 14px; }}
        tr:hover td {{ background: #fafafa; }}
        .badge {{ display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; }}
        .badge.pass {{ background: #e8f5e9; color: #2e7d32; }}
        .badge.fail {{ background: #ffebee; color: #c62828; }}
        .badge.warn {{ background: #fff3e0; color: #e65100; }}
        .chart-container {{ overflow-x: auto; padding: 20px 0; }}
        .footer {{ text-align: center; padding: 20px; color: #999; font-size: 12px; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>{title}</h1>
        <div class="meta">Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | Total Samples: {total_requests}</div>
    </div>
    <div class="container">
        <div class="summary">
            <div class="card">
                <h3>Total Requests</h3>
                <div class="value">{total_requests:,}</div>
            </div>
            <div class="card">
                <h3>Error Rate</h3>
                <div class="value {'pass' if error_rate < 1 else 'warn' if error_rate < 5 else 'fail'}">{error_rate}%</div>
            </div>
            <div class="card">
                <h3>Avg Response</h3>
                <div class="value {'pass' if avg_response < 500 else 'warn' if avg_response < 1000 else 'fail'}">{avg_response}ms</div>
            </div>
            <div class="card">
                <h3>Throughput</h3>
                <div class="value">{round(total_requests / max(1, (samples[-1]['timestamp'] - samples[0]['timestamp']) / 1000), 1)} rps</div>
            </div>
        </div>

        <div class="section">
            <h2>Response Time by Endpoint</h2>
            <div class="chart-container">{chart_svg}</div>
        </div>

        <div class="section">
            <h2>Detailed Metrics</h2>
            <table>
                <thead>
                    <tr>
                        <th>Endpoint</th>
                        <th>Requests</th>
                        <th>Errors</th>
                        <th>Avg</th>
                        <th>P50</th>
                        <th>P90</th>
                        <th>P95</th>
                        <th>P99</th>
                        <th>Min</th>
                        <th>Max</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
"""

    for label, m in sorted(metrics.items()):
        status_class = "pass" if m["error_rate"] < 5 and m["p95"] < 1000 else "warn" if m["error_rate"] < 10 else "fail"
        status_text = "PASS" if status_class == "pass" else "WARN" if status_class == "warn" else "FAIL"
        html += f"""                    <tr>
                        <td><strong>{label}</strong></td>
                        <td>{m['total']:,}</td>
                        <td>{m['errors']} ({m['error_rate']}%)</td>
                        <td>{m['avg']}ms</td>
                        <td>{m['p50']}ms</td>
                        <td>{m['p90']}ms</td>
                        <td>{m['p95']}ms</td>
                        <td>{m['p99']}ms</td>
                        <td>{m['min']}ms</td>
                        <td>{m['max']}ms</td>
                        <td><span class="badge {status_class}">{status_text}</span></td>
                    </tr>
"""

    html += """                </tbody>
            </table>
        </div>
    </div>
    <div class="footer">
        Generated by JMeter Performance Testing Framework | github.com/parsa83besharati/jmeter-performance-testing-framework
    </div>
</body>
</html>"""

    with open(output_path, "w") as f:
        f.write(html)

    return output_path


def main():
    parser = argparse.ArgumentParser(description="Generate HTML5 performance report from JTL")
    parser.add_argument("jtl_file", help="Path to JTL results file")
    parser.add_argument("--output", default=None, help="Output HTML file path")
    parser.add_argument("--title", default="Performance Test Report", help="Report title")
    args = parser.parse_args()

    if not os.path.exists(args.jtl_file):
        print(f"ERROR: JTL file not found: {args.jtl_file}")
        sys.exit(1)

    print(f"Parsing JTL: {args.jtl_file}")
    samples = parse_jtl(args.jtl_file)

    if not samples:
        print("ERROR: No data in JTL file")
        sys.exit(1)

    print(f"Calculating metrics for {len(samples)} samples...")
    metrics, timeline = calculate_metrics(samples)

    output_path = args.output
    if not output_path:
        jtl_name = Path(args.jtl_file).stem
        output_dir = Path(args.jtl_file).parent.parent / "html"
        output_dir.mkdir(parents=True, exist_ok=True)
        output_path = str(output_dir / f"{jtl_name}-report.html")

    print(f"Generating report: {output_path}")
    generate_html_report(samples, metrics, timeline, args.title, output_path)
    print(f"Report generated: {output_path}")


if __name__ == "__main__":
    main()
