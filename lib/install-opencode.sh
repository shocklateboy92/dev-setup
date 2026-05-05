# shellcheck shell=bash
# Install opencode (https://opencode.ai), the AI coding agent that VoxPilot wraps.
#
# Sourced from install.sh. Idempotent.
#
# Strategy: prefer the system package manager (auto-updates, audited). Fall
# back to the official curl install script on distros without a package.

if has_command opencode; then
  log_info "opencode: already installed ($(opencode --version 2>&1 | head -1))"
  return 0
fi

if is_arch; then
  ensure_system_package opencode opencode opencode opencode || return 1
elif is_macos; then
  if has_command brew; then
    log_info "opencode: installing via Homebrew tap (anomalyco/tap/opencode)"
    brew install anomalyco/tap/opencode
  else
    log_error "opencode: Homebrew required on macOS; install brew first"
    return 1
  fi
else
  # Debian/Ubuntu/Fedora/etc. -- use the official installer.
  log_info "opencode: no native package; using official install script"
  curl -fsSL https://opencode.ai/install | bash
  # Installer drops binary in ~/.local/bin or similar; ensure shell can find it.
  if ! has_command opencode; then
    log_warn "opencode: installed but not on PATH; you may need to start a new shell"
    log_warn "  the installer typically adds ~/.local/bin to PATH via your rc file"
  fi
fi
