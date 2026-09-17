#!/usr/bin/env bash
# apply-template.sh — Push the current template to all opencode users.
# Lightweight version of deploy.sh for ongoing syncs (no user creation, no sudoers changes).
set -euo pipefail

TEMPLATE="/home/opencode0/template"
MAX_USER_NUM=20

echo "=== Applying template to all opencode users ==="

for i in $(seq 0 "$MAX_USER_NUM"); do
  user="opencode${i}"
  home="/home/${user}"

  if [ ! -d "$home" ]; then
    continue
  fi

  # Shell configs
  sudo -u "$user" install -m 0644 "${TEMPLATE}/.bashrc" "${home}/.bashrc"
  sudo -u "$user" install -m 0644 "${TEMPLATE}/.bash_profile" "${home}/.bash_profile"
  sudo -u "$user" install -m 0644 "${TEMPLATE}/.bash_logout" "${home}/.bash_logout"
  sudo -u "$user" install -m 0644 "${TEMPLATE}/.bashrc_garuda" "${home}/.bashrc_garuda"
  sudo -u "$user" install -m 0644 "${TEMPLATE}/.profile" "${home}/.profile"
  sudo -u "$user" install -m 0644 "${TEMPLATE}/AGENTS.md" "${home}/AGENTS.md"
  sudo -u "$user" install -m 0755 "${TEMPLATE}/user_local_setup.sh" "${home}/user_local_setup.sh"

  # .config/opencode
  sudo -u "$user" mkdir -p "${home}/.config/opencode"
  [ -d "${TEMPLATE}/.config/opencode/agent" ] && sudo -u "$user" cp -rT "${TEMPLATE}/.config/opencode/agent" "${home}/.config/opencode/agent"
  [ -d "${TEMPLATE}/.config/opencode/agent-bin" ] && sudo -u "$user" cp -rT "${TEMPLATE}/.config/opencode/agent-bin" "${home}/.config/opencode/agent-bin"
  [ -d "${TEMPLATE}/.config/opencode/scripts" ] && sudo -u "$user" cp -rT "${TEMPLATE}/.config/opencode/scripts" "${home}/.config/opencode/scripts"
  [ -d "${TEMPLATE}/.config/opencode/skills" ] && sudo -u "$user" cp -rT "${TEMPLATE}/.config/opencode/skills" "${home}/.config/opencode/skills"
  [ -f "${TEMPLATE}/.config/opencode/opencode.jsonc" ] && sudo -u "$user" install -m 0644 "${TEMPLATE}/.config/opencode/opencode.jsonc" "${home}/.config/opencode/opencode.jsonc"

  echo "  Synced: ${user}"
done

echo "=== Template apply complete ==="
