#!/usr/bin/env bash
# rank.sh — Rank agents by domain using academic hierarchy titles.
# 24 divisions from lowest to highest mastery.
set -euo pipefail

RESULTS_FILE="/home/opencode0/test-prompts/results/all.json"
OUTPUT_DIR="/home/opencode0/test-prompts/results"

[ -f "$RESULTS_FILE" ] || { echo "No results. Run evaluate.sh first." >&2; exit 1; }

# --- Academic Hierarchy (24 divisions) ---
# Score ranges map to titles. Score is composite: functionality + adherence + parallelism - errors
# Max composite ≈ 30 (func 10 + adh 10 + par 10)
declare -a TITLES=(
  "Unclassified"           # 0
  "Novice"                 # 1
  "Apprentice"             # 2
  "Student"                # 3
  "Pupil"                  # 4
  "Acolyte"                # 5
  "Candidate"              # 6
  "Associate"              # 7
  "Journeyman"             # 8
  "Practitioner"           # 9
  "Bachelor"               # 10
  "Bachelor of Science"    # 11
  "Bachelor of Arts"       # 12
  "Master"                 # 13
  "Master of Science"      # 14
  "Master of Arts"         # 15
  "Master of Philosophy"   # 16
  "Licentiate"             # 17
  "Senior Practitioner"    # 18
  "Expert"                 # 19
  "Professor"              # 20
  "Distinguished Professor" # 21
  "Doctor of Science"      # 22
  "Doctor of Philosophy"   # 23
)

# Friendly domain names
declare -A DOMAIN_NAMES=(
  ["web-frontend"]="Web Frontend"
  ["assembly"]="Assembly Programming"
  ["fpga"]="FPGA Design"
  ["system-inventory"]="System Inventory"
  ["mechanical"]="Mechanical Engineering"
  ["documentation"]="System Documentation"
  ["test-programming"]="Test Engineering"
  ["gui-design"]="GUI/UX Design"
  ["directory-services"]="Directory Services"
  ["network-kernel"]="Network Kernel"
  ["ui-psychology"]="UI Psychology"
  ["math"]="Mathematics"
  ["distro-management"]="Distro Management"
  ["radio-ee"]="Radio & EE"
  ["quantum-hydro"]="Quantum Hydrodynamics"
  ["quantum-computing"]="Quantum Computing"
)

echo "============================================"
echo "  RANKINGS: Agent × Domain"
echo "============================================"

python3 << 'PYEOF'
import json
import sys

with open(sys.argv[1] if len(sys.argv) > 1 else "/home/opencode0/test-prompts/results/all.json") as f:
    data = json.load(f)

evaluations = data["evalitles"] = data.get("evaluations", [])

TITLES = [
    "Unclassified", "Novice", "Apprentice", "Student", "Pupil",
    "Acolyte", "Candidate", "Associate", "Journeyman", "Practitioner",
    "Bachelor", "Bachelor of Science", "Bachelor of Arts", "Master",
    "Master of Science", "Master of Arts", "Master of Philosophy", "Licentiate",
    "Senior Practitioner", "Expert", "Professor", "Distinguished Professor",
    "Doctor of Science", "Doctor of Philosophy"
]

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

def composite_score(ev):
    """Composite: functionality*3 + adherence*2 + parallelism*1.5 - errors*0.5, normalized to ~30"""
    func = ev.get("functionality", 0)
    adh = ev.get("adherence", 0)
    par = ev.get("parallelism", 0)
    err = max(0, ev.get("errors", 0))
    raw = func * 3.0 + adh * 2.0 + par * 1.5 - err * 0.5
    return max(0, raw)

def score_to_title(score):
    # Map 0-90 composite to 24 divisions
    # 90 / 24 = 3.75 per tier
    idx = int(score / 3.75)
    idx = min(idx, 23)
    idx = max(idx, 0)
    return TITLES[idx]

# Group by domain
from collections import defaultdict
by_domain = defaultdict(list)
by_agent = defaultdict(list)

for ev in evaluations:
    score = composite_score(ev)
    title = score_to_title(score)
    ev["composite_score"] = round(score, 2)
    ev["title"] = title
    by_domain[ev["domain"]].append(ev)
    by_agent[ev["agent"]].append(ev)

# Print per-domain rankings
print()
for domain in sorted(by_domain.keys()):
    display_name = DOMAIN_NAMES.get(domain, domain)
    print(f"{'='*60}")
    print(f"  DOMAIN: {display_name}")
    print(f"{'='*60}")
    print(f"  {'Agent':<12} {'Score':>6} {'Func':>4} {'Adh':>4} {'Par':>4} {'Err':>4} {'Cmd':>4} {'Cost':>7}  Title")
    print(f"  {'-'*12} {'-'*6} {'-'*4} {'-'*4} {'-'*4} {'-'*4} {'-'*4} {'-'*7}  {'-'*20}")

    sorted_evs = sorted(by_domain[domain], key=lambda x: x["composite_score"], reverse=True)
    for ev in sorted_evs:
        print(f"  {ev['agent']:<12} {ev['composite_score']:>6.1f} {ev['functionality']:>4} {ev['adherence']:>4.1f} {ev['parallelism']:>4} {ev.get('errors',0):>4} {ev['commands']:>4} ${ev['cost_usd']:>6.4f}  {ev['title']}")
    print()

# Print overall agent rankings
print(f"{'='*60}")
print(f"  OVERALL AGENT RANKINGS (average composite across all domains)")
print(f"{'='*60}")
print(f"  {'Rank':>4} {'Agent':<12} {'AvgScore':>8} {'Domains':>7} {'Best Domain':<25} {'Worst Domain':<25}")
print(f"  {'-'*4} {'-'*12} {'-'*8} {'-'*7} {'-'*25} {'-'*25}")

agent_avg = []
for agent, evs in by_agent.items():
    scores = [e["composite_score"] for e in evs]
    avg = sum(scores) / len(scores) if scores else 0
    best = max(evs, key=lambda x: x["composite_score"])
    worst = min(evs, key=lambda x: x["composite_score"])
    agent_avg.append((agent, avg, len(evs), best, worst))

agent_avg.sort(key=lambda x: x[1], reverse=True)

for rank, (agent, avg, n, best, worst) in enumerate(agent_avg, 1):
    overall_title = score_to_title(avg)
    print(f"  {rank:>4} {agent:<12} {avg:>8.1f} {n:>7} {DOMAIN_NAMES.get(best['domain'], best['domain']):<25} {DOMAIN_NAMES.get(worst['domain'], worst['domain']):<25}  [{overall_title}]")

# Save enhanced results
output_path = "/home/opencode0/test-prompts/results/all.json"
with open(output_path, 'w') as f:
    json.dump(data, f, indent=2)
print()
print(f"Results saved to {output_path}")
PYEOF

echo ""
echo "============================================"
echo "  RANKING COMPLETE"
echo "============================================"
