#!/usr/bin/env bash
# quick-test-fleet.sh — Fleet quick test (STAGE 7, the "quick test mode").
#
#   quick-test-fleet.sh                # bridge-only, ALL ledger rows (default)
#   quick-test-fleet.sh --agent NAME   # bridge-only, ONE ledger row
#   quick-test-fleet.sh --ledger F     # alternate ledger
#   quick-test-fleet.sh --dry-run      # list would-check rows, do nothing
#
# Never runs LLM completions. Serial, read-only, fail-fast. Proves the 1:1
# bridge contract for every row: (a) OS account exists, (b) per-agent FIFO
# runtime dir exists, (c) per-account fleet template dir exists.
set -uo pipefail

LEDGER_DEFAULT="$HOME/fleet-data/fleet-ledger.tsv"
LEDGER="$LEDGER_DEFAULT"
AGENT_ONLY=""
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --ledger) LEDGER="$2"; shift ;;
    --agent) AGENT_ONLY="$2"; shift ;;
    --dry-run) DRY=1 ;;
    *) echo "usage: quick-test-fleet.sh [--ledger F] [--agent NAME] [--dry-run]" >&2; exit 1 ;;
  esac
  shift
done

[ -s "$LEDGER" ] || { echo "quick-test-fleet: no ledger — run the pipeline first" >&2; exit 1; }

check_row() {
  local acc="$1" agent="$2"
  local fifo_dir="$HOME/.agent-fifo/$agent"
  local tpl_dir="$HOME/fleet-template/$acc"
  local bad=0
  id "$acc" >/dev/null 2>&1 || { echo "  FAIL: no OS account $acc" >&2; bad=1; }
  [ -d "$fifo_dir" ] || { echo "  FAIL: no FIFO runtime for $acc ($agent)" >&2; bad=1; }
  [ -d "$tpl_dir" ] || { echo "  FAIL: no template for $acc" >&2; bad=1; }
  [ "$bad" -eq 0 ] && echo "  bridge OK: $acc <-> $agent"
  return "$bad"
}

PASS=0; FAIL=0

check_ledger_row() {
  local acc agent
  acc="$1"; agent="$2"
  if [ "$DRY" -eq 1 ]; then
    echo "  [dry-run] would check: $acc <-> $agent"
    return 0
  fi
  if check_row "$acc" "$agent"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
}

if [ -n "$AGENT_ONLY" ]; then
  row=$(awk -F'\t' -v a="$AGENT_ONLY" '$2==a {print $1"\t"$2; exit}' "$LEDGER")
  if [ -z "$row" ]; then
    echo "quick-test-fleet: no ledger row for agent $AGENT_ONLY" >&2
    exit 1
  fi
  check_ledger_row $(echo "$row" | tr '\t' ' ')
else
  while IFS=$'\t' read -r acc agent _rest; do
    check_ledger_row "$acc" "$agent"
  done < <(tail -n +2 "$LEDGER")
fi

echo
echo "quick-test-fleet: pass=$PASS fail=$FAIL (bridge-only; zero LLM completions)"
[ "$FAIL" -eq 0 ]
