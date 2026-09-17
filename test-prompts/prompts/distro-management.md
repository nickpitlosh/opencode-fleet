# Domain: Linux Distribution Management (Arch, Nix, Gentoo, Debian)

Create a unified build system for a custom application that targets all four distributions. Requirements:

**Arch Linux (PKGBUILD):**
1. Package a Rust application with proper makedepends, depends, checkdepends
2. Split package: runtime + docs + debug
3. systemd service unit with hardening (ProtectSystem, PrivateTmp, NoNewPrivileges)

**Gentoo (ebuild):**
2. EAPI 8 ebuild with USE flags: systemd, openssl, sqlite
3. src_compile with both cmake and cargo features
4. Pre-compiled binary fallback with a warning
5. OpenRC init script alternative

**Debian (debian/):**
1. Full debian/ directory: control, rules, changelog, copyright, watch file
2. Multi-arch support: amd64, arm64, riscv64
3. autopkgtest with 3 tests: smoke, integration, upgrade-from-prior
4. Lintian overrides where justified

**Nix (flake.nix):**
1. Flake with inputs: nixpkgs, rust-overlay, flake-utils
2. Output sets: packages, devShells, overlays, nixosModules
3. NixOS module with options: enable, package, settings (nixos/lib.mkOption)
4. cachix cache configuration

**Cross-distro CI:**
1. GitHub Actions matrix: build on all 4 distros, test install + run
2. Reproducible build verification: build twice, compare hashes
3. SBOM generation in SPDX format

Deliver: PKGBUILD, app.ebuild, debian/, flake.nix, .github/workflows/ci.yml, README.md
