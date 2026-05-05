#!/usr/bin/env bash
# dev-setup entry point.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/shocklateboy92/dev-setup/main/install.sh | bash
#
# Idempotent. Safe to re-run.

set -euo pipefail

REPO_URL="${DEV_SETUP_REPO_URL:-https://github.com/shocklateboy92/dev-setup.git}"
REPO_BRANCH="${DEV_SETUP_REPO_BRANCH:-main}"
INSTALL_ROOT="${DEV_SETUP_ROOT:-$HOME/.local/share/dev-setup}"

# When fetched via curl, $0 is "bash" or a fd. When run from a clone, $0 is a real path.
script_path="${BASH_SOURCE[0]:-}"
running_from_clone=0
if [[ -n "$script_path" && -f "$script_path" ]]; then
  script_dir="$(cd "$(dirname "$script_path")" && pwd)"
  if [[ -d "$script_dir/.git" || -d "$script_dir/../.git" ]]; then
    running_from_clone=1
    INSTALL_ROOT="$(cd "$script_dir" && git rev-parse --show-toplevel)"
  fi
fi

if [[ $running_from_clone -eq 0 ]]; then
  # Bootstrap path: ensure git is available, clone or update, re-exec from clone.
  if ! command -v git >/dev/null 2>&1; then
    echo "dev-setup: git is required to bootstrap. Install git first." >&2
    exit 1
  fi
  mkdir -p "$(dirname "$INSTALL_ROOT")"
  if [[ -d "$INSTALL_ROOT/.git" ]]; then
    echo "dev-setup: updating existing clone at $INSTALL_ROOT"
    git -C "$INSTALL_ROOT" fetch --quiet origin "$REPO_BRANCH"
    git -C "$INSTALL_ROOT" checkout --quiet "$REPO_BRANCH"
    git -C "$INSTALL_ROOT" pull --ff-only --quiet
  else
    echo "dev-setup: cloning $REPO_URL into $INSTALL_ROOT"
    git clone --quiet --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_ROOT"
  fi
  echo "dev-setup: re-executing from clone"
  exec bash "$INSTALL_ROOT/install.sh" "$@"
fi

export DEV_SETUP_ROOT="$INSTALL_ROOT"

# shellcheck source=lib/common.sh
source "$INSTALL_ROOT/lib/common.sh"

log_info "dev-setup root: $INSTALL_ROOT"

# Order matters: CLI before auth (auth uses the CLI), instructions last.
modules=(
  "lib/install-secrets.sh"
  "lib/install-todoist-cli.sh"
  "lib/install-opencode.sh"
  "lib/install-voxpilot.sh"
  "lib/install-instructions.sh"
)

for module in "${modules[@]}"; do
  module_path="$INSTALL_ROOT/$module"
  if [[ ! -f "$module_path" ]]; then
    log_warn "missing module: $module (skipping)"
    continue
  fi
  log_info "running $module"
  # shellcheck disable=SC1090
  source "$module_path"
done

log_info "done."
log_info "if 'td' isn't found, start a new shell or 'source ~/.zshrc' / 'source ~/.bashrc'."
log_info "to authenticate Todoist, run: td auth login"
log_info "to update later: cd $INSTALL_ROOT && git pull && ./install.sh"
