#!/usr/bin/env bash
# sync-agents.sh — Refresh agent definitions to match current opencode-go models.
# Creates new agents for any model not yet represented, updates existing ones.
# Ratio: exactly one agent per model, all fenced in the opencode-go provider.
set -euo pipefail

AGENT_DIR="${HOME}/.config/opencode/agent"
BIN_DIR="${HOME}/.config/opencode/agent-bin"
PROVIDER="opencode-go"
PREFIX="${PROVIDER}/"

mkdir -p "$AGENT_DIR" "$BIN_DIR"

# Short names pool for auto-naming new models
NAMES_POOL=(
  cleo dax echo finn gale halo iris jade knot lark moss nero opal pike
  quin rue sage tessa vale wren xena yale zane amber blitz cipher dusk
  flare gleam hawk ink jade karma lumen nyx orion pulse quest raven
  streak torch ultra vega whisper xenon yarrow zephyr
)

declare -A MODEL_TO_NAME=(
  ["deepseek-v4-flash"]="stacy"
  ["deepseek-v4-flash-vision-exp"]="riven"
  ["deepseek-v4-pro"]="kade"
  ["deepseek-v4.1-flash"]="thera"
  ["glm-5.1"]="nyx"
  ["glm-5.2"]="orion"
  ["glm-5.3"]="vega"
  ["glm-5.3-flash"]="lumi"
  ["gpt-5.6-luna"]="luna"
  ["grok-4.6"]="maverick"
  ["hy3"]="phoenix"
  ["hy4-preview"]="hikari"
  ["kimi-k2.6"]="kairo"
  ["kimi-k2.7-code"]="kenji"
  ["kimi-k3"]="kira"
  ["longcat-2.0"]="felix"
  ["mimo-v2.5"]="mira"
  ["mimo-v2.5-pro"]="mireille"
  ["minimax-m2.7"]="minim"
  ["minimax-m3"]="maxim"
  ["muse-spark-1.2-contributor"]="spark"
  ["muse-spark-1.3-contributor"]="ember"
  ["qwen3.6-plus"]="qwenix"
  ["qwen3.7-max"]="novax"
  ["qwen3.7-plus"]="aria"
  ["qwen3.8-flash"]="flash"
  ["qwen3.8-max"]="zephyr"
  ["union-alpha"]="alpha"
)

# Fetch current models from opencode
mapfile -t CURRENT_MODELS < <(opencode models "$PROVIDER" 2>/dev/null | sed "s|^${PREFIX}||" | sort -u)

if [ ${#CURRENT_MODELS[@]} -eq 0 ]; then
  echo "ERROR: no models returned for provider ${PROVIDER}" >&2
  exit 1
fi

echo "Found ${#CURRENT_MODELS[@]} models for ${PROVIDER}"

# Track existing agent names
declare -A EXISTING_NAMES
for f in "$AGENT_DIR"/*.md; do
  [ -f "$f" ] || continue
  b="$(basename "$f" .md)"
  EXISTING_NAMES[$b]=1
done

# Assign names to models not in our map
name_idx=0
for model in "${CURRENT_MODELS[@]}"; do
  if [ -z "${MODEL_TO_NAME[$model]+x}" ]; then
    # Auto-assign a name from the pool
    while [ $name_idx -lt ${#NAMES_POOL[@]} ]; do
      candidate="${NAMES_POOL[$name_idx]}"
      name_idx=$((name_idx + 1))
      if [ -z "${EXISTING_NAMES[$candidate]+x}" ]; then
        MODEL_TO_NAME[$model]="$candidate"
        echo "AUTO-ASSIGNED: ${model} -> ${candidate}"
        break
      fi
    done
  fi
done

# Create/update agents
created=0
updated=0
for model in "${CURRENT_MODELS[@]}"; do
  name="${MODEL_TO_NAME[$model]:-}"
  if [ -z "$name" ]; then
    echo "SKIP: no name available for ${model}" >&2
    continue
  fi
  full_model="${PROVIDER}/${model}"
  agent_file="${AGENT_DIR}/${name}.md"
  bin_file="${BIN_DIR}/${name}"

  if [ -f "$agent_file" ]; then
    # Update model reference in case it changed
    sed -i "s|^model:.*|model: ${full_model}|" "$agent_file"
    sed -i "s|exec opencode run -m \".*\"|exec opencode run -m \"${full_model}\" \"\\\$@\"|" "$bin_file" 2>/dev/null || true
    updated=$((updated + 1))
  else
    # Create new agent
    cat > "$agent_file" <<EOF
---
description: ${name} agent — powered by ${full_model}. Use when you need this model's specific capabilities.
mode: subagent
model: ${full_model}
permission:
  edit: ask
  bash: ask
---

You are the **${name}** agent, running on the \`${full_model}\` model.
Execute the user's request using your model's strengths. Be direct, accurate, and concise.
EOF

    cat > "$bin_file" <<EOF
#!/usr/bin/env bash
# ${name} — runs opencode with ${full_model}
exec opencode run -m "${full_model}" "\$@"
EOF
    chmod +x "$bin_file"
    echo "CREATED: ${name} -> ${full_model}"
    created=$((created + 1))
  fi
done

# Remove agents for models that no longer exist
removed=0
declare -A VALID_MODELS
for model in "${CURRENT_MODELS[@]}"; do
  VALID_MODELS[$model]=1
done

for f in "$AGENT_DIR"/*.md; do
  [ -f "$f" ] || continue
  b="$(basename "$f" .md)"
  # Check if this agent's model is still valid
  agent_model="$(grep '^model:' "$f" | head -1 | sed 's/^model: *//')"
  agent_model_short="${agent_model#${PREFIX}}"
  if [ -z "${VALID_MODELS[$agent_model_short]+x}" ]; then
    rm -f "$f" "$BIN_DIR/$b"
    echo "REMOVED: ${b} (model ${agent_model} no longer available)"
    removed=$((removed + 1))
  fi
done

echo ""
echo "=== sync complete ==="
echo "  created: ${created}"
echo "  updated: ${updated}"
echo "  removed: ${removed}"
echo "  total agents: $(ls "$AGENT_DIR"/*.md 2>/dev/null | wc -l)"
echo "  total scripts: $(ls "$BIN_DIR"/* 2>/dev/null | wc -l)"
echo ""
echo "Add ${BIN_DIR} to PATH to use agent names directly:"
echo "  export PATH=\"${BIN_DIR}:\$PATH\""
