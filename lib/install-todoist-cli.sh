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
  case ":$PATH:" in
    *":$npm_prefix/bin:"*) ;;
    *)
      log_warn "add '$npm_prefix/bin' to your PATH (e.g. in ~/.zshrc.local)"
      export PATH="$npm_prefix/bin:$PATH"
      ;;
  esac
fi

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
