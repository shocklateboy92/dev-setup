# shellcheck shell=bash
# Install the opencode-pty plugin so the agent can spawn/read/write/kill
# persistent PTY sessions (background dev servers, watch modes, REPLs, and
# long-running tasks that must survive across tool calls). Provides the
# pty_spawn / pty_write / pty_read / pty_list / pty_kill tools.
#
# Sourced from install.sh. Idempotent.
#
# Why a *pinned local* install instead of `plugin: ["opencode-pty"]`:
#   opencode-pty 0.3.4 declares bun-pty ^0.4.8, which resolves to 0.4.9, but
#   the plugin's own monkey-patch guard throws on bun-pty > 0.4.8. We ship a
#   package.json (lib/opencode-pty/package.json) that pins bun-pty to 0.4.8
#   via an `overrides` block and install it into a self-contained directory.
#   Revisit once https://github.com/shekohex/opencode-pty/issues/36 is fixed.
#
# Wiring: opencode auto-loads any *.js in ~/.config/opencode/plugins/ at
# startup (see https://opencode.ai/docs/plugins "Load order"). We drop a small
# managed shim there that re-exports the pinned build, so we NEVER touch the
# user's opencode.json/opencode.jsonc (which may carry unrelated model/provider
# overrides). If a config file already wires opencode-pty itself, we defer to
# it and skip the shim so the plugin isn't loaded twice.

ensure_system_package node nodejs nodejs nodejs
ensure_system_package npm npm npm node

opencode_dir="$HOME/.config/opencode"
pin_src="$DEV_SETUP_ROOT/lib/opencode-pty/package.json"
pin_dir="$opencode_dir/local-plugins/opencode-pty"
dist_rel="node_modules/opencode-pty/dist/index.js"
dist="$pin_dir/$dist_rel"
plugins_dir="$opencode_dir/plugins"
shim="$plugins_dir/dev-setup-opencode-pty.js"
shim_marker="// managed by dev-setup (lib/install-opencode-pty.sh)"

if [[ ! -f "$pin_src" ]]; then
  log_error "opencode-pty: missing pinned manifest at $pin_src"
  return 1
fi

# --- 1. materialize + install the pinned plugin -----------------------------
mkdir -p "$pin_dir"

# Only (re)install when the manifest changed or the build is absent. npm honors
# the `overrides` block in the manifest, so bun-pty resolves to 0.4.8.
need_install=0
if [[ ! -f "$dist" ]]; then
  need_install=1
elif ! cmp -s "$pin_src" "$pin_dir/package.json"; then
  need_install=1
fi

cp -f "$pin_src" "$pin_dir/package.json"

if [[ $need_install -eq 1 ]]; then
  log_info "opencode-pty: installing pinned plugin into $pin_dir"
  if ! ( cd "$pin_dir" && npm install --silent --no-audit --no-fund >/dev/null ); then
    log_error "opencode-pty: npm install failed in $pin_dir"
    return 1
  fi
else
  log_info "opencode-pty: pinned plugin already installed"
fi

if [[ ! -f "$dist" ]]; then
  log_error "opencode-pty: build missing after install ($dist)"
  return 1
fi

# --- 2. wiring: skip if a config file already references the plugin ---------
# Read-only probe of the user's config; we never edit it.
config_wired=0
for cfg in "$opencode_dir/opencode.json" "$opencode_dir/opencode.jsonc"; do
  if [[ -f "$cfg" ]] && grep -q "opencode-pty" "$cfg"; then
    config_wired=1
    log_info "opencode-pty: already wired via $(basename "$cfg"); leaving config untouched"
    break
  fi
done

if [[ $config_wired -eq 1 ]]; then
  # Config owns the wiring. Remove our shim if we previously wrote one, so the
  # plugin doesn't load twice. Only ever delete our own managed file.
  if [[ -f "$shim" ]] && head -1 "$shim" | grep -qF "$shim_marker"; then
    rm -f "$shim"
    log_info "opencode-pty: removed redundant managed shim (config wires it)"
  fi
  return 0
fi

# --- 3. wire via an auto-discovered global plugin shim ----------------------
# The plugin exposes a named export `PTYPlugin` (no default); re-export it.
mkdir -p "$plugins_dir"
tmp_shim="$(mktemp "$plugins_dir/.dev-setup-pty-XXXXXX")"
{
  printf '%s\n' "$shim_marker -- do not edit."
  printf '// Re-exports the pinned opencode-pty build so PTY tools\n'
  printf '// (pty_spawn/pty_write/pty_read/pty_list/pty_kill) are available.\n'
  printf '// To manage the pin, edit dev-setup/lib/opencode-pty/package.json.\n'
  printf 'export { PTYPlugin } from "%s";\n' "$dist"
} > "$tmp_shim"
mv -f "$tmp_shim" "$shim"
log_info "opencode-pty: wired via $shim"
log_info "opencode-pty: restart opencode to pick up the plugin (config loads at startup)"
