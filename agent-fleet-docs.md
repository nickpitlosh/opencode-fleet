# Agent Fleet: Complete System Documentation

## Architecture Overview

```
~/.agent-fifo/
├── agent-daemon.sh       # Per-agent FIFO daemon launcher
├── agent-ctl.sh          # Monitoring & control (idempotent)
├── README.md             # FIFO daemon documentation
├── stacy/                # Per-agent session directory
│   ├── in                # Input FIFO (write prompts)
│   ├── out               # Output FIFO (completion markers)
│   ├── log               # Append-only session log
│   ├── daemon.pid        # Daemon PID
│   └── status            # idle | running | error
├── luna/
└── ...

~/.config/opencode/
├── agent/                # Agent definition files (.md)
├── agent-bin/            # Agent wrapper scripts
├── scripts/
│   └── sync-agents.sh    # Sync agents with opencode-go models
└── skills/agent-army/SKILL.md

~/test-prompts/
├── prompts/              # 16 domain test prompts
├── scripts/
│   ├── gauntlet.sh       # Parallel prompt execution
│   ├── evaluate.sh       # Response evaluation (10+ metrics)
│   └── rank.sh           # Academic hierarchy ranking (24 tiers)
├── DOMAINS.md            # Domain list and methodology
└── results/              # Evaluation output

~/deploy.sh               # Full deploy (users + sudo + template)
~/apply-template.sh       # Lightweight template sync
~/AGENTS.md               # Agent fleet quick reference
```

## FIFO Daemon Pattern

Based on the same architecture as `~/.oc/` webserver session daemons:

```
Writer (shell)          Daemon (persistent)
     │                        │
     ├─ open FIFO for write   ├─ exec 3<>"$FIFO" (read-write, no EOF)
     ├─ write "prompt\n"      ├─ read -u 3 LINE  (blocks for writer)
     ├─ close FIFO            ├─ status=running
     │                        ├─ opencode run -m <model>
     │                        ├─ capture output >> log
     │                        ├─ status=idle
     │                        └─ loop back to read
```

**Why read-write open?** Opening a FIFO read-only causes EOF when the
writer closes. Opening read-write ensures the reader never sees EOF,
staying alive between commands.

## Agent Lifecycle

### Start
```bash
agent-ctl.sh start <agent>
# 1. Check if already running (PID file + liveness) → skip if yes
# 2. Create FIFOs if missing (perl mknod or mkfifo)
# 3. Launch daemon via setsid + nohup (fully detached)
# 4. Wait for PID file to appear (up to 9s)
```

### Execute
```bash
agent-ctl.sh exec <agent> "<prompt>"
# 1. Record current task count
# 2. Write prompt to FIFO (timeout 10s, tmpfile for safe quoting)
# 3. Poll log for new TASK END marker
# 4. Extract output between markers, filter ANSI/UI artifacts
# 5. Return clean output
```

### Tear Down
```bash
agent-ctl.sh stop <agent>
# 1. Kill daemon (SIGTERM → wait 4.5s → SIGKILL)
# 2. Clean up PID file, status file, task file
# 3. FIFOs persist (filesystem objects, recreated on next start)
```

## Resilience Model

### Unexpected Reboot / Power Loss
- **FIFOs persist**: Named pipes are filesystem objects, survive process death
- **PID files go stale**: Next `start` detects dead PID and launches fresh daemon
- **No data loss**: Log files are append-only, all tasks recorded
- **Clean recovery**: `startall` → all 28 agents operational in <5 seconds

### Tested Scenarios
| Scenario | Result |
|----------|--------|
| `kill -9` all daemons | All DOWN, FIFOs intact |
| `startall` after kill | All 28 restarted |
| Full reboot simulation | All agents recover, respond correctly |
| Stale PID files | Detected and replaced on `start` |
| Idempotent restart | No duplicate daemons |

## Test Prompt Gauntlet

