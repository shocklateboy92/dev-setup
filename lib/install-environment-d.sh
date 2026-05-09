# shellcheck shell=bash
# Populate ~/.config/environment.d/ so user systemd services inherit the same
# PATH and credentials that interactive shells get from shell/env.sh.
#
# Why this exists:
#   systemd --user services don't source shell rc files. They start with a
#   minimal env from PAM/the user manager, which means tools that live on a
#   non-default PATH (e.g. ~/.npm-global/bin/td, ~/.bun/bin/opencode) and
#   secrets exported only by shell/env.sh (KAGI_SESSION_TOKEN) are invisible
#   to anything launched by `systemctl --user`.
#
#   ~/.config/environment.d/*.conf is the systemd-native, shell-independent
#   way to extend the user manager's environment. systemd-environment-d-
#   generator(8) reads these on user-manager startup and exports them to all
#   user services. See environment.d(5).
#
# This complements (does not replace) shell/env.sh:
#   - shell/env.sh: sourced by ~/.zshrc / ~/.bashrc, owns interactive shell env.
#   - environment.d: read by systemd --user, owns service env.
#   Both are generated/maintained from this dev-setup repo so they stay in
#   sync; the duplication is irreducible because the two consumers don't
#   share a config format (shell needs scripting, systemd needs KEY=VALUE).
#
# Sourced from install.sh AFTER install-secrets.sh so the kagi token file
# (which we read here) already exists. Idempotent: regenerated wholesale.

env_d_dir="$HOME/.config/environment.d"
env_d_file="$env_d_dir/10-dev-setup.conf"

mkdir -p "$env_d_dir"

# Build the file content. environment.d supports ${VAR} expansion, so
# PATH=...:${PATH} properly appends to whatever the user manager already
# has, rather than clobbering it.
{
  echo "# Managed by dev-setup/lib/install-environment-d.sh -- do not edit by hand."
  echo "# Provides PATH and credentials to user systemd services. See environment.d(5)."
  echo
  # PATH: prepend the same directories shell/env.sh prepends, plus ~/.bun/bin
  # (used by opencode) which voxpilot's unit currently sets in its own
  # Environment=PATH= line. Centralizing here means future services don't
  # have to re-list these.
  echo "PATH=\$HOME/.npm-global/bin:\$HOME/.local/bin:\$HOME/.bun/bin:\${PATH}"

  # KAGI_SESSION_TOKEN: only currently-needed env-var-style secret. Same
  # source of truth as shell/env.sh (the file written by install-secrets.sh).
  # Skipped silently if the token file doesn't exist (fresh machine before
  # secrets bootstrap, or non-Infisical install).
  if [[ -r "$HOME/.config/kagi/session-token" ]]; then
    token="$(< "$HOME/.config/kagi/session-token")"
    echo "KAGI_SESSION_TOKEN=$token"
  fi
} > "$env_d_file"

# File contains a secret; lock it down. environment.d files are normally
# world-readable but this one isn't shared and contains a token.
chmod 600 "$env_d_file"
log_info "environment-d: wrote $env_d_file"

# Make the running user manager re-read environment.d. daemon-reexec is the
# documented way; it preserves running services but re-imports the env so
# subsequent service (re)starts see the new vars.
if has_command systemctl; then
  if systemctl --user daemon-reexec 2>/dev/null; then
    log_info "environment-d: reloaded user systemd manager"
  else
    log_warn "environment-d: 'systemctl --user daemon-reexec' failed; new env will apply on next login"
  fi
fi
