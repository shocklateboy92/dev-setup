# shellcheck shell=bash
# Authenticate the td CLI. Idempotent: skips if already authenticated.
# Sourced by install.sh after lib/install-todoist-cli.sh.
#
# `td auth login` opens a browser and stores the token in the OS credential
# manager (libsecret on Linux). On headless machines, set TODOIST_API_TOKEN
# in the environment instead — `td` honours it directly.

if ! has_command td; then
  log_warn "td not on PATH; skipping auth"
  return 0
fi

if td auth status >/dev/null 2>&1; then
  log_info "td already authenticated"
  return 0
fi

if [[ -n "${TODOIST_API_TOKEN:-}" ]]; then
  log_info "TODOIST_API_TOKEN is set; td will use it directly"
  return 0
fi

if [[ ! -t 0 ]]; then
  log_warn "no TTY and no \$TODOIST_API_TOKEN; skipping auth. Run 'td auth login' interactively, or export TODOIST_API_TOKEN."
  return 0
fi

log_info "running 'td auth login' (opens browser; falls back to a code if no browser)"
td auth login || log_warn "td auth login did not complete; re-run later with 'td auth login'"
