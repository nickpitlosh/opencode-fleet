#!/usr/bin/env bash
# deploy.sh — Ensure opencode users exist, have sudo access, and are in sync with the template.
# Must be run as opencode0 (which needs sudo to opencode* users via /etc/sudoers.d).
set -euo pipefail

TEMPLATE="/home/opencode0/template"
MAX_USER_NUM=20

echo "=== Deploy: ensuring users + sudo + template sync ==="

# --- Step 0: Verify sudo access ---
if ! sudo -n -u opencode1 true 2>/dev/null; then
  echo "ERROR: opencode0 cannot sudo to other users." >&2
  echo "Run: echo 'ROOTPASS' | su -c 'mkdir -p /etc/sudoers.d && visudo -c'" >&2
  exit 1
fi

# --- Step 1: Create missing users ---
echo ""
echo "--- Step 1: Creating missing users ---"
MISSING_ROOT_PASS="${ROOTPASS:-}"
for i in $(seq 0 "$MAX_USER_NUM"); do
  user="opencode${i}"
  if ! getent passwd "$user" >/dev/null 2>&1; then
    echo "  Creating user: ${user}"
    if [ -n "$MISSING_ROOT_PASS" ]; then
      echo "$MISSING_ROOT_PASS" | su -c "useradd -m -s /bin/bash '${user}'" root 2>&1 | tail -1
    else
      echo "  WARN: User ${user} missing but no ROOTPASS provided. Skipping." >&2
    fi
  else
    echo "  Exists: ${user}"
  fi
done

# --- Step 2: Apply template to all users ---
echo ""
echo "--- Step 2: Applying template to all users ---"

for i in $(seq 0 "$MAX_USER_NUM"); do
  user="opencode${i}"
  home="/home/${user}"

  if [ ! -d "$home" ]; then
    echo "  SKIP: home dir missing for ${user}"
    continue
  fi

  echo "  Pushing template to ${user}..."

  # Shell configs (owned by target user)
  sudo -u "$user" install -m 0644 "${TEMPLATE}/.bashrc" "${home}/.bashrc"
  sudo -u "$user" install -m 0644 "${TEMPLATE}/.bash_profile" "${home}/.bash_profile"
  sudo -u "$user" install -m 0644 "${TEMPLATE}/.bash_logout" "${home}/.bash_logout"
  sudo -u "$user" install -m 0644 "${TEMPLATE}/.bashrc_garuda" "${home}/.bashrc_garuda"
  sudo -u "$user" install -m 0644 "${TEMPLATE}/.profile" "${home}/.profile"
  sudo -u "$user" install -m 0644 "${TEMPLATE}/AGENTS.md" "${home}/AGENTS.md"
  sudo -u "$user" install -m 0755 "${TEMPLATE}/user_local_setup.sh" "${home}/user_local_setup.sh"

  # .config/opencode — create dirs, copy, fix ownership
  sudo -u "$user" mkdir -p "${home}/.config/opencode"

  if [ -d "${TEMPLATE}/.config/opencode/agent" ]; then
    sudo -u "$user" cp -r "${TEMPLATE}/.config/opencode/agent" "${home}/.config/opencode/"
  fi
  if [ -d "${TEMPLATE}/.config/opencode/agent-bin" ]; then
    sudo -u "$user" cp -r "${TEMPLATE}/.config/opencode/agent-bin" "${home}/.config/opencode/"
  fi
  if [ -d "${TEMPLATE}/.config/opencode/scripts" ]; then
    sudo -u "$user" cp -r "${TEMPLATE}/.config/opencode/scripts" "${home}/.config/opencode/"
  fi
  if [ -d "${TEMPLATE}/.config/opencode/skills" ]; then
    sudo -u "$user" cp -r "${TEMPLATE}/.config/opencode/skills" "${home}/.config/opencode/"
  fi
  if [ -f "${TEMPLATE}/.config/opencode/opencode.jsonc" ]; then
    sudo -u "$user" install -m 0644 "${TEMPLATE}/.config/opencode/opencode.jsonc" "${home}/.config/opencode/opencode.jsonc"
  fi

  echo "  Done: ${user}"
done

# --- Step 3: Verify ---
echo ""
echo "--- Step 3: Verification ---"
echo "Total opencode users: $(getent passwd | grep -c '^opencode')"
echo "Sudo test: $(sudo -u opencode1 whoami 2>&1) / $(sudo -u opencode10 whoami 2>&1) / $(sudo -u opencode20 whoami 2>&1)"
echo "Agent counts:"
for i in 0 1 5 10 15 20; do
  user="opencode${i}"
  home="/home/${user}"
  if [ -d "${home}/.config/opencode/agent" ]; then
    count=$(sudo -u "$user" bash -c "ls ${home}/.config/opencode/agent/*.md 2>/dev/null | wc -l")
    bincount=$(sudo -u "$user" bash -c "ls ${home}/.config/opencode/agent-bin/* 2>/dev/null | wc -l")
    echo "  ${user}: ${count} agent defs, ${bincount} scripts"
  fi
done

echo ""
echo "=== Deploy complete ==="
