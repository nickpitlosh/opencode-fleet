# Agent Army — Multi-Model Parallel Execution

This account runs a fleet of named opencode agents, one per `opencode-go` model.
Each agent is a short name (like `stacy`) that invokes opencode with a specific model.

## Available Agents

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

## Running Agents

### Single agent
```bash
stacy "your prompt here"
```

### Multiple agents in parallel
```bash
for agent in stacy luna maverick kira; do
  $agent "search for error handling patterns" &
done
wait
```

### All agents at once
```bash
ls ~/.config/opencode/agent-bin/ | while read agent; do
  $agent "what does this repo do?" &
done
wait
```

### Parallel with xargs (8 concurrent)
```bash
ls ~/.config/opencode/agent-bin/ | xargs -P8 -I{} bash -c '{} "your prompt"'
```

## Fleet Management

```bash
# Sync agents with latest opencode-go models
~/.config/opencode/scripts/sync-agents.sh

# List all agents
ls ~/.config/opencode/agent-bin/

# Check an agent's model
grep '^model:' ~/.config/opencode/agent/stacy.md
```

## Key Constraints

- **1:1 ratio** — each agent maps to exactly one model
- **Same account** — all agents use the `opencode-go` provider
- **Short names** — all agents have memorable names like `stacy`, `riven`, `kade`
- **Arbitrary prompts** — each agent can run any prompt on its assigned model
