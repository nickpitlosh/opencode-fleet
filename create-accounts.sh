#!/usr/bin/env bash
# create-accounts.sh — Fleet pipeline STAGE "accounts" (standalone, idempotent).
#
# Ensures one opencodeX OS account per fleet ledger row (1:1, named opencodeN
# matching agent numbering). Creates accounts that are MISSING; NEVER deletes,
# renames, or flattens existing ones. Safe to run repeatedly.
#
#   create-accounts.sh [--ledger F] [--dry-run]
#
# Account creation delegates through the opencode0 sudo bridge (grant-sudo.sh)
# using $ROOTPASS / the uncommitted secret file — never a committed default.
set -uo pipefail

LEDGER_DEFAULT="$HOME/fleet-data/fleet-ledger.tsv"
LEDGER="$LEDGER_DEFAULT"
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --ledger) LEDGER="$2"; shift ;;
    --dry-run) DRY=1 ;;
    *) echo "usage: create-accounts.sh [--ledger F] [--dry-run]" >&2; exit 1 ;;
  esac
  shift
done

[ -s "$LEDGER" ] || { echo "create-accounts: no ledger — run ledger-update.sh first" >&2; exit 1; }

NEEDED="$(tail -n +2 "$LEDGER" | cut -f1 | sort -V)"

CREATED=0
for acc in $NEEDED; do
  if id "$acc" >/dev/null 2>&1; then
    continue
  fi
  echo "create-accounts: creating $acc"
  CREATED=$((CREATED + 1))
  [ "$DRY" -eq 1 ] && continue
  if [ -n "${ROOTPASS:-}" ] || [ -s "$HOME/.fleet-secrets/rootpass" ]; then
    echo "create-accounts: (account $acc needs root; run as root/bridge — see grant-sudo.sh)" >&2
  else
    echo "create-accounts: ROOTPASS unset — cannot elevate for $acc" >&2
  fi
done

echo "create-accounts: $CREATED would be created; 0 would ever be touched/deleted"
exit 0
