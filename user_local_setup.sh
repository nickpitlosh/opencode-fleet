#!/usr/bin/env bash
# Per-user, no-root tool/skill/MCP installer for Garuda and Gentoo.
# Does not set or store any root password.
set -euo pipefail

export HOME="${HOME:-$(getent passwd "$(id -un)" | cut -d: -f6)}"
export PATH="/usr/bin:/bin:/usr/local/bin:${HOME}/.local/bin:${HOME}/.opencode/bin:${HOME}/.local/node/bin"
umask 022

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) GH_ARCH=x86_64; NODE_ARCH=x64 ;;
  aarch64|arm64) GH_ARCH=aarch64; NODE_ARCH=arm64 ;;
  *) GH_ARCH=x86_64; NODE_ARCH=x64 ;;
esac

distro_id=unknown
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  distro_id="${ID:-unknown}"
fi

mkdir -p \
  "${HOME}/.local/bin" \
  "${HOME}/.local/share" \
  "${HOME}/.local/node" \
  "${HOME}/.opencode/bin" \
  "${HOME}/.config/opencode/skills" \
  "${HOME}/.config/opencode/agent" \
  "${HOME}/.cache"

echo "user=$(id -un) distro=${distro_id} arch=${ARCH} home=${HOME}"

install_opencode() {
  if [ -x "${HOME}/.opencode/bin/opencode" ] || [ -x "${HOME}/.local/bin/opencode" ]; then
    echo "opencode present"
    return 0
  fi
  curl -fsSL https://opencode.ai/install | env OPENCODE_INSTALL_DIR="${HOME}/.opencode/bin" bash -s -- --no-modify-path
  if [ -x "${HOME}/.opencode/bin/opencode" ]; then
    ln -sfn "${HOME}/.opencode/bin/opencode" "${HOME}/.local/bin/opencode"
  fi
}

install_gh_bin() {
  local name="$1" url="$2" bin="$3"
  if command -v "$bin" >/dev/null 2>&1; then
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" -o "${tmp}/pkg.tgz"; then
    tar -xzf "${tmp}/pkg.tgz" -C "$tmp" 2>/dev/null || tar -xf "${tmp}/pkg.tgz" -C "$tmp" 2>/dev/null || true
    local found
    found="$(find "$tmp" -type f -name "$bin" | head -1)"
    if [ -n "$found" ]; then
      install -m 0755 "$found" "${HOME}/.local/bin/$bin"
      echo "installed $bin"
    else
      echo "no $bin in archive $url"
    fi
  else
    echo "download failed: $name"
  fi
  rm -rf "$tmp"
}

install_starship() {
  command -v starship >/dev/null 2>&1 && return 0
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y --bin-dir "${HOME}/.local/bin" || true
}

install_zoxide() {
  command -v zoxide >/dev/null 2>&1 && return 0
  curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash || true
}

install_fzf() {
  command -v fzf >/dev/null 2>&1 && return 0
  git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.local/share/fzf" 2>/dev/null || true
  if [ -x "${HOME}/.local/share/fzf/install" ]; then
    "${HOME}/.local/share/fzf/install" --bin --no-update-rc --no-key-bindings --no-completion || true
    [ -x "${HOME}/.local/share/fzf/bin/fzf" ] && ln -sfn "${HOME}/.local/share/fzf/bin/fzf" "${HOME}/.local/bin/fzf"
  fi
}

install_node() {
  if command -v node >/dev/null 2>&1 && command -v npx >/dev/null 2>&1; then
    return 0
  fi
  if [ -x "${HOME}/.local/node/bin/node" ]; then
    return 0
  fi
  local ver="v22.19.0"
  local tar="node-${ver}-linux-${NODE_ARCH}.tar.xz"
  local src="${NODE_DIST:-/tmp/${tar}}"
  local tmp
  tmp="$(mktemp -d)"
  if [ -f "$src" ]; then
    cp "$src" "${tmp}/${tar}"
  elif curl -fsSL "https://nodejs.org/dist/${ver}/${tar}" -o "${tmp}/${tar}"; then
    true
  else
    echo "node download failed"
    rm -rf "$tmp"
    return 0
  fi
  if [ -f "${tmp}/${tar}" ]; then
    tar -xJf "${tmp}/${tar}" -C "$tmp"
    mkdir -p "${HOME}/.local/node"
    cp -a "${tmp}/node-${ver}-linux-${NODE_ARCH}/." "${HOME}/.local/node/"
    ln -sfn "${HOME}/.local/node/bin/node" "${HOME}/.local/bin/node"
    ln -sfn "${HOME}/.local/node/bin/npm" "${HOME}/.local/bin/npm"
    ln -sfn "${HOME}/.local/node/bin/npx" "${HOME}/.local/bin/npx"
    echo "installed node ${ver}"
  else
    echo "node download failed"
  fi
  rm -rf "$tmp"
}

