# shellcheck shell=bash
# Make the `setup-ha-automount` helper available on every dev-setup machine.
#
# Sourced from install.sh. Idempotent. Linux-only.
#
# This module does NOT mount anything itself. It just exposes the
# `setup-ha-automount` script on the user's PATH (via a symlink in
# ~/.local/bin pointing into the dev-setup clone). On the one machine
# that should act as the HA workbench, run `sudo setup-ha-automount` once.
#
# Why split it this way:
# - The actual mount needs root (sshfs system-mount + systemd .automount).
# - Most dev machines should NOT mount HA's /config (laptops that travel,
#   ephemeral VMs, etc.) -- so it can't be auto-applied.
# - But every machine that *might* become a workbench should have the
#   command ready to run, with the SSH key already materialized from
#   Infisical (handled by lib/install-secrets.sh).

if is_macos; then
  log_warn "ha-mount: macOS not supported (would need macFUSE); skipping"
  return 0
fi

bin_src="$DEV_SETUP_ROOT/bin/setup-ha-automount"
bin_dst="$HOME/.local/bin/setup-ha-automount"

if [[ ! -f "$bin_src" ]]; then
  log_error "ha-mount: missing $bin_src"
  return 1
fi

mkdir -p "$HOME/.local/bin"
ln -sfn "$bin_src" "$bin_dst"
chmod +x "$bin_src"
log_info "ha-mount: linked $bin_dst -> $bin_src"
log_info "  to enable the HA /config mount on this machine, run:"
log_info "    sudo \$(which setup-ha-automount)"
log_info "    (or: sudo $bin_dst -- sudo's secure_path strips ~/.local/bin)"
