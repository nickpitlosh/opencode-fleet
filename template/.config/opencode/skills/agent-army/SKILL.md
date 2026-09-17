---
name: agent-army
description: Manage and run a fleet of named opencode agents, one per opencode-go model. Use when the user wants to run tasks across multiple models in parallel, search using multiple agents, or manage the agent fleet (sync, list, add, remove).
---

# Agent Army

A fleet of named agents, one per `opencode-go` model. Each agent runs opencode with a unique model. All agents are fenced in the same account.

## Directory Layout

```
~/.config/opencode/
├── agent/                  # Agent definition files (.md)
│   ├── stacy.md           # -> deepseek-v4-flash
│   ├── riven.md           # -> deepseek-v4-flash-vision-exp
│   ├── kade.md            # -> deepseek-v4-pro
│   └── ...
├── agent-bin/             # Executable wrapper scripts
│   ├── stacy              # -> opencode run -m opencode-go/deepseek-v4-flash
│   ├── riven              # -> opencode run -m opencode-go/deepseek-v4-flash-vision-exp
│   └── ...
├── scripts/
│   └── sync-agents.sh     # Refresh agents to match current models
└── skills/agent-army/
    └── SKILL.md           # This file
```

## Quick Reference

| Agent | Model |
|-------|-------|
| stacy | opencode-go/deepseek-v4-flash |
| riven | opencode-go/deepseek-v4-flash-vision-exp |
| kade | opencode-go/deepseek-v4-pro |
| thera | opencode-go/deepseek-v4.1-flash |
| nyx | opencode-go/glm-5.1 |
| orion | opencode-go/glm-5.2 |
| vega | opencode-go/glm-5.3 |
| lumi | opencode-go/glm-5.3-flash |
| luna | opencode-go/gpt-5.6-luna |
| maverick | opencode-go/grok-4.6 |
| phoenix | opencode-go/hy3 |
| hikari | opencode-go/hy4-preview |
| kairo | opencode-go/kimi-k2.6 |
| kenji | opencode-go/kimi-k2.7-code |
| kira | opencode-go/kimi-k3 |
| felix | opencode-go/longcat-2.0 |
| mira | opencode-go/mimo-v2.5 |
| mireille | opencode-go/mimo-v2.5-pro |
| minim | opencode-go/minimax-m2.7 |
| maxim | opencode-go/minimax-m3 |
| spark | opencode-go/muse-spark-1.2-contributor |
| ember | opencode-go/muse-spark-1.3-contributor |
| qwenix | opencode-go/qwen3.6-plus |
| novax | opencode-go/qwen3.7-max |
| aria | opencode-go/qwen3.7-plus |
| flash | opencode-go/qwen3.8-flash |
| zephyr | opencode-go/qwen3.8-max |
| alpha | opencode-go/union-alpha |

## Usage

### Run a single agent with a prompt

```bash
stacy "explain quantum entanglement"
riven "review this function for edge cases"
```

### Run agents in parallel

Use bash background jobs or `xargs` to fan out across models:

```bash
# Run same prompt on 4 models in parallel
for agent in stacy luna maverick kira; do
  $agent "summarize the README.md" &
done
wait
```

```bash
# Run same prompt on ALL agents in parallel
ls ~/.config/opencode/agent-bin/ | while read agent; do
  $agent "what is the capital of France?" &
done
wait
```

```bash
# Parallel search with xargs (8 at a time)
ls ~/.config/opencode/agent-bin/ | xargs -P8 -I{} bash -c '{} "find files modified today"'
```

### Sync agents with latest models

```bash
~/.config/opencode/scripts/sync-agents.sh
```

This fetches the current model list from `opencode-go`, creates agents for any new models, and removes agents for discontinued models.

### List all agents

```bash
ls ~/.config/opencode/agent-bin/
```

### Check which model an agent uses

```bash
grep '^model:' ~/.config/opencode/agent/stacy.md
```

## Parallel Execution Patterns

### Pattern 1: Scatter-Gather Search

Send the same query to multiple agents, collect results:

```bash
mkdir -p /tmp/agent-results
for agent in stacy luna maverick kira felix; do
  $agent "find all TODO comments in src/" > "/tmp/agent-results/${agent}.txt" 2>&1 &
done
wait
cat /tmp/agent-results/*.txt
```

### Pattern 2: Split Workload

Divide a task across agents by model strength:

```bash
# Complex reasoning
kira "design the database schema for a multi-tenant app" &

# Fast iteration
stacy "generate boilerplate for the API routes" &

# Code specialization
kenji "write unit tests for the auth module" &

wait
```

### Pattern 3: Comparative Analysis

Run the same task on different models to compare outputs:

```bash
for agent in stacy luna maverick; do
  echo "=== $agent ==="
  $agent "implement fibonacci iteratively" &
done
wait
```

### Pattern 4: Fan-Out Fan-In with Result Aggregation

```bash
results=$(mktemp -d)
ls ~/.config/opencode/agent-bin/ | while read agent; do
  ($agent "count lines of code in src/" > "$results/$agent.out" 2>&1) &
done
wait
cat "$results"/*.out
```

## Maintaining the Fleet

1. Run `sync-agents.sh` periodically or when you notice new models available
2. The script preserves existing name assignments and auto-names new ones
3. Edit `~/.config/opencode/agent/<name>.md` to customize an agent's system prompt
4. Add the `agent-bin` directory to PATH for direct access:

```bash
export PATH="$HOME/.config/opencode/agent-bin:$PATH"
```

## Constraints

- **1:1 ratio**: Each agent maps to exactly one model. No sharing.
- **Same account**: All agents use the `opencode-go` provider, fenced in the same account.
- **No duplicates**: Sync detects and prevents duplicate agents for the same model.
