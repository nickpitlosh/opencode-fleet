#!/usr/bin/env bash
# scan-models.sh — Fleet pipeline STAGE 1 (standalone, no daemon).
#
# Scans the live opencode model landscape and writes ONE committed snapshot
# (TSV) that every later fleet stage consumes as its only model source.
# The zen free-rotation class rotates over time; models are NEVER hand-edited.
# Provider metadata listing only — no LLM inference calls are made here, so
# this stage does not burn opencode subscription completion quota.
#
#   scan-models.sh                 # prefer cached list (cheap)
#   scan-models.sh --refresh       # force a live provider model refresh first
#   scan-models.sh --snapshot FILE # write snapshot to FILE (default models.tsv)
set -uo pipefail
umask 077

SNAP_DEFAULT="$HOME/fleet-data/models.tsv"
SNAP="$SNAP_DEFAULT"
REFRESH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --refresh) REFRESH=1 ;;
    --snapshot) SNAP="$2"; shift ;;
    *) echo "usage: scan-models.sh [--refresh] [--snapshot FILE]" >&2; exit 1 ;;
  esac
  shift
done

CACHE="$HOME/.cache/opencode/models.json"
TMP="$(mktemp)"

if [ "$REFRESH" -eq 1 ]; then
  # Metadata-only refresh from the provider; a listing, not an LLM call.
  opencode models --refresh >/dev/null 2>&1 || true
fi

# Model source: prefer the provider cache, else a fresh CLI listing (TSV-safe).
SRC="$CACHE"
if [ ! -s "$SRC" ]; then
  opencode models > "$TMP" 2>/dev/null || SRC=""
fi
[ -s "$SRC" ] || { echo "scan-models: no model source (cache empty and CLI unavailable)" >&2; exit 1; }

mkdir -p "$(dirname "$SNAP")"
python3 - "$SRC" "$SNAP" <<'PY'
import sys, json, time

src, out = sys.argv[1], sys.argv[2]
now = int(time.time())

try:
    data = json.load(open(src))
except Exception as e:
    sys.stderr.write(f"scan-models: cannot parse {src}: {e}\n")
    sys.exit(1)

rows = []
models = data.get("models", data) if isinstance(data, dict) else {}

for mid, meta in models.items():
    if not isinstance(meta, dict):
        continue
    if not isinstance(mid, str):
        continue
    prov = meta.get("provider") or ""
    if not prov and "/" in mid:
        prov = mid.split("/", 1)[0]
    mid_l = mid.lower()
    zenc = ("zen" in mid_l) or ("/zen" in mid_l) or (prov.lower() == "zen")
    rows.append((mid, "zen" if zenc else "standard", prov, now))

rows.sort()
with open(out, "w") as f:
    f.write("#model\tclass\tprovider\tfetched-at\n")
    for r in rows:
        f.write("\t".join(str(x) for x in r) + "\n")

sys.stderr.write(f"scan-models: {len(rows)} models -> {out}\n")
PY
exit 0
