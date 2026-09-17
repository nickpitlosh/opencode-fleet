#!/usr/bin/env python3
"""
evaluate.py — Compute statistics for each agent×domain response.

Reads orchestrate_state.json and computes:
  - functionality (0-10): code structure & completeness
  - adherence (0-10): matches prompt requirements
  - parallelism (0-10): concurrent pattern usage
  - error_rate (0-inf): error markers
  - commands (0-inf): commands/code blocks found
  - unique_words (0-inf): vocabulary richness
  - fkgl (0-20): Flesch-Kincaid Grade Level
  - size_bytes (0-inf): response size
  - cost_usd (0-inf): estimated API cost
  - composite_score (0-90): func*3 + adh*2 + par*1.5 - err*0.5
  - academic_title: 24-tier hierarchy

Outputs: results/evaluations.json, results/evaluations.csv
"""

import json
import math
import os
import re
import sys
from pathlib import Path
from collections import defaultdict

RESULTS_DIR = Path.home() / "test-prompts/results"
STATE_FILE = RESULTS_DIR / "orchestrate_state.json"
OUTPUT_JSON = RESULTS_DIR / "evaluations.json"
OUTPUT_CSV = RESULTS_DIR / "evaluations.csv"

# ── 24-Tier Academic Hierarchy ──────────────────────────────────────────────

ACADEMIC_TIERS = [
    (0.0, "Unclassified"),
    (3.75, "Novice"),
    (7.50, "Apprentice"),
    (11.25, "Student"),
    (15.00, "Pupil"),
    (18.75, "Acolyte"),
    (22.50, "Candidate"),
    (26.25, "Associate"),
    (30.00, "Journeyman"),
    (33.75, "Practitioner"),
    (37.50, "Bachelor"),
    (41.25, "Bachelor of Science"),
    (45.00, "Bachelor of Arts"),
    (48.75, "Master"),
    (52.50, "Master of Science"),
    (56.25, "Master of Arts"),
    (60.00, "Master of Philosophy"),
    (63.75, "Licentiate"),
    (67.50, "Senior Practitioner"),
    (71.25, "Expert"),
    (75.00, "Professor"),
    (78.75, "Distinguished Professor"),
    (82.50, "Doctor of Science"),
    (86.25, "Doctor of Philosophy"),
]

def composite_to_title(score):
    for threshold, title in reversed(ACADEMIC_TIERS):
        if score >= threshold:
            return title
    return "Unclassified"

# ── Metrics ──────────────────────────────────────────────────────────────────

def flesch_kincaid(text):
    words = len(text.split())
    sentences = max(1, len(re.findall(r'[.!?]+', text)))
    syllables = max(1, len(re.findall(r'[aeiouyAEIOUY]+', text)))
    if words == 0:
        return 0.0
    score = 0.39 * (words / sentences) + 11.8 * (syllables / words) - 15.59
    return round(max(0, score), 1)

def count_commands(text):
    patterns = [
        r'^\s*[\$>]\s*\w+',
        r'^\s*(function\s+\w+|\w+\s*\(\))',
        r'^(import|from\s|def\s|class\s|fn\s|func\s|pub\s+fn)\s',
    ]
    total = 0
    for pat in patterns:
        total += len(re.findall(pat, text, re.MULTILINE | re.IGNORECASE))
    return total

def count_unique_words(text):
    words = re.findall(r'[a-z]{4,}', text.lower())
    return len(set(words))

def estimate_errors(text):
    error_patterns = [
        r'\b(error|exception|traceback|panic|fatal)\b',
        r'\b(undefined|null\s+pointer|segfault|syntax\s+error)\b',
        r'\b(not\s+found|No\s+such|Permission\s+denied)\b',
        r'\b(failed|failed\s+to|invalid)\b',
    ]
    total = 0
    for pat in error_patterns:
        total += len(re.findall(pat, text, re.IGNORECASE))
    return total

def score_parallelism(text):
    patterns = [
        r'\b(parallel|concurrent|parallelism)\b',
        r'\b(thread|threading|multithread)\b',
        r'\b(process|multiprocess|subprocess)\b',
        r'\b(worker|pool|executor)\b',
        r'\b(fork|spawn|exec)\b',
        r'\b(async|await|goroutine|coroutine)\b',
        r'\b(channel|mutex|semaphore|lock)\b',
        r'\b(delegate|distribute|split\s+the\s+work)\b',
        r'\b(map.?reduce|scatter.?gather|fan.?out|fan.?in)\b',
    ]
    score = 0
    for pat in patterns:
        matches = len(re.findall(pat, text, re.IGNORECASE))
        score += min(matches, 3)
    return min(score, 10)

