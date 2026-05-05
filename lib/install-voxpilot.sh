# shellcheck shell=bash
# Install / update VoxPilot from the latest GitHub Release tarball.
#
# Sourced from install.sh. Idempotent.
#
# Layout:
#   ~/.local/share/voxpilot/                              -- extracted tarball
#   ~/.config/systemd/user/voxpilot.service               -- symlink into above
#   ~/.config/systemd/user/voxpilot-tsnet.service         -- optional, symlink
#   ~/.config/voxpilot/tsnet.env                          -- optional, secrets
#
# Re-running fetches the latest release, re-extracts, and restarts the service.

VOXPILOT_REPO="${VOXPILOT_REPO:-shocklateboy92/voxpilot}"
VOXPILOT_ROOT="${VOXPILOT_ROOT:-$HOME/.local/share/voxpilot}"

# Linux-only: systemd --user is not a thing on macOS.
if ! has_command systemctl; then
  log_warn "voxpilot: systemctl not found; skipping (Linux-only deploy)"
  return 0
fi

# Toolchain prerequisites: just curl + tar + the gh CLI for downloading the
# release asset. gh works without auth for public repo releases, but the
# token from setup-secrets is fine too.
ensure_system_package curl curl curl curl || return 1
ensure_system_package tar tar tar gnu-tar || return 1
ensure_system_package gh github-cli gh gh || return 1

# Detect arch -> tarball suffix.
case "$(uname -m)" in
  x86_64|amd64) ARCH_TAG="linux-x64" ;;
  aarch64|arm64) ARCH_TAG="linux-arm64" ;;
  *)
    log_error "voxpilot: unsupported architecture: $(uname -m)"
    return 1
    ;;
esac

# Find the latest release asset URL via the GitHub API.
log_info "voxpilot: querying latest release of $VOXPILOT_REPO"
asset_pattern="voxpilot-*-${ARCH_TAG}.tar.gz"
download_dir="$(mktemp -d)"
trap 'rm -rf "$download_dir"' RETURN

if ! gh release download --repo "$VOXPILOT_REPO" \
        --pattern "$asset_pattern" \
        --pattern "$asset_pattern.sha256" \
        --dir "$download_dir" \
        --clobber 2>&1; then
  log_error "voxpilot: failed to download release tarball matching '$asset_pattern'"
  return 1
fi

tarball="$(ls "$download_dir"/voxpilot-*.tar.gz 2>/dev/null | head -1)"
checksum="$tarball.sha256"
if [[ -z "$tarball" || ! -f "$tarball" ]]; then
  log_error "voxpilot: no tarball matched '$asset_pattern' in latest release"
  return 1
fi

# Verify checksum if present.
if [[ -f "$checksum" ]]; then
  log_info "voxpilot: verifying sha256"
  ( cd "$download_dir" && sha256sum -c "$(basename "$checksum")" >/dev/null ) || {
    log_error "voxpilot: checksum verification failed"
    return 1
  }
fi

# Extract. Tarball contains a top-level voxpilot/ dir which becomes
# $VOXPILOT_ROOT after extraction into ~/.local/share.
parent="$(dirname "$VOXPILOT_ROOT")"
mkdir -p "$parent"

# Stop the service before swapping files (binary may be in use).
if systemctl --user is-active --quiet voxpilot.service 2>/dev/null; then
  log_info "voxpilot: stopping running service for upgrade"
  systemctl --user stop voxpilot.service || true
fi
if systemctl --user is-active --quiet voxpilot-tsnet.service 2>/dev/null; then
  systemctl --user stop voxpilot-tsnet.service || true
fi

log_info "voxpilot: extracting to $VOXPILOT_ROOT"
# tar's --overwrite ensures we replace files cleanly. Note the tarball's top
# dir is literally 'voxpilot', so target name matches $(basename $VOXPILOT_ROOT)
# only when VOXPILOT_ROOT ends in /voxpilot. If it doesn't, rename after.
tar -xzf "$tarball" -C "$parent" --overwrite

extracted="$parent/voxpilot"
if [[ "$extracted" != "$VOXPILOT_ROOT" ]]; then
  rm -rf "$VOXPILOT_ROOT"
  mv "$extracted" "$VOXPILOT_ROOT"
fi

version="$(cat "$VOXPILOT_ROOT/VERSION" 2>/dev/null || echo "unknown")"
log_info "voxpilot: installed version $version"

# --- systemd unit setup ---------------------------------------------------
unit_dir="$HOME/.config/systemd/user"
mkdir -p "$unit_dir"

# Symlink the unit file from the install tree. Re-extracting updates the
# linked file automatically.
ln -sfn "$VOXPILOT_ROOT/systemd/voxpilot.service" "$unit_dir/voxpilot.service"
log_info "voxpilot: linked unit -> $unit_dir/voxpilot.service"

systemctl --user daemon-reload
systemctl --user enable --quiet voxpilot.service
systemctl --user restart voxpilot.service
log_info "voxpilot: service started -- check 'systemctl --user status voxpilot'"

# --- optional tsnet-proxy -------------------------------------------------
tsnet_env="$HOME/.config/voxpilot/tsnet.env"
tsnet_state_dir="$HOME/.local/state/voxpilot-tsnet"

# Detect tsnet config: either an auth key in tsnet.env or persisted state
# from a previous run.
tsnet_configured=0
if [[ -f "$tsnet_env" ]] && grep -Eq '^TS_AUTHKEY=.+' "$tsnet_env"; then
  tsnet_configured=1
fi
if [[ -d "$tsnet_state_dir" ]] && [[ -n "$(ls -A "$tsnet_state_dir" 2>/dev/null)" ]]; then
  tsnet_configured=1
fi

if [[ $tsnet_configured -eq 1 ]]; then
  ln -sfn "$VOXPILOT_ROOT/systemd/voxpilot-tsnet.service" \
          "$unit_dir/voxpilot-tsnet.service"
  log_info "voxpilot-tsnet: linked unit -> $unit_dir/voxpilot-tsnet.service"
  systemctl --user daemon-reload
  systemctl --user enable --quiet voxpilot-tsnet.service
  systemctl --user restart voxpilot-tsnet.service
  log_info "voxpilot-tsnet: service started"
else
  log_info "voxpilot-tsnet: not configured (no TS_AUTHKEY, no state); skipping."
  log_info "  to enable: create $tsnet_env with TS_AUTHKEY=<key> and re-run install.sh"
fi

log_info "voxpilot: deployed -- $VOXPILOT_ROOT (version $version)"
log_info "  logs:    journalctl --user -u voxpilot -f"
log_info "  status:  systemctl --user status voxpilot"
log_info "  tip:     run 'sudo loginctl enable-linger $USER' so it starts at boot"
