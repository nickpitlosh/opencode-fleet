#!/usr/bin/env bash
# gauntlet.sh — Run all test prompts through selected agents and collect responses.
# Usage: ./gauntlet.sh [--agents agent1,agent2,...] [--domains domain1,domain2,...] [--user opencode0]
# If no agents specified, runs all 28. If no domains specified, runs all 16.
set -euo pipefail

PROMPT_DIR="/home/opencode0/test-prompts/prompts"
RESPONSE_DIR="/home/opencode0/test-prompts/responses"
AGENT_BIN="/home/opencode0/.config/opencode/agent-bin"
RUN_AS_USER="${RUN_AS_USER:-opencode0}"
MAX_PARALLEL="${MAX_PARALLEL:-4}"
TIMEOUT="${TIMEOUT:-300}"

# Parse arguments
AGENTS=""
DOMAINS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agents) AGENTS="$2"; shift 2;;
    --domains) DOMAINS="$2"; shift 2;;
    --user) RUN_AS_USER="$2"; shift 2;;
    --parallel) MAX_PARALLEL="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

# Build agent list
if [ -n "$AGENTS" ]; then
  IFS=',' read -ra AGENT_LIST <<< "$AGENTS"
else
  mapfile -t AGENT_LIST < <(ls "$AGENT_BIN" | sort)
fi

# Build domain list
if [ -n "$DOMAINS" ]; then
  IFS=',' read -ra DOMAIN_LIST <<< "$DOMAINS"
else
  mapfile -t DOMAIN_LIST < <(ls "$PROMPT_DIR" | sed 's/.md//')
fi

TOTAL=$(( ${#AGENT_LIST[@]} * ${#DOMAIN_LIST[@]} ))
COMPLETED=0
FAILED=0

echo "============================================"
echo "  GAUNTLET: ${#AGENT_LIST[@]} agents × ${#DOMAIN_LIST[@]} domains = ${TOTAL} runs"
echo "  Max parallel: ${MAX_PARALLEL} | Timeout: ${TIMEOUT}s per prompt"
echo "============================================"

# Worker function
run_prompt() {
  local agent="$1" domain="$2"
  local prompt_file="${PROMPT_DIR}/${domain}.md"
  local out_dir="${RESPONSE_DIR}/${agent}"
  local out_file="${out_dir}/${domain}.response.md"
  local meta_file="${out_dir}/${domain}.meta.json"
  local start_time end_time duration

  mkdir -p "$out_dir"
  start_time=$(date +%s%N)

  # Run the agent with the prompt piped via stdin
  if timeout "$TIMEOUT" sudo -u "$RUN_AS_USER" bash -c "
    export PATH=\"${AGENT_BIN}:\$HOME/.local/bin:\$HOME/.opencode/bin:\$PATH\"
    cat '${prompt_file}' | ${agent}
  " > "$out_file" 2>"${out_file}.stderr"; then
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    size=$(stat -c %s "$out_file" 2>/dev/null || echo 0)
    line_count=$(wc -l < "$out_file" 2>/dev/null || echo 0)
    word_count=$(wc -w < "$out_file" 2>/dev/null || echo 0)

    cat > "$meta_file" << METAEOF
{
  "agent": "${agent}",
  "domain": "${domain}",
  "status": "ok",
  "duration_ms": ${duration},
  "size_bytes": ${size},
  "line_count": ${line_count},
    "word_count": ${word_count},
  "timestamp": "$(date -Iseconds)"
}
METAEOF
    echo "  OK  ${agent}/${domain} (${duration}ms, ${word_count} words)"
  else
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    cat > "$meta_file" << METAEOF
{
  "agent": "${agent}",
  "domain": "${domain}",
  "status": "failed",
  "duration_ms": ${duration},
  "timestamp": "$(date -Iseconds)}"
}
METAEOF
    echo "  FAIL ${agent}/${domain} (${duration}ms)"
  fi
}

export -f run_prompt
export PROMPT_DIR RESPONSE_DIR AGENT_BIN RUN_AS_USER TIMEOUT

# Run with parallelization
for domain in "${DOMAIN_LIST[@]}"; do
  for agent in "${AGENT_LIST[@]}"; do
    # Run in background, control parallelism
    run_prompt "$agent" "$domain" &
    COMPLETED=$((COMPLETED + 1))

    # Wait if we've hit max parallel
    if (( $(jobs -r | wc -l) >= MAX_PARALLEL )); then
      wait -n || true
    fi
  done
done

wait
echo ""
echo "============================================"
echo "  GAUNTLET COMPLETE"
echo "  Responses: ${RESPONSE_DIR}/"
echo "  Run evaluation: ./test-prompts/scripts/evaluate.sh"
echo "============================================"
