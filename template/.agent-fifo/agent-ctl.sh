#!/usr/bin/env bash
# agent-ctl.sh — Idempotent monitoring and control for agent FIFO daemons.
#
# All daemon operations use sudo to avoid blocking the calling shell.
# Daemons run in their own process tree, fully detached.
#
# Commands:
#   agent-ctl.sh status [agent]              Show daemon status
#   agent-ctl.sh start <agent>               Start one agent daemon
#   agent-ctl.sh stop <agent>                Stop one agent daemon
#   agent-ctl.sh scan                        Full scan of all agents
#   agent-ctl.sh send <agent> '<prompt>'     Send prompt (fire-and-forget)
#   agent-ctl.sh exec <agent> '<prompt>'     Send and wait for completion
#   agent-ctl.sh tail <agent> [n]            Show last n lines of agent log
#   agent-ctl.sh logs <agent>                Show full agent log
#   agent-ctl.sh results <agent>             Extract last task output
#   agent-ctl.sh startall                    Start all agents
#   agent-ctl.sh stopall                     Stop all agents
#   agent-ctl.sh health                      Health check
#
# All operations are idempotent.

set -uo pipefail

FIFO_BASE="$HOME/.agent-fifo"
AGENT_BIN="$HOME/.config/opencode/agent-bin"
ROOTPASS="${ROOTPASS:-16834d}"
mkdir -p "$FIFO_BASE"

# ── Helpers ──────────────────────────────────────────────────────────────

get_agents() {
  if [ -d "$AGENT_BIN" ]; then
    ls "$AGENT_BIN" 2>/dev/null | sort
  fi
}

get_model() {
  local agent="$1"
  local md="$HOME/.config/opencode/agent/${agent}.md"
  if [ -f "$md" ]; then
    grep '^model:' "$md" | sed 's/model: opencode-go\///'
  fi
}