def score_adherence(response_text, prompt_text):
    deliverable_lines = re.findall(r'^\s*(?:\d+\.\s*|[-*]\s*)(.+)$', prompt_text, re.MULTILINE)
    if not deliverable_lines:
        return 5.0
    score = 0
    for line in deliverable_lines:
        key_terms = re.findall(r'\b([A-Za-z_]{4,}(?:\.[a-z]+)?)\b', line)
        key_terms = [t.lower() for t in key_terms if len(t) > 3]
        if not key_terms:
            continue
        matches = sum(1 for t in key_terms if t in response_text.lower())
        if matches >= max(1, len(key_terms) // 3):
            score += 1
    total = len(deliverable_lines)
    if total == 0:
        return 5.0
    return round(score / total * 10, 1)

def score_functionality(text):
    score = 0
    code_blocks = len(re.findall(r'```', text))
    score += min((code_blocks // 2) * 2, 4)
    if re.search(r'^#{2,3}\s', text, re.MULTILINE):
        score += 2
    words = len(text.split())
    if words > 200: score += 1
    if words > 500: score += 1
    if words > 1000: score += 1
    if words > 2000: score += 1
    if re.search(r'v\d+\.\d+|/[\w./~-]+|`\w+`\s*--|^\s*[\$>]', text, re.MULTILINE):
        score += 1
    files = re.findall(r'\b[\w_]+\.(py|js|sh|md|json|yaml|yml|nix|css|html|v|sv|vhdl|cpp|c|h|rs|toml|xml)\b', text)
    if len(files) >= 3: score += 1
    return min(score, 10)

# ── Main Evaluation ─────────────────────────────────────────────────────────

def main():
    if not STATE_FILE.exists():
        print("No state file. Run orchestrate.py first.")
        sys.exit(1)

    state = json.loads(STATE_FILE.read_text())
    completed = state.get("completed", {})

    if not completed:
        print("No completed tests to evaluate.")
        sys.exit(1)

    PROMPT_DIR = Path.home() / "test-prompts/prompts"
    evaluations = []

    for key, result in completed.items():
        agent = result["agent"]
        domain = result["domain"]
        response = result.get("response", "")

        # Read prompt
        prompt_file = PROMPT_DIR / f"{domain}.md"
        prompt_text = prompt_file.read_text() if prompt_file.exists() else ""

        # Clean response (strip ANSI)
        clean_response = re.sub(r'\x1b\[[0-9;]*m', '', response)
        size = len(clean_response.encode('utf-8'))

        func = score_functionality(clean_response)
        adh = score_adherence(clean_response, prompt_text)
        par = score_parallelism(clean_response)
        err = estimate_errors(clean_response)
        composite = round(func * 3.0 + adh * 2.0 + par * 1.5 - err * 0.5, 2)
        composite = max(0, composite)

        ev = {
            "agent": agent,
            "domain": domain,
            "status": result.get("status", "unknown"),
            "size_bytes": size,
            "word_count": len(clean_response.split()),
            "line_count": len(clean_response.splitlines()),
            "fkgl": flesch_kincaid(clean_response),
            "commands": count_commands(clean_response),
            "unique_words": count_unique_words(clean_response),
            "errors": err,
            "parallelism": par,
            "adherence": adh,
            "functionality": func,
            "composite_score": composite,
            "academic_title": composite_to_title(composite),
            "cost_usd": round((size / 4) / 1000 * 0.003, 4),
            "duration_s": result.get("duration_s", 0),
            "timestamp": result.get("timestamp", ""),
        }
        evaluations.append(ev)

    # Save JSON
    output = {
        "timestamp": state["stats"].get("end", ""),
        "total_evaluations": len(evaluations),
        "evaluations": evaluations,
        "by_domain": {},
        "by_agent": {},
    }

    # Group by domain and agent
    by_domain = defaultdict(list)
    by_agent = defaultdict(list)
    for ev in evaluations:
        by_domain[ev["domain"]].append(ev)
        by_agent[ev["agent"]].append(ev)

    for domain, evs in sorted(by_domain.items()):
        scores = [e["composite_score"] for e in evs]
        output["by_domain"][domain] = {
            "count": len(evs),
            "avg_composite": round(sum(scores) / len(scores), 2) if scores else 0,
            "max_composite": max(scores) if scores else 0,
            "min_composite": min(scores) if scores else 0,
            "top_agent": max(evs, key=lambda x: x["composite_score"])["agent"] if evs else "",
        }

    for agent, evs in sorted(by_agent.items()):
        scores = [e["composite_score"] for e in evs]
        output["by_agent"][agent] = {
            "count": len(evs),
            "avg_composite": round(sum(scores) / len(scores), 2) if scores else 0,
            "best_domain": max(evs, key=lambda x: x["composite_score"])["domain"] if evs else "",
            "worst_domain": min(evs, key=lambda x: x["composite_score"])["domain"] if evs else "",
            "avg_functionality": round(sum(e["functionality"] for e in evs) / len(evs), 2) if evs else 0,
            "avg_adherence": round(sum(e["adherence"] for e in evs) / len(evs), 2) if evs else 0,
            "avg_duration": round(sum(e["duration_s"] for e in evs) / len(evs), 2) if evs else 0,
            "avg_cost": round(sum(e["cost_usd"] for e in evs) / len(evs), 4) if evs else 0,
            "overall_title": composite_to_title(sum(scores) / len(scores)) if scores else "Unclassified",
        }

    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_JSON.write_text(json.dumps(output, indent=2))

    # Save CSV
    if evaluations:
        headers = evaluations[0].keys()
        csv_lines = [",".join(headers)]
        for ev in evaluations:
            csv_lines.append(",".join(str(ev.get(h, "")) for h in headers))
        OUTPUT_CSV.write_text("\n".join(csv_lines))

    print(f"Evaluated {len(evaluations)} tests")
    print(f"By domain: {len(output['by_domain'])}")
    print(f"By agent: {len(output['by_agent'])}")
    print(f"Saved: {OUTPUT_JSON}")
    print(f"Saved: {OUTPUT_CSV}")

    # Print top agents
    print("\n=== TOP 10 AGENTS ===")
    sorted_agents = sorted(output["by_agent"].items(), key=lambda x: x[1]["avg_composite"], reverse=True)
    for i, (agent, data) in enumerate(sorted_agents[:10], 1):
        print(f"  {i:>2}. {agent:<12} avg={data['avg_composite']:>5.1f}  {data['overall_title']}")

    # Print top domains
    print("\n=== DOMAIN DIFFICULTY ===")
    sorted_domains = sorted(output["by_domain"].items(), key=lambda x: x[1]["avg_composite"])
    for domain, data in sorted_domains:
        print(f"  {domain:<20} avg={data['avg_composite']:>5.1f}  best={data['top_agent']}")

if __name__ == "__main__":
    main()