### 16 Domains
| ID | Domain | Complexity |
|----|--------|------------|
| web-frontend | HTML/CSS/JS collaborative editor | High |
| assembly | x86-64 suffix arrays | High |
| fpga | RISC-V RV32I pipeline | High |
| system-inventory | Hardware/software/security catalog | Medium |
| mechanical | Thermal/CFD heat sink | High |
| documentation | Distributed KV store docs | Medium |
| test-programming | QA automation framework | High |
| gui-design | Medical monitoring dashboard | High |
| directory-services | AD/LDAP/GPO architecture | High |
| network-kernel | eBPF/XDP IPv6 filter | High |
| ui-psychology | Cognitive moderation design | Medium |
| math | Full-spectrum math proficiency | Medium |
| distro-management | Arch/Nix/Gentoo/Debian | High |
| radio-ee | SDR RF front-end | High |
| quantum-hydro | Madelung/Bohmian/BEC | High |
| quantum-computing | Qiskit Grover/QEC/VQE | High |

### Evaluation Metrics
| Metric | Scale | Description |
|--------|-------|-------------|
| functionality | 0–10 | Code structure & completeness |
| adherence | 0–10 | Match to prompt requirements |
| parallelism | 0–10 | Concurrent pattern usage |
| errors | 0–∞ | Error/exception markers |
| commands | 0–∞ | Commands/code blocks found |
| unique_words | 0–∞ | Vocabulary richness |
| fkgl | 0–20+ | Flesch-Kincaid Grade Level |
| size_bytes | 0–∞ | Response size |
| cost_usd | $0–∞ | Estimated API cost |
| composite_score | 0–90 | func×3 + adh×2 + par×1.5 - err×0.5 |

### Academic Hierarchy (24 Tiers)
```
 0–3.75   Unclassified         45.0–48.75  Master
 3.75–7.50 Novice              48.75–52.50  Master of Science
 7.50–11.25 Apprentice         52.50–56.25  Master of Arts
11.25–15.00 Student           56.25–60.00  Master of Philosophy
15.00–18.75 Pupil             60.00–63.75  Licentiate
18.75–22.50 Acolyte            63.75–67.50  Senior Practitioner
22.50–26.25 Candidate          67.50–71.25  Expert
26.25–30.00 Associate          71.25–75.00  Professor
30.00–33.75 Journeyman         75.00–78.75  Distinguished Professor
33.75–37.50 Practitioner       78.75–82.50  Doctor of Science
37.50–41.25 Bachelor           82.50–90.00  Doctor of Philosophy
41.25–45.00 Bachelor of Science
```

## Deploy

```bash
# Full deploy (create users, sudo, template)
PASS='16834d' ROOTPASS='16834d' ./deploy.sh

# Sync template to all users
./apply-template.sh

# Start all FIFO daemons
~/.agent-fifo/agent-ctl.sh startall

# Health check
~/.agent-fifo/agent-ctl.sh health

# Run test gauntlet (subset)
./test-prompts/scripts/gauntlet.sh --agents stacy,luna,kira --domains math
./test-prompts/scripts/evaluate.sh
./test-prompts/scripts/rank.sh
```

## User Isolation

- 21 users (opencode0–opencode20), each with own agent fleet
- opencode0 has sudo-to-opencodeX via `/etc/sudoers.d/opencode0-fleet`
- Each user has independent FIFOs, logs, and agent processes
- Template system ensures consistent configuration across all users
- All agents use same opencode-go account (fenced, 1:1 ratio)

## Filesystem Layout (per user)
```
/home/opencodeX/
├── .agent-fifo/          # FIFO daemon sessions
│   ├── agent-daemon.sh
│   ├── agent-ctl.sh
│   └── stacy/            # Per-agent: in, out, log, pid, status
├── .config/opencode/
│   ├── agent/            # 28 agent .md definitions
│   ├── agent-bin/        # 28 executable scripts
│   ├── scripts/sync-agents.sh
│   └── skills/agent-army/SKILL.md
├── .bashrc               # Includes agent-bin in PATH
├── AGENTS.md             # Quick reference
└── user_local_setup.sh   # Per-user tool installer
```
