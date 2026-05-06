# shellcheck shell=bash
# Sourced by interactive zsh/bash via a one-time block in ~/.zshrc / ~/.bashrc
# (installed by lib/install-shell-env.sh).
#
# Single source of truth for environment variables and PATH entries that
# dev-setup modules rely on. Edit this file directly when adding a new
# module that needs an env var; remove the corresponding lines when retiring
# the module. No stale-vars problem because there's exactly one file.
#
# Anything sourced from here runs in every interactive login shell, so keep
# it cheap and side-effect-free: no command lookups, no network, no prompts.

# --- npm-global PATH (install-todoist-cli.sh, install-kagi-cli.sh) ---
# Prepend ~/.npm-global/bin so globally-installed npm packages (td, kagi-cli)
# are on PATH without sudo or fiddling with the system npm prefix.
case ":$PATH:" in
  *":$HOME/.npm-global/bin:"*) ;;
  *) export PATH="$HOME/.npm-global/bin:$PATH" ;;
esac

# --- Kagi session token (install-secrets.sh + install-kagi-cli.sh) ---
# The kagi CLI reads $KAGI_SESSION_TOKEN; the token file is materialized from
# Infisical by install-secrets.sh. Silent no-op if the file isn't there yet
# (e.g. fresh machine before secrets bootstrap finishes).
if [[ -r "$HOME/.config/kagi/session-token" ]]; then
  KAGI_SESSION_TOKEN="$(< "$HOME/.config/kagi/session-token")"
  export KAGI_SESSION_TOKEN
fi
