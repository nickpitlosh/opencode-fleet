# Agent FIFO Daemon System

## Architecture

Each agent runs as a persistent FIFO-daemon process that survives shell
disconnects and maintains state across invocations. This is the same
pattern used for the webserver session daemons at `~/.oc/`.

```
~/.agent-fifo/
├── agent-daemon.sh       # daemon launcher (reads FIFO, runs opencode)
├── agent-ctl.sh          # monitoring and control script
├── stacy/
│   ├── in                # FIFO: write prompts here
│   ├── out               # FIFO: completion markers
│   ├── log               # session log (append-only)
│   ├── daemon.pid        # PID of daemon process
│   ├── status            # idle | running | error
│   └── task.pid          # current task ID (0 if idle)
├── luna/
│   └── ...
└── ... (one directory per agent)
```

## How It Works

1. **FIFO Creation**: `agent-daemon.sh` creates a named pipe (`in`) for each agent
2. **Persistent Read**: The daemon opens the FIFO read-write (`exec 3<>"$in"`) to
   prevent EOF on writer close, then blocks on `read -u 3` waiting for input
3. **Task Execution**: When a line arrives, the daemon:
   - Marks status as `running`
   - Logs the prompt with a unique task ID
   - Pipes the prompt through `opencode run -m <model>`
   - Captures output to the log
   - Marks status as `idle`
4. **Idempotent Start**: The control script checks if a daemon is already
   running before launching a new one

## Usage

```bash
# Start a single agent daemon
bash ~/.agent-fifo/agent-ctl.sh start stacy

# Start all agents
bash ~/.agent-fifo/agent-ctl.sh startall

# Check status of all agents
bash ~/.agent-fifo/agent-ctl.sh scan

# Check health (all idle?)
bash ~/.agent-fifo/agent-ctl.sh health

# Send a prompt (fire-and-forget)
bash ~/.agent-fifo/agent-ctl.sh send stacy "explain recursion in 50 words"

# Send a prompt and wait for completion (returns output)
bash ~/.agent/opencode/agent-ctl.sh exec stacy "what is 2+2?"

# Get last task output
bash ~/.agent-fifo/agent-ctl.sh results stacy

# Tail the log
bash ~/.agent-fifo/agent-ctl.sh tail stacy 20

# Full log dump
bash ~/.agent-fifo/agent-ctl.sh logs stacy

# Stop an agent
bash ~/.agent-fifo/agent-ctl.sh stop stacy

# Stop all agents
bash ~/.agent-fifo/agent-ctl.sh stopall

# Restart all agents
bash ~/.agent-fifo/agent-ctl.sh restartall
```

## Task Execution Flow

```
User shell                          Daemon process
    │                                    │
    ├─ write "prompt" ──────────►  FIFO in
    │                                    │
    │                              read -u 3 LINE
    │                              status=running
    │                              echo "TASK START" >> log
    │                              opencode run -m <model>
    │                              capture output >> log
    │                              echo "TASK END" >> log
    │                              status=idle
    │                                    │
    ├─ poll log for "TASK END" ◄─────────┘
    │   (extract output between markers)
    │
    └─ return output to user
```

## Idempotency

- **start**: Checks PID file and process liveness; skips if already running
- **stop**: Graceful kill with fallback to SIGKILL; cleans up PID/status files
- **scan/status**: Read-only operations, safe to run concurrently
- **health**: Verifies all daemons are alive and idle

## Multi-Agent Parallel Execution

```bash
# Start all agents
bash ~/.agent-fifo/agent-ctl.sh startall

# Send different prompts to different agents
for agent in stacy luna kira; do
  bash ~/.agent-fifo/agent-ctl.sh send "$agent" "analyze this code: ..." &
done
wait

# Collect results
for agent in stacy luna kira; do
  echo "=== $agent ==="
  bash ~/.agent-fifo/agent-ctl.sh results "$agent"
done
```

## Log Format

Each task in the log is bounded by markers:

```
==== daemon up: <agent> (<model>) pid <pid> at <timestamp> ====
==== TASK START <task_id> at <timestamp> ====
PROMPT: <user prompt>
---- output ----
<opencode output with ANSI codes>
==== TASK END <task_id> status=<ok|error|timeout> [<exit_code>] at <timestamp> ====
```

## Key Design Decisions

1. **FIFO read-write open (`exec 3<>"$in"`)**: Prevents EOF when the writer
   closes, allowing the daemon to stay alive between commands
2. **Per-agent isolation**: Each agent has its own FIFO directory, PID file,
   and log. No shared state between agents.
3. **Root delegation**: All daemon operations use `su -c` to run in a separate
   process tree, preventing the shell tool from blocking on FIFO reads.
4. **Task markers**: Unique task IDs and START/END markers enable reliable
   output extraction and completion detection.
5. **Append-only log**: The log is never truncated, providing full audit trail.

## Troubleshooting

- **Daemon won't start**: Check if FIFOs exist (`ls -la ~/.agent-fifo/<agent>/in`)
- **Prompt sent but no output**: Check daemon status (`scan`) and log (`tail`)
- **Multiple daemons for one agent**: Kill stale PIDs, restart
- **Permission denied**: Ensure FIFOs are owned by the user running the daemon
