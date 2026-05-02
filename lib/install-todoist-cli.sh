# shellcheck shell=bash
# Install or upgrade the Doist Todoist CLI (`td`) and its agent skill.
# Sourced by install.sh after lib/common.sh.

ensure_system_package node nodejs nodejs nodejs
ensure_system_package npm npm npm node

# npm prefix for global installs without sudo. Use ~/.npm-global if the user
# hasn't already configured a writable prefix.
npm_prefix="$(npm config get prefix 2>/dev/null || true)"
if [[ ! -w "$npm_prefix" ]]; then
  npm_prefix="$HOME/.npm-global"
  log_info "configuring npm to install global packages into $npm_prefix"
  mkdir -p "$npm_prefix"
  npm config set prefix "$npm_prefix"
fi

# Make sure $npm_prefix/bin is on PATH for this script run...
case ":$PATH:" in
  *":$npm_prefix/bin:"*) ;;
  *) export PATH="$npm_prefix/bin:$PATH" ;;
esac

# ...and persist it for future shells via a sentinel-marked block in the
# user's shell rc files. Idempotent: matches by sentinel before appending.
sentinel='# >>> dev-setup: npm-global PATH >>>'
end_sentinel='# <<< dev-setup: npm-global PATH <<<'
path_block=$(cat <<EOF
$sentinel
case ":\$PATH:" in
  *":$npm_prefix/bin:"*) ;;
  *) export PATH="$npm_prefix/bin:\$PATH" ;;
esac
$end_sentinel
EOF
)

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [[ -f "$rc" ]] || continue
  if grep -qF "$sentinel" "$rc"; then
    log_info "PATH block already present in $rc"
  else
    log_info "appending npm-global PATH block to $rc"
    printf '\n%s\n' "$path_block" >> "$rc"
  fi
done

if has_command td; then
  log_info "upgrading @doist/todoist-cli"
else
  log_info "installing @doist/todoist-cli"
fi
npm install -g --silent @doist/todoist-cli >/dev/null

# Resolve the binary even if the npm prefix isn't on PATH yet in this shell.
td_bin="$(command -v td || true)"
if [[ -z "$td_bin" && -x "$npm_prefix/bin/td" ]]; then
  td_bin="$npm_prefix/bin/td"
fi

if [[ -z "$td_bin" ]]; then
  log_error "td CLI installed but not found on PATH"
  return 1
fi

log_info "td CLI: $("$td_bin" --version 2>/dev/null || echo 'installed')"

# Install the universal agent skill (~/.agents/skills/todoist-cli/SKILL.md).
# This is the Doist-maintained command reference; our Copilot instructions
# point agents at it for command syntax. `td skill install` is idempotent
# (re-runs are safe; auto-updates with future `td` upgrades).
log_info "installing universal agent skill"
"$td_bin" skill install universal >/dev/null
