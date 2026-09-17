#!/usr/bin/env bash
# evaluate.sh — Compute statistics for each agent×domain response.
# Measures: size, functionality score, reading level, adherence, parallelism, error rate,
#           command count, uniqueness, and estimated cost.
set -euo pipefail

RESPONSE_DIR="/home/opencode0/test-prompts/responses"
PROMPT_DIR="/home/opencode0/test-prompts/prompts"
RESULTS_DIR="/home/opencode0/test-prompts/results"

mkdir -p "$RESULTS_DIR"

# Check if any response files exist
FOUND=0
for d in "$RESPONSE_DIR"/*/; do
  ls "$d"/*.response.md >/dev/null 2>&1 && FOUND=1 && break
done
[ "$FOUND" -eq 0 ] && { echo "No response files found. Run gauntlet.sh first." >&2; exit 1; }

echo "============================================"
echo "  EVALUATION: computing statistics"
echo "============================================"

# Run Python evaluation engine
python3 << 'PYEOF'
import json
import os
import re
import sys
from pathlib import Path

RESPONSE_DIR = "/home/opencode0/test-prompts/responses"
PROMPT_DIR = "/home/opencode0/test-prompts/prompts"
RESULTS_DIR = "/home/opencode0/test-prompts/results"

def safe_int(val, default=0):
    try:
        return int(val)
    except (ValueError, TypeError):
        return default

def safe_float(val, default=0.0):
    try:
        return float(val)
    except (ValueError, TypeError):
        return default

def count_matches(pattern, text):
    return len(re.findall(pattern, text, re.IGNORECASE))

def flesch_kincaid(text):
    """Flesch-Kincaid Grade Level"""
    words = len(text.split())
    sentences = max(1, len(re.findall(r'[.!?]+', text)))
    syllables = max(1, len(re.findall(r'[aeiouyAEIOUY]+', text)))
    if words == 0:
        return 0.0
    score = 0.39 * (words / sentences) + 11.8 * (syllables / words) - 15.59
    return round(max(0, score), 1)

def count_commands(text):
    """Count code commands, function definitions, shell prompts"""
    patterns = [
        r'^\s*[\$>]\s*\w+',
        r'^\s*(function\s+\w+|\w+\s*\(\))',
        r'^(import|from\s|def\s|class\s|fn\s|func\s|pub\s+fn)\s',
        r'^\s*\w+\s*--',
        r'^\s*sudo\s',
    ]
    total = 0
    for pat in patterns:
        total += len(re.findall(pat, text, re.MULTILINE | re.IGNORECASE))
    return total

def count_unique_words(text):
    """Count unique words with 4+ characters"""
    words = re.findall(r'[a-z]{4,}', text.lower())
    return len(set(words))

def estimate_errors(text):
    """Count error markers"""
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
    """Score mentions of parallelization/concurrency patterns"""
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
        score += min(matches, 3)  # cap each category at 3
    return min(score, 10)

def score_adherence(response_text, domain):
    """Check if deliverables mentioned in prompt are present in response"""
    prompt_file = Path(PROMPT_DIR) / f"{domain}.md"
    if not prompt_file.exists():
        return 5.0
    prompt_text = prompt_file.read_text()

    # Extract deliverable lines from prompt
    deliverable_lines = re.findall(r'^\s*(?:\d+\.\s*|[-*]\s*)(.+)$', prompt_text, re.MULTILINE)
    if not deliverable_lines:
        return 5.0

    score = 0
    total = len(deliverable_lines)
    for line in deliverable_lines:
        # Extract key terms from this deliverable
        key_terms = re.findall(r'\b([A-Za-z_]{4,}(?:\.[a-z]+)?)\b', line)
        key_terms = [t.lower() for t in key_terms if len(t) > 3]
        # Check if enough key terms appear in response
        matches = sum(1 for t in key_terms if t in response_text.lower())
        if matches >= max(1, len(key_terms) // 3):
            score += 1

    if total == 0:
        return 5.0
    return round(score / total * 10, 1)

def score_functionality(text):
    """Heuristic score for code structure and completeness"""
    score = 0

    # Code blocks present
    code_blocks = len(re.findall(r'```', text))
    score += min((code_blocks // 2) * 2, 4)

    # Has section headers
    if re.search(r'^#{2,3}\s', text, re.MULTILINE):
        score += 2

    # Substantial length
    words = len(text.split())
    if words > 200: score += 1
    if words > 500: score += 1
    if words > 1000: score += 1
    if words > 2000: score += 1

    # Has technical specifics
    if re.search(r'v\d+\.\d+|/[\w./~-]+|`\w+`\s*--|^\s*[\$>]', text, re.MULTILINE):
        score += 1

    # File extensions mentioned
    files = re.findall(r'\b[\w_]+\.(py|js|sh|md|json|yaml|yml|nix|css|html|v|sv|vhdl|cpp|c|h|rs|toml|xml)\b', text)
    if len(files) >= 3: score += 1

    return min(score, 10)

# Collect all evaluations
evaluations = []

for agent_dir in sorted(Path(RESPONSE_DIR).iterdir()):
    if not agent_dir.is_dir():
        continue
    agent = agent_dir.name

    for response_file in sorted(agent_dir.glob("*.response.md")):
        domain = response_file.stem.replace(".response", "")

        # Read meta
        meta_file = agent_dir / f"{domain}.meta.json"
        if meta_file.exists():
            meta = json.loads(meta_file.read_text())
        else:
            meta = {}

        if meta.get("status") != "ok":
            continue

        response_text = response_file.read_text()
        size = len(response_text.encode('utf-8'))
        words = len(response_text.split())
        lines = len(response_text.splitlines())

        metrics = {
            "agent": agent,
            "domain": domain,
            "size_bytes": size,
            "word_count": words,
            "line_count": lines,
            "fkgl": flesch_kincaid(response_text),
            "commands": count_commands(response_text),
            "unique_words": count_unique_words(response_text),
            "errors": estimate_errors(response_text),
            "parallelism": score_parallelism(response_text),
            "adherence": score_adherence(response_text, domain),
            "functionality": score_functionality(response_text),
            "cost_usd": round((size / 4) / 1000 * 0.003, 4),
        }

        evaluations.append(metrics)
        print(f"  eval {agent}/{domain}: func={metrics['functionality']} adh={metrics['adherence']} par={metrics['parallelism']} err={metrics['errors']} cmd={metrics['commands']} uniq={metrics['unique_words']} fkgl={metrics['fkgl']} cost=${metrics['cost_usd']}")

# Save results
output = {"timestamp": __import__("datetime").datetime.now().isoformat(), "evaluations": evaluations}
with open(f"{RESULTS_DIR}/all.json", "w") as f:
    json.dump(output, f, indent=2)

print(f"\nSaved {len(evaluations)} evaluations to {RESULTS_DIR}/all.json")
PYEOF

echo ""
echo "============================================"
echo "  EVALUATION COMPLETE"
echo "  Results: ${RESULTS_DIR}/all.json"
echo "  Rank agents: ./test-prompts/scripts/rank.sh"
echo "============================================"