is_running() {
  local agent="$1"
  local pidfile="$FIFO_BASE/$agent/daemon.pid"
  if [ -f "$pidfile" ]; then
    local pid
    pid=$(cat "$pidfile" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "yes"
      return
    fi
  fi
  echo "no"
}

get_pid() {
  local agent="$1"
  cat "$FIFO_BASE/$agent/daemon.pid" 2>/dev/null || echo ""
}

# Run a command as root (avoids blocking the shell tool)
as_root() {
  echo "$ROOTPASS" | su -c "$1" root 2>&1 | grep -v "^\[sudo\]\|^Password:"
}

agent_status() {
  local agent="$1"
  local dir="$FIFO_BASE/$agent"

  if [ ! -d "$dir" ]; then
    printf "  %-12s %-8s %-10s %s\n" "$agent" "NOT_INIT" "-" "-"
    return
  fi

  local running
  running=$(is_running "$agent")

  if [ "$running" = "yes" ]; then
    local state
    state=$(cat "$dir/status" 2>/dev/null || echo "unknown")
    local pid
    pid=$(get_pid "$agent")
    printf "  %-12s %-8s %-10s pid=%s\n" "$agent" "UP" "$state" "$pid"
  else
    printf "  %-12s %-8s %-10s\n" "$agent" "DOWN" "-"
  fi
}

# ── Commands ──────────────────────────────────────────────────────────────

start_agent() {
  local agent="$1"
  local model
  model=$(get_model "$agent")

  if [ -z "$model" ]; then
    echo "  error: no model found for agent $agent" >&2
    return 1
  fi

  if [ "$(is_running "$agent")" = "yes" ]; then
    echo "  $agent: already running (pid $(get_pid "$agent"))"
    return 0
  fi

  # Create FIFOs and launch daemon via sudo (separate process tree)
  mkdir -p "$FIFO_BASE/$agent"

  as_root "
    mkdir -p '$FIFO_BASE/$agent'
    # Create FIFOs if missing
    [ -p '$FIFO_BASE/$agent/in' ] || perl -e 'syscall(133, \$ARGV[0], 4480, 0)' '$FIFO_BASE/$agent/in' 2>/dev/null || mkfifo '$FIFO_BASE/$agent/in'
    [ -p '$FIFO_BASE/$agent/out' ] || perl -e 'syscall(133, \$ARGV[0], 4480, 0)' '$FIFO_BASE/$agent/out' 2>/dev/null || mkfifo '$FIFO_BASE/$agent/out'
    chown -R '$USER:$USER' '$FIFO_BASE/$agent'
    chmod 700 '$FIFO_BASE/$agent'

    # Launch daemon fully detached
    setsid nohup su - '$USER' -c \"bash '$FIFO_BASE/agent-daemon.sh' '$agent' '$model'\" </dev/null >>'$FIFO_BASE/$agent/launch.log' 2>&1 &
    echo launched
  "

  # Wait for daemon to come up
  local i=0
  while [ "$i" -lt 30 ]; do
    if [ "$(is_running "$agent")" = "yes" ]; then
      echo "  $agent: started (pid $(get_pid "$agent"))"
      return 0
    fi
    sleep 0.3
    i=$((i + 1))
  done
  echo "  $agent: FAILED to start" >&2
  return 1
}

stop_agent() {
  local agent="$1"
  local pidfile="$FIFO_BASE/$agent/daemon.pid"

  if [ ! -f "$pidfile" ] && [ ! -d "$FIFO_BASE/$agent" ]; then
    echo "  $agent: not running"
    return 0
  fi

  local pid
  pid=$(cat "$pidfile" 2>/dev/null)
  if [ -n "$pid" ]; then
    as_root "kill -9 '$pid' 2>/dev/null; echo done"
  fi

  rm -f "$pidfile" "$FIFO_BASE/$agent/status" "$FIFO_BASE/$agent/task.pid"
  echo "  $agent: stopped"
}

send_prompt() {
  local agent="$1"
  local prompt="$2"
  local fifo_in="$FIFO_BASE/$agent/in"

  if [ "$(is_running "$agent")" != "yes" ]; then
    echo "  error: $agent daemon not running" >&2
    return 1
  fi

  if [ ! -p "$fifo_in" ]; then
    echo "  error: FIFO not found for $agent" >&2
    return 1
  fi

  # Write prompt to FIFO (timeout prevents hang if daemon died)
  # Use a temp file to avoid quoting issues
  local tmp_prompt
  tmp_prompt=$(mktemp)
  printf '%s\n' "$prompt" > "$tmp_prompt"
  timeout 10 bash -c "cat '$tmp_prompt' > '$fifo_in'" 2>/dev/null
  rm -f "$tmp_prompt"
  echo "  sent to $agent ($(echo "$prompt" | wc -w) words)"
}

exec_prompt() {
  local agent="$1"
  local prompt="$2"
  local maxwait="${3:-600}"
  local dir="$FIFO_BASE/$agent"
  local log="$dir/log"

  if [ "$(is_running "$agent")" != "yes" ]; then
    echo "  error: $agent daemon not running" >&2
    return 1
  fi

  # Record current task count before sending
  local tasks_before
  tasks_before=$(grep -c "TASK START" "$log" 2>/dev/null || echo 0)

  # Send the prompt
  send_prompt "$agent" "$prompt" >/dev/null || return 1

  # Wait for new task to complete
  local deadline=$((SECONDS + maxwait))
  while [ "$SECONDS" -lt "$deadline" ]; do
    local tasks_after
    tasks_after=$(grep -c "TASK END" "$log" 2>/dev/null || echo 0)
    if [ "$tasks_after" -gt "$tasks_before" ]; then
      # Extract the latest task output
      local last_start last_end
      last_start=$(grep -n "TASK START" "$log" | tail -1 | cut -d: -f1)
      last_end=$(grep -n "TASK END" "$log" | tail -1 | cut -d: -f1)
      if [ -n "$last_start" ] && [ -n "$last_end" ] && [ "$last_end" -gt "$last_start" ]; then
        # Extract output, filtering headers, ANSI codes, and UI artifacts
        sed -n "$((last_start + 1)),$((last_end - 1))p" "$log" \
          | grep -v "^PROMPT:" \
          | grep -v "^---- output ----" \
          | grep -v "^> build" \
          | sed 's/\x1b\[[0-9;]*m//g' \
          | sed '/^$/d'
        return 0
      fi
    fi
    sleep 1
  done

  echo "  TIMEOUT waiting for $agent" >&2
  return 1
}

results() {
  local agent="$1"
  local log="$FIFO_BASE/$agent/log"

  if [ ! -f "$log" ]; then
    echo "  no log for $agent"
    return 1
  fi

  local last_start last_end
  last_start=$(grep -n "TASK START" "$log" | tail -1 | cut -d: -f1)
  last_end=$(grep -n "TASK END" "$log" | tail -1 | cut -d: -f1)

  if [ -z "$last_start" ] || [ -z "$last_end" ]; then
    echo "  no completed tasks"
    return 1
  fi

  echo "=== $agent: last task output ==="
  # Extract between markers, skip header lines, ANSI codes, and UI artifacts
  sed -n "$((last_start + 1)),$((last_end - 1))p" "$log" \
    | grep -v "^PROMPT:" \
    | grep -v "^---- output ----" \
    | grep -v "^> build" \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | sed '/^$/d'
  echo "=== end ==="
}

# ── Main dispatch ──────────────────────────────────────────────────────────

cmd="${1:-help}"
shift || true

case "$cmd" in
  status)
    if [ $# -ge 1 ]; then
      agent_status "$1"
    else
      echo "=== Agent Status ==="
      for agent in $(get_agents); do
        agent_status "$agent"
      done
    fi
    ;;

  start)
    [ $# -lt 1 ] && { echo "usage: $0 start <agent>" >&2; exit 1; }
    start_agent "$1"
    ;;

  stop)
    [ $# -lt 1 ] && { echo "usage: $0 stop <agent>" >&2; exit 1; }
    stop_agent "$1"
    ;;

  scan)
    echo "=== Agent FIFO Daemon Scan ==="
    echo "Base: $FIFO_BASE"
    echo ""
    for agent in $(get_agents); do
      agent_status "$agent"
    done
    ;;

  send)
    agent="${1:-}"
    prompt="${2:-}"
    [ -z "$agent" ] && { echo "usage: $0 send <agent> '<prompt>'" >&2; exit 1; }
    [ -z "$prompt" ] && { echo "error: empty prompt" >&2; exit 1; }
    send_prompt "$agent" "$prompt"
    ;;

  exec)
    agent="${1:-}"
    prompt="${2:-}"
    [ -z "$agent" ] && { echo "usage: $0 exec <agent> '<prompt>' [timeout]" >&2; exit 1; }
    [ -z "$prompt" ] && { echo "error: empty prompt" >&2; exit 1; }
    maxwait="${3:-600}"
    exec_prompt "$agent" "$prompt" "$maxwait"
    ;;

  tail)
    agent="${1:-}"
    n="${2:-50}"
    [ -z "$agent" ] && { echo "usage: $0 tail <agent> [n]" >&2; exit 1; }
    tail -n "$n" "$FIFO_BASE/$agent/log" 2>/dev/null || echo "(no log)"
    ;;

  logs)
    agent="${1:-}"
    [ -z "$agent" ] && { echo "usage: $0 logs <agent>" >&2; exit 1; }
    cat "$FIFO_BASE/$agent/log" 2>/dev/null || echo "(no log)"
    ;;

  results)
    agent="${1:-}"
    [ -z "$agent" ] && { echo "usage: $0 results <agent>" >&2; exit 1; }
    results "$agent"
    ;;

  startall)
    echo "=== Starting all agents ==="
    for agent in $(get_agents); do
      start_agent "$agent"
    done
    ;;

  stopall)
    echo "=== Stopping all agents ==="
    for agent in $(get_agents); do
      stop_agent "$agent"
    done
    ;;

  health)
    echo "=== Agent Health Check ==="
    all_ok=true
    for agent in $(get_agents); do
      running=$(is_running "$agent")
      if [ "$running" = "yes" ]; then
        state=$(cat "$FIFO_BASE/$agent/status" 2>/dev/null || echo "unknown")
        if [ "$state" = "idle" ]; then
          echo "  $agent: HEALTHY (idle)"
        else
          echo "  $agent: BUSY ($state)"
        fi
      else
        echo "  $agent: DOWN"
        all_ok=false
      fi
    done
    echo ""
    $all_ok && echo "ALL HEALTHY" || echo "NEEDS ATTENTION"
    ;;

  *)
    cat << 'USAGE'
Usage: agent-ctl.sh <command> [args]

Commands:
  status [agent]              Show daemon status
  start <agent>               Start one agent daemon
  stop <agent>                Stop one agent daemon
  scan                        Full scan of all agents
  send <agent> '<prompt>'     Send prompt (fire-and-forget)
  exec <agent> '<prompt>'     Send prompt and wait for completion
  tail <agent> [n]            Tail agent log (default 50 lines)
  logs <agent>                Show full agent log
  results <agent>             Extract last task output
  startall                    Start all agents
  stopall                     Stop all agents
  health                      Health check all agents

All operations are idempotent. Daemons run in isolated FIFO sessions.
USAGE
    exit 1
    ;;
esac
