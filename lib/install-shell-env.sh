# shellcheck shell=bash
# Install the one-time sentinel block in ~/.zshrc / ~/.bashrc that sources
# shell/env.sh from the dev-setup clone.
#
# Sourced by install.sh BEFORE other modules so that when subsequent modules
# rely on env vars (e.g. PATH including ~/.npm-global/bin) being exported in
# future shells, the plumbing is already in place.
#
# Idempotent. Safe to re-run.

env_script="$DEV_SETUP_ROOT/shell/env.sh"

if [[ ! -f "$env_script" ]]; then
  log_error "shell-env: $env_script does not exist"
  return 1
fi

sentinel='# >>> dev-setup: shell env >>>'
end_sentinel='# <<< dev-setup: shell env <<<'

block=$(cat <<EOF
$sentinel
# Sourced from $DEV_SETUP_ROOT (managed by dev-setup; do not edit by hand).
# To change env vars, edit shell/env.sh in the dev-setup repo.
[[ -r "$env_script" ]] && . "$env_script"
$end_sentinel
EOF
)

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [[ -f "$rc" ]] || continue
  if grep -qF "$sentinel" "$rc"; then
    log_info "shell-env: block already present in $rc"
  else
    log_info "shell-env: appending block to $rc"
    printf '\n%s\n' "$block" >> "$rc"
  fi
done

# One-time cleanup: an earlier version of dev-setup wrote a separate
# `# >>> dev-setup: npm-global PATH >>>` block from install-todoist-cli.sh.
# That logic now lives in shell/env.sh; remove the legacy block so PATH
# isn't double-prepended and so we don't have two competing sources of
# truth. Safe to delete this loop in a few months once all machines have
# been re-provisioned at least once.
legacy_start='# >>> dev-setup: npm-global PATH >>>'
legacy_end='# <<< dev-setup: npm-global PATH <<<'
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [[ -f "$rc" ]] || continue
  if grep -qF "$legacy_start" "$rc"; then
    log_info "shell-env: removing legacy npm-global PATH block from $rc"
    # sed -i is GNU/BSD-portable enough for our targets (Linux + macOS).
    # Use a temp file to keep the edit atomic and avoid in-place quirks.
    tmp="$(mktemp)"
    awk -v s="$legacy_start" -v e="$legacy_end" '
      $0 == s { skip = 1; next }
      $0 == e { skip = 0; next }
      !skip
    ' "$rc" > "$tmp"
    mv "$tmp" "$rc"
  fi
done

# Source it in this shell too, so the modules that run after us this turn
# can rely on the env (npm-global PATH in particular).
# shellcheck disable=SC1090
. "$env_script"
