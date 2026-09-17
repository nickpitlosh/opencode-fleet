#!/usr/bin/env bash
# run-full-gauntlet.sh — Complete test pipeline: orchestrate → evaluate → report → deploy.
#
# Usage: [MAX_CONCURRENT=4] [TEST_TIMEOUT=120] ./run-full-gauntlet.sh
#
# Pipeline:
#   1. Start all 28 agent daemons
#   2. Orchestrate: run all agent×domain tests (4 concurrent, staggered)
#   3. Evaluate: compute metrics on all responses
#   4. Report: generate flipboard HTML
#   5. Deploy: push to communityservices.cc
set -euo pipefail

BASE_DIR="/home/opencode0/test-prompts/scripts"
MAX_CONCURRENT="${MAX_CONCURRENT:-4}"
TEST_TIMEOUT="${TEST_TIMEOUT:-120}"
STAGGER_MS="${STAGGER_MS:-500}"

export MAX_CONCURRENT TEST_TIMEOUT STAGGER_MS

PIPELINE_START=$(date +%s)

echo "============================================"
echo "  FULL GAUNTLET PIPELINE"
echo "  $(date)"
echo "  Max concurrent: $MAX_CONCURRENT"
echo "  Timeout: ${TEST_TIMEOUT}s per test"
echo "  Stagger: ${STAGGER_MS}ms"
echo "============================================"

# ── Phase 0: Start agent daemons ───────────────────────────────────────────
echo ""
echo "--- Phase 0: Starting agent daemons ---"
bash /home/opencode0/.agent-fifo/agent-ctl.sh startall 2>&1 | grep -c "started" | xargs -I{} echo "  {} agents started"

# ── Phase 1: Orchestrate tests ────────────────────────────────────────────
echo ""
echo "--- Phase 1: Running tests ---"
python3 "$BASE_DIR/orchestrate.py" \
  --max-concurrent "$MAX_CONCURRENT" \
  --timeout "$TEST_TIMEOUT" \
  --stagger "$(echo "scale=3; $STAGGER_MS / 1000" | bc)"

# ── Phase 2: Evaluate responses ───────────────────────────────────────────
echo ""
echo "--- Phase 2: Evaluating responses ---"
python3 "$BASE_DIR/evaluate.py"

# ── Phase 3: Generate report ──────────────────────────────────────────────
echo ""
echo "--- Phase 3: Generating report ---"
python3 "$BASE_DIR/report_gen.py"

# ── Phase 4: Deploy to communityservices.cc ───────────────────────────────
echo ""
echo "--- Phase 4: Deploying report ---"
bash "$BASE_DIR/deploy-report.sh"

# ── Summary ────────────────────────────────────────────────────────────────
PIPELINE_END=$(date +%s)
PIPELINE_TIME=$((PIPELINE_END - PIPELINE_START))

echo ""
echo "============================================"
echo "  PIPELINE COMPLETE"
echo "  Total time: ${PIPELINE_TIME}s ($(( PIPELINE_TIME / 60 ))m)"
echo "  Report: https://communityservices.cc/reports/agent-evaluation/"
echo "============================================"
