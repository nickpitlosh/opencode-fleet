#!/usr/bin/env bash
# ledger-update.sh — Fleet pipeline STAGE 2 (standalone).
#
# Rebuilds the fleet ledger: one opencodeX OS account <-> one agent <-> one
# model, 1:1, in stable opencodeX ordering. Consumes ONLY the STAGE 1 model
# snapshot (the canonical model truth) and the per-agent configs (canonical
# agent truth). This is the ONLY intermediate stage between the live model
# scan and any account<->model synchronization.
#
#   ledger-update.sh [--snapshot F] [--ledger F] [--dry-run]
#
# The ledger NEVER deletes rows and NEVER hand-edits models.
set -uo pipefail

SNAP_DEFAULT="$HOME/fleet-data/models-snapshot.tsv"
LEDGER_DEFAULT="$HOME/fleet-data/fleet-ledger.tsv"
SNAP="$SNAP_DEFAULT"
LEDGER="$LEDGER_DEFAULT"
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --snapshot) SNAP="$2"; shift ;;
    --ledger) LEDGER="$2"; shift ;;
    --dry-run) DRY=1 ;;
    *) echo "usage: ledger-update.sh [--snapshot F] [--ledger F] [--dry-run]" >&2; exit 1 ;;
  esac
  shift
done

[ -s "$SNAP" ] || { echo "ledger-update: no snapshot — run scan-models.sh first (snapshot must precede any account↔model sync)" >&2; exit 1; }

AGENT_DIR="$HOME/.config/opencode/agent"

python3 - "$SNAP" "$AGENT_DIR" "$LEDGER" <<'PY'
import os, re, sys

snap_f, agent_dir, out_f = sys.argv[1], sys.argv[2], sys.argv[3]

# --- snapshot: canonical model truth (STAGE 1 output). Never hand-edit. ---
model_provider = {}   # model -> provider
model_class = {}      # model -> "zen" | "standard"
with open(snap_f) as f:
    for line in f:
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        mid = parts[0]
        model_class[mid] = parts[1]
        model_provider[mid] = parts[2]

# --- agent configs: canonical agent truth (the .md agent definitions). ---
agents = []
try:
    agents = sorted(n for n in os.listdir(agent_dir) if n.endswith(".md"))
except FileNotFoundError:
    sys.stderr.write("ledger-update: no agent config dir %s\n" % agent_dir)
    agents = []

agent_model = {}
for a in agents:
    p = os.path.join(agent_dir, a)
    try:
        with open(p) as f:
            for line in f:
                m = re.match(r"^\s*model:\s*(\S+)", line)
                if m:
                    agent_model[a[:-3]] = m.group(1)
                    break
    except OSError:
        continue

# --- write ledger: account \t agent \t model \t model-class \t provider ---
# Account name = opencodeN where N is the 1-based index of the agent in the
# same sorted order the fleet always enumerates them (stable).
rows = []
for i, a in enumerate(agents, start=1):
    name = a[:-3]
    model = agent_model.get(name, "")
    rows.append("\t".join([f"opencode{i}", name, model, model_class.get(model, ""), model_provider.get(model, "")]))

if not rows:
    sys.stderr.write("ledger-update: ledger would be empty; refusing\n")
    sys.exit(1)

out = "#account\tagent\tmodel\tmodel-class\tprovider\n" + "\n".join(rows) + "\n"
if out_f == "-":
    sys.stdout.write(out)
else:
    import os as _os
    _os.makedirs(_os.path.dirname(out_f), exist_ok=True)
    with open(out_f, "w") as f:
        f.write(out)
    sys.stderr.write(f"ledger-update: {len(rows)} rows -> {out_f}\n")
PY
