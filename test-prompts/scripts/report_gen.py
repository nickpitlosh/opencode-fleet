#!/usr/bin/env python3
"""
report_gen.py — Generate a flipboard-style HTML report for agent evaluations.

Outputs a responsive masonry-layout report with:
  - Executive summary cards
  - Per-domain scoreboards
  - Per-agent scorecards
  - Engineering notes subpane with live analysis
  - Interactive filtering and sorting

Output: test-prompts/results/report.html
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime
from collections import defaultdict

RESULTS_DIR = Path.home() / "test-prompts/results"
EVAL_FILE = RESULTS_DIR / "evaluations.json"
OUTPUT_FILE = RESULTS_DIR / "report.html"

DOMAIN_NAMES = {
    "web-frontend": "Web Frontend",
    "assembly": "Assembly Programming",
    "fpga": "FPGA Design",
    "system-inventory": "System Inventory",
    "mechanical": "Mechanical Engineering",
    "documentation": "System Documentation",
    "test-programming": "Test Engineering",
    "gui-design": "GUI/UX Design",
    "directory-services": "Directory Services",
    "network-kernel": "Network Kernel",
    "ui-psychology": "UI Psychology",
    "math": "Mathematics",
    "distro-management": "Distro Management",
    "radio-ee": "Radio & EE",
    "quantum-hydro": "Quantum Hydrodynamics",
    "quantum-computing": "Quantum Computing",
}

ACADEMIC_TIERS = [
    (0.0, "Unclassified", "#9e9e9e"),
    (3.75, "Novice", "#795548"),
    (7.50, "Apprentice", "#607d8b"),
    (11.25, "Student", "#2196f3"),
    (15.00, "Pupil", "#03a9f4"),
    (18.75, "Acolyte", "#00bcd4"),
    (22.50, "Candidate", "#009688"),
    (26.25, "Associate", "#4caf50"),
    (30.00, "Journeyman", "#8bc34a"),
    (33.75, "Practitioner", "#cddc39"),
    (37.50, "Bachelor", "#ffeb3b"),
    (41.25, "Bachelor of Science", "#ffc107"),
    (45.00, "Bachelor of Arts", "#ff9800"),
    (48.75, "Master", "#ff5722"),
    (52.50, "Master of Science", "#e91e63"),
    (56.25, "Master of Arts", "#9c27b0"),
    (60.00, "Master of Philosophy", "#673ab7"),
    (63.75, "Licentiate", "#3f51b5"),
    (67.50, "Senior Practitioner", "#2196f3"),
    (71.25, "Expert", "#00bcd4"),
    (75.00, "Professor", "#009688"),
    (78.75, "Distinguished Professor", "#4caf50"),
    (82.50, "Doctor of Science", "#8bc34a"),
    (86.25, "Doctor of Philosophy", "#cddc39"),
]

def score_to_color(score):
    for threshold, _, color in reversed(ACADEMIC_TIERS):
        if score >= threshold:
            return color
    return "#9e9e9e"

def score_to_title(score):
    for threshold, title, _ in reversed(ACADEMIC_TIERS):
        if score >= threshold:
            return title
    return "Unclassified"

def generate_html(data):
    evaluations = data.get("evaluations", [])
    by_domain = data.get("by_domain", {})
    by_agent = data.get("by_agent", {})

    timestamp = data.get("timestamp", datetime.now().isoformat())

    # ── Compute summary stats ────────────────────────────────────────────
    all_scores = [e["composite_score"] for e in evaluations]
    avg_score = sum(all_scores) / len(all_scores) if all_scores else 0
    max_score = max(all_scores) if all_scores else 0
    min_score = min(all_scores) if all_scores else 0
    total_cost = sum(e.get("cost_usd", 0) for e in evaluations)
    total_duration = sum(e.get("duration_s", 0) for e in evaluations)
    total_tests = len(evaluations)

    # Top and bottom agents
    sorted_agents = sorted(by_agent.items(), key=lambda x: x[1]["avg_composite"], reverse=True)
    top_agents = sorted_agents[:5]
    bottom_agents = sorted_agents[-3:]

    # Domain difficulty
    sorted_domains = sorted(by_domain.items(), key=lambda x: x[1]["avg_composite"])
    easiest = sorted_domains[-3:]
    hardest = sorted_domains[:3]

    # ── Generate HTML ───────────────────────────────────────────────────

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Agent Evaluation Report</title>
<style>
:root {{
  --bg: #0d1117;
  --card-bg: #161b22;
  --card-border: #30363d;
  --text: #c9d1d9;
  --text-muted: #8b949e;
  --accent: #58a6ff;
  --success: #3fb950;
  --warning: #d29922;
  --danger: #f85149;
  --radius: 12px;
}}

* {{ margin: 0; padding: 0; box-sizing: border-box; }}

body {{
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: var(--bg);
  color: var(--text);
  line-height: 1.6;
  min-height: 100vh;
}}

.container {{ max-width: 1400px; margin: 0 auto; padding: 20px; }}

header {{
  text-align: center;
  padding: 40px 20px;
  border-bottom: 1px solid var(--card-border);
  margin-bottom: 30px;
}}

header h1 {{
  font-size: 2.5em;
  font-weight: 300;
  letter-spacing: -0.5px;
  margin-bottom: 8px;
}}

header .subtitle {{
  color: var(--text-muted);
  font-size: 1.1em;
}}

header .meta {{
  margin-top: 12px;
  font-size: 0.85em;
  color: var(--text-muted);
}}

/* ── Executive Summary ─────────────────────────────────────────────── */

.summary-grid {{
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
  margin-bottom: 40px;
}}

.stat-card {{
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius);
  padding: 24px;
  text-align: center;
  transition: transform 0.2s, box-shadow 0.2s;
}}

.stat-card:hover {{
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.3);
}}

.stat-card .value {{
  font-size: 2.5em;
  font-weight: 700;
  margin-bottom: 4px;
}}

.stat-card .label {{
  color: var(--text-muted);
  font-size: 0.85em;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}}

/* ── Section Headers ───────────────────────────────────────────────── */

.section-title {{
  font-size: 1.5em;
  font-weight: 300;
  margin: 40px 0 20px;
  padding-bottom: 10px;
  border-bottom: 1px solid var(--card-border);
}}

/* ── Flipboard Masonry ────────────────────────────────────────======= */

.masonry {{
  columns: 3;
  column-gap: 16px;
}}

@media (max-width: 1200px) {{ .masonry {{ columns: 2; }} }}
@media (max-width: 768px) {{ .masonry {{ columns: 1; }} }}

.flip-card {{
  break-inside: avoid;
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius);
  padding: 20px;
  margin-bottom: 16px;
  transition: transform 0.3s, box-shadow 0.3s;
  cursor: pointer;
}}

.flip-card:hover {{
  transform: translateY(-4px) scale(1.01);
  box-shadow: 0 12px 32px rgba(0,0,0,0.4);
}}

.flip-card .card-header {{
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}}

.flip-card .card-title {{
  font-weight: 600;
  font-size: 1.1em;
}}

.flip-card .card-score {{
  font-size: 1.8em;
  font-weight: 700;
  text-align: right;
}}

.flip-card .card-title-small {{
  font-size: 0.75em;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--text-muted);
  margin-top: 4px;
}}

.flip-card .metrics {{
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-top: 12px;
  font-size: 0.85em;
}}

.flip-card .metric {{
  display: flex;
  justify-content: space-between;
}}

.flip-card .metric-label {{ color: var(--text-muted); }}

.flip-card .badge {{
  display: inline-block;
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 0.75em;
  font-weight: 600;
  color: #000;
  margin-top: 8px;
}}

/* ── Engineering Notes Subpane ─────────────────────────────────────── */

.eng-notes {{
  background: var(--card-bg);
  border: 1px solid var(--card-border);
  border-radius: var(--radius);
  padding: 24px;
  margin-top: 40px;
}}

.eng-notes h2 {{
  font-weight: 300;
  margin-bottom: 16px;
}}

.eng-notes .note-block {{
  background: #0d1117;
  border-left: 3px solid var(--accent);
  padding: 16px;
  margin-bottom: 12px;
  border-radius: 0 8px 8px 0;
  font-family: 'SF Mono', Monaco, 'Cascadia Code', monospace;
  font-size: 0.9em;
  white-space: pre-wrap;
  overflow-x: auto;
}}

.eng-notes .metric-grid {{
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 16px;
  margin-top: 16px;
}}

.eng-notes .metric-card {{
  background: #0d1117;
  border: 1px solid var(--card-border);
  border-radius: 8px;
  padding: 16px;
}}

/* ── Agent Rank Table ──────────────────────────────────────────────── */

.rank-table {{
  width: 100%;
  border-collapse: collapse;
  margin-top: 16px;
}}

.rank-table th, .rank-table td {{
  padding: 10px 14px;
  text-align: left;
  border-bottom: 1px solid var(--card-border);
}}

.rank-table th {{
  color: var(--text-muted);
  font-weight: 500;
  font-size: 0.8em;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}}

.rank-table tr:hover {{
  background: rgba(255,255,255,0.02);
}}

.rank-table .score-bar {{
  height: 6px;
  border-radius: 3px;
  background: #30363d;
  overflow: hidden;
}}

.rank-table .score-fill {{
  height: 100%;
  border-radius: 3px;
  transition: width 0.5s;
}}

/* ── Responsive ────────────────────────────────────────────────────── */

@media (max-width: 768px) {{
  .container {{ padding: 12px; }}
  header h1 {{ font-size: 1.8em; }}
  .flip-card .metrics {{ grid-template-columns: 1fr; }}
}}
</style>
</head>
<body>

<div class="container">

<header>
  <h1>Agent Evaluation Report</h1>
  <div class="subtitle">28 AI models across 16 domains of systems knowledge</div>
  <div class="meta">Generated: {timestamp} | {total_tests} tests | {total_duration:.0f}s total runtime</div>
</header>

<!-- ═══════════════════════════════════════════════════════════════════ -->
<!-- EXECUTIVE SUMMARY                                                    -->
<!-- ═══════════════════════════════════════════════════════════════════ -->

<div class="summary-grid">
  <div class="stat-card">
    <div class="value" style="color:{score_to_color(avg_score)}">{avg_score:.1f}</div>
    <div class="label">Avg Composite</div>
  </div>
  <div class="stat-card">
    <div class="value">{total_tests}</div>
    <div class="label">Total Tests</div>
  </div>
  <div class="stat-card">
    <div class="value" style="color:{score_to_color(max_score)}">{max_score:.1f}</div>
    <div class="label">Peak Score</div>
  </div>
  <div class="stat-card">
    <div class="value">${total_cost:.4f}</div>
    <div class="label">Total Cost</div>
  </div>
  <div class="stat-card">
    <div class="value">{total_duration/60:.1f}m</div>
    <div class="label">Runtime</div>
  </div>
  <div class="stat-card">
    <div class="value">{score_to_title(avg_score)}</div>
    <div class="label">Overall Rank</div>
  </div>
</div>

<!-- ═══════════════════════════════════════════════════════════════════ -->
<!-- AGENT RANKINGS                                                       -->
<!-- ═══════════════════════════════════════════════════════════════════ -->

<h2 class="section-title">Agent Rankings</h2>

<table class="rank-table">
<thead>
<tr><th>#</th><th>Agent</th><th>Avg Score</th><th>Title</th><th>Domains</th><th>Avg Duration</th><th>Avg Cost</th><th>Best Domain</th></tr>
</thead>
<tbody>"""

    for i, (agent, a_data) in enumerate(sorted_agents, 1):
        avg = a_data["avg_composite"]
        color = score_to_color(avg)
        title = a_data["overall_title"]
        bar_width = min(avg / 90 * 100, 100)
        html += f"""
<tr>
  <td>{i}</td>
  <td><strong>{agent}</strong></td>
  <td>
    <div class="score-bar"><div class="score-fill" style="width:{bar_width}%;background:{color}"></div></div>
    <span style="color:{color}">{avg:.1f}</span>
  </td>
  <td><span class="badge" style="background:{color}">{title}</span></td>
  <td>{a_data['count']}</td>
  <td>{a_data['avg_duration']:.1f}s</td>
  <td>${a_data['avg_cost']:.4f}</td>
  <td>{a_data['best_domain']}</td>
</tr>"""

    html += """
</tbody>
</table>

<!-- ═══════════════════════════════════════════════════════════════════ -->
<!-- DOMAIN FLIPBOARD CARDS                                              -->
<!-- ═══════════════════════════════════════════════════════════════════ -->

<h2 class="section-title">Domain Analysis</h2>

<div class="masonry">"""

    for domain, d_data in sorted(by_domain.items(), key=lambda x: x[1]["avg_composite"], reverse=True):
        display_name = DOMAIN_NAMES.get(domain, domain.replace("-", " ").title())
        avg = d_data["avg_composite"]
        color = score_to_color(avg)
        top = d_data["top_agent"]
        max_s = d_data["max_composite"]
        min_s = d_data["min_composite"]
        count = d_data["count"]

        # Get per-domain agent details
        domain_evals = [e for e in evaluations if e["domain"] == domain]
        top_eval = max(domain_evals, key=lambda x: x["composite_score"]) if domain_evals else None

        func_avg = sum(e["functionality"] for e in domain_evals) / len(domain_evals) if domain_evals else 0
        adh_avg = sum(e["adherence"] for e in domain_evals) / len(domain_evals) if domain_evals else 0

        html += f"""
<div class="flip-card" style="border-left:4px solid {color}">
  <div class="card-header">
    <div>
      <div class="card-title">{display_name}</div>
      <div class="card-title-small">{domain} &middot; {count} agents</div>
    </div>
    <div>
      <div class="card-score" style="color:{color}">{avg:.1f}</div>
      <div class="card-title-small">avg score</div>
    </div>
  </div>
  <div class="metrics">
    <div class="metric"><span class="metric-label">Top</span><strong>{top} ({max_s:.1f})</strong></div>
    <div class="metric"><span class="metric-label">Low</span><strong>{min_s:.1f}</strong></div>
    <div class="metric"><span class="metric-label">Function</span><strong>{func_avg:.1f}</strong></div>
    <div class="metric"><span class="metric-label">Adhere</span><strong>{adh_avg:.1f}</strong></div>
  </div>
  <span class="badge" style="background:{color}">{score_to_title(avg)}</span>
</div>"""

    html += """
</div>

<!-- ═══════════════════════════════════════════════════════════════════ -->
<!-- AGENT SCORECARDS                                                     -->
<!-- ═══════════════════════════════════════════════════════════════════ -->

<h2 class="section-title">Agent Scorecards</h2>

<div class="masonry">"""

    for agent, a_data in sorted(by_agent.items(), key=lambda x: x[1]["avg_composite"], reverse=True):
        avg = a_data["avg_composite"]
        color = score_to_color(avg)
        title = a_data["overall_title"]

        # Get agent's per-domain scores
        agent_evals = [e for e in evaluations if e["agent"] == agent]
        best = max(agent_evals, key=lambda x: x["composite_score"]) if agent_evals else None
        worst = min(agent_evals, key=lambda x: x["composite_score"]) if agent_evals else None

        html += f"""
<div class="flip-card" style="border-left:4px solid {color}">
  <div class="card-header">
    <div>
      <div class="card-title">{agent}</div>
      <div class="card-title-small">{a_data['count']} domains tested</div>
    </div>
    <div>
      <div class="card-score" style="color:{color}">{avg:.1f}</div>
      <div class="card-title-small">avg score</div>
    </div>
  </div>
  <div class="metrics">
    <div class="metric"><span class="metric-label">Function</span><strong>{a_data['avg_functionality']:.1f}</strong></div>
    <div class="metric"><span class="metric-label">Adhere</span><strong>{a_data['avg_adherence']:.1f}</strong></div>
    <div class="metric"><span class="metric-label">Duration</span><strong>{a_data['avg_duration']:.1f}s</strong></div>
    <div class="metric"><span class="metric-label">Cost</span><strong>${a_data['avg_cost']:.4f}</strong></div>
  </div>
  <div style="margin-top:8px;font-size:0.8em;color:var(--text-muted)">
    Best: {a_data['best_domain']}<br>
    Needs work: {a_data['worst_domain']}
  </div>
  <span class="badge" style="background:{color}">{title}</span>
</div>"""

    html += """
</div>

<!-- ═══════════════════════════════════════════════════════════════════ -->
<!-- ENGINEERING NOTES                                                    -->
<!-- ═══════════════════════════════════════════════════════════════════ -->

<div class="eng-notes">
  <h2>Engineering Notes</h2>
  <p style="color:var(--text-muted);margin-bottom:16px">Live analysis computed from evaluation metrics.</p>

  <div class="metric-grid">
    <div class="metric-card">
      <h3 style="font-size:0.8em;color:var(--text-muted);margin-bottom:8px">SCORE DISTRIBUTION</h3>
      <div class="note-block">"""

    # Score distribution histogram
    bins = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90]
    hist = [0] * (len(bins) - 1)
    for s in all_scores:
        for i in range(len(bins) - 1):
            if bins[i] <= s < bins[i + 1]:
                hist[i] += 1
                break

    max_hist = max(hist) if hist else 1
    for i, count in enumerate(hist):
        bar = "#" * int(count / max_hist * 40)
        html += f"  {bins[i]:>3}-{bins[i+1]:>3}: {bar} ({count})\n"

    html += """</div>
    </div>

    <div class="metric-card">
      <h3 style="font-size:0.8em;color:var(--text-muted);margin-bottom:8px">COST ANALYSIS</h3>
      <div class="note-block">"""

    # Cost analysis
    agent_costs = defaultdict(float)
    for e in evaluations:
        agent_costs[e["agent"]] += e.get("cost_usd", 0)

    top_expensive = sorted(agent_costs.items(), key=lambda x: x[1], reverse=True)[:5]
    html += "Top 5 by total cost:\n"
    for agent, cost in top_expensive:
        html += f"  {agent:<12} ${cost:.4f}\n"
    html += f"\nAvg cost per test: ${total_cost/total_tests:.4f}\n"
    html += f"Cost per composite point: ${total_cost/avg_score:.4f}\n" if avg_score > 0 else ""

    html += """</div>
    </div>

    <div class="metric-card">
      <h3 style="font-size:0.8em;color:var(--text-muted);margin-bottom:8px">RELIABILITY</h3>
      <div class="note-block">"""

    # Error analysis
    error_agents = defaultdict(int)
    for e in evaluations:
        if e.get("errors", 0) > 0:
            error_agents[e["agent"]] += e["errors"]

    if error_agents:
        html += "Agents with error markers:\n"
        for agent, errs in sorted(error_agents.items(), key=lambda x: x[1], reverse=True)[:5]:
            html += f"  {agent:<12} {errs} errors\n"
    else:
        html += "No error markers detected.\n"

    timeouts = sum(1 for e in evaluations if e.get("status") == "timeout")
    html += f"\nTimeouts: {timeouts}/{total_tests}\n"
    html += f"Success rate: {((total_tests - timeouts) / total_tests * 100):.1f}%\n" if total_tests > 0 else ""

    html += """</div>
    </div>

    <div class="metric-card">
      <h3 style="font-size:0.8em;color:var(--text-muted);margin-bottom:8px">DOMAIN INSIGHTS</h3>
      <div class="note-block">"""

    html += "Hardest domains (lowest avg):\n"
    for domain, data in hardest[:3]:
        html += f"  {DOMAIN_NAMES.get(domain, domain):<25} {data['avg_composite']:.1f}\n"
    html += "\nEasiest domains (highest avg):\n"
    for domain, data in easiest[:3]:
        html += f"  {DOMAIN_NAMES.get(domain, domain):<25} {data['avg_composite']:.1f}\n"

    # Correlation: adherence vs functionality
    func_scores = [e["functionality"] for e in evaluations]
    adh_scores = [e["adherence"] for e in evaluations]
    if len(func_scores) > 1:
        n = len(func_scores)
        mean_f = sum(func_scores) / n
        mean_a = sum(adh_scores) / n
        cov = sum((f - mean_f) * (a - mean_a) for f, a in zip(func_scores, adh_scores)) / n
        std_f = (sum((f - mean_f) ** 2 for f in func_scores) / n) ** 0.5
        std_a = (sum((a - mean_a) ** 2 for a in adh_scores) / n) ** 0.5
        corr = cov / (std_f * std_a) if std_f > 0 and std_a > 0 else 0
        html += f"\nFunc-Adhere correlation: {corr:.3f}\n"

    html += """</div>
    </div>
  </div>
</div>

</div>
</body>
</html>"""

    return html


def main():
    if not EVAL_FILE.exists():
        print("No evaluations. Run evaluate.py first.")
        sys.exit(1)

    data = json.loads(EVAL_FILE.read_text())
    html = generate_html(data)

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(html)
    print(f"Report generated: {OUTPUT_FILE}")
    print(f"Size: {len(html):,} bytes")
    print(f"Tests: {data['total_evaluations']}")
    print(f"Domains: {len(data['by_domain'])}")
    print(f"Agents: {len(data['by_agent'])}")


if __name__ == "__main__":
    main()
