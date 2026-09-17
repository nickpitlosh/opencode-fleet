#!/usr/bin/env bash
# agent-daemon.sh — Persistent FIFO-wrapped opencode agent daemon.
set -uo pipefail

AGENT="${1:?usage: agent-daemon.sh <agent> <model>}"
MODEL="${2:?usage: agent-daemon.sh <agent> <model>}"
BASE_DIR="$HOME/.agent-fifo/$AGENT"
FIFO_IN="$BASE_DIR/in"
LOG="$BASE_DIR/log"
PIDFILE="$BASE_DIR/daemon.pid"
STATUSFILE="$BASE_DIR/status"

mkdir -p "$BASE_DIR"
touch "$LOG"

# Create FIFOs
for fifo in "$FIFO_IN" "$BASE_DIR/out"; do
  [ -p "$fifo" ] || { perl -e "syscall(133, '$fifo', 4480, 0)" 2>/dev/null || mkfifo "$fifo" 2>/dev/null || true; }
done

# Idempotent start
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "daemon already running (pid $(cat "$PIDFILE"))"
  exit 0
fi

trap '' HUP
echo "$$" > "$PIDFILE"
echo "idle" > "$STATUSFILE"
echo "==== daemon up: $AGENT ($MODEL) pid $$ at $(date +%s) ====" >> "$LOG"

cleanup() {
  echo "idle" > "$STATUSFILE"
  echo "==== daemon down: $AGENT pid $$ at $(date +%s) ====" >> "$LOG"
  rm -f "$PIDFILE"
  exit 0
}
trap cleanup EXIT TERM INT

# Main loop: use cat piped to while-read.
# cat blocks until a writer opens the FIFO, reads until EOF (writer closes),
# then exits. We restart cat on each iteration.
while true; do
  while IFS= read -r LINE; do
    [ -z "$LINE" ] && continue

    echo "running" > "$STATUSFILE"
    TASK_ID="task_$(date +%s)_$$_$RANDOM"

    {
      echo "==== TASK START $TASK_ID at $(date +%s) ===="
      echo "PROMPT: $LINE"
      echo "---- output ----"
    } >> "$LOG"

    TASK_LOG=$(mktemp)
    if echo "$LINE" | timeout 900 "$HOME/.opencode/bin/opencode" run -m "opencode-go/$MODEL" > "$TASK_LOG" 2>&1; then
      cat "$TASK_LOG" >> "$LOG"
      echo "==== TASK END $TASK_ID status=ok at $(date +%s) ====" >> "$LOG"
    else
      EC=$?
      cat "$TASK_LOG" >> "$LOG"
      if [ "$EC" -eq 124 ]; then
        echo "==== TASK END $TASK_ID status=timeout at $(date +%s) ====" >> "$LOG"
      else
        echo "==== TASK END $TASK_ID status=error exit=$EC at $(date +%s) ====" >> "$LOG"
      fi
    fi
    rm -f "$TASK_LOG"
    echo "idle" > "$STATUSFILE"
  done < "$FIFO_IN"
done