write_skills() {
  local s="${HOME}/.config/opencode/skills"

  mkdir -p "${s}/git-release"
  cat > "${s}/git-release/SKILL.md" <<'EOF'
---
name: git-release
description: Create consistent releases and changelogs from git history. Use when tagging a release or drafting gh release notes.
license: MIT
compatibility: opencode
---
## What I do
- Draft release notes from merged commits/PRs
- Propose a version bump
- Provide a copy-pasteable `gh release create` command
## When to use
Preparing a tagged release. Ask if the versioning scheme is unclear.
EOF

  mkdir -p "${s}/test-first"
  cat > "${s}/test-first/SKILL.md" <<'EOF'
---
name: test-first
description: Write failing tests before implementation. Use when adding features, fixing bugs, or the user asks for TDD.
license: MIT
compatibility: opencode
---
## Procedure
1. Identify the behavior change.
2. Add or update tests that fail for the right reason.
3. Implement the smallest change that makes tests pass.
4. Refactor only after green.
## Anti-patterns
Do not ship untested behavior. Do not weaken tests to match broken code.
EOF

  mkdir -p "${s}/code-review"
  cat > "${s}/code-review/SKILL.md" <<'EOF'
---
name: code-review
description: Review diffs for correctness, security, and missing tests. Use when asked to review a PR, patch, or uncommitted changes.
license: MIT
compatibility: opencode
---
## Procedure
1. Read the full diff and surrounding context.
2. Flag bugs, race conditions, injection, secret leaks, and missing tests.
3. Suggest concrete patches, not vague advice.
4. Separate blocking issues from nits.
EOF

  mkdir -p "${s}/skill-creator"
  cat > "${s}/skill-creator/SKILL.md" <<'EOF'
---
name: skill-creator
description: Create a well-formed OpenCode SKILL.md from a repeated workflow. Use when the user wants a new skill.
license: MIT
compatibility: opencode
---
## Procedure
1. Pick a hyphenated lowercase name matching the directory.
2. Write YAML frontmatter with name and description.
3. Keep the body as steps, quality bar, and anti-patterns.
4. Put long reference material in references/.
EOF
}

write_opencode_config() {
  local cfg="${HOME}/.config/opencode/opencode.json"
  local npx="${HOME}/.local/bin/npx"
  [ -x "${HOME}/.local/node/bin/npx" ] && npx="${HOME}/.local/node/bin/npx"
  command -v npx >/dev/null 2>&1 && npx="$(command -v npx)"

  cat > "$cfg" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "mcp": {
    "filesystem": {
      "type": "local",
      "command": ["${npx}", "-y", "@modelcontextprotocol/server-filesystem", "${HOME}"],
      "enabled": true
    },
    "git": {
      "type": "local",
      "command": ["${npx}", "-y", "@modelcontextprotocol/server-git", "--repository", "${HOME}"],
      "enabled": true
    },
    "fetch": {
      "type": "local",
      "command": ["${npx}", "-y", "@modelcontextprotocol/server-fetch"],
      "enabled": true
    },
    "memory": {
      "type": "local",
      "command": ["${npx}", "-y", "@modelcontextprotocol/server-memory"],
      "enabled": false
    },
    "sequential-thinking": {
      "type": "local",
      "command": ["${npx}", "-y", "@modelcontextprotocol/server-sequential-thinking"],
      "enabled": false
    },
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "enabled": true,
      "oauth": false
    }
  },
  "tools": {
    "memory*": false,
    "sequential-thinking*": false
  },
  "agent": {
    "plan": {
      "tools": {
        "sequential-thinking*": true,
        "context7*": true
      }
    },
    "build": {
      "tools": {
        "memory*": true,
        "filesystem*": true,
        "git*": true
      }
    },
    "general": {
      "tools": {
        "fetch*": true,
        "context7*": true
      }
    }
  },
  "permission": {
    "skill": {
      "*": "allow"
    }
  }
}
EOF
}

wire_shell() {
  local line='export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.local/node/bin:$PATH"'
  for rc in "${HOME}/.bashrc" "${HOME}/.profile"; do
    touch "$rc"
    grep -qxF "$line" "$rc" 2>/dev/null || printf '\n%s\n' "$line" >> "$rc"
  done
  mkdir -p "${HOME}/.config/fish"
  touch "${HOME}/.config/fish/config.fish"
  grep -q 'opencode/bin' "${HOME}/.config/fish/config.fish" 2>/dev/null || \
    echo 'fish_add_path $HOME/.local/bin $HOME/.opencode/bin $HOME/.local/node/bin' >> "${HOME}/.config/fish/config.fish"
}

try_npx_skills() {
  command -v npx >/dev/null 2>&1 || return 0
  npx --yes skills add https://github.com/anthropics/skills --skill skill-creator -g -a opencode -y >/dev/null 2>&1 || true
  npx --yes skills add vercel-labs/agent-skills --skill frontend-design -g -a opencode -y >/dev/null 2>&1 || true
}

install_opencode
install_starship
install_zoxide
install_fzf
install_gh_bin ripgrep "https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-${GH_ARCH}-unknown-linux-musl.tar.gz" rg
install_gh_bin fd "https://github.com/sharkdp/fd/releases/download/v10.2.0/fd-v10.2.0-${GH_ARCH}-unknown-linux-musl.tar.gz" fd
install_node
write_skills
write_opencode_config
try_npx_skills
wire_shell

echo "done $(id -un) opencode=$(command -v opencode || echo missing) node=$(command -v node || echo missing)"
