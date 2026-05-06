# shellcheck shell=bash
# Distribute long-lived service credentials from Infisical onto this machine.
#
# Sourced from install.sh. Idempotent. Always overwrites local files with the
# Infisical version (that's how rotations propagate to other machines).
#
# Hard-fails if `infisical` is missing or the user isn't logged in. This is a
# personal dev-setup; running it without secret bootstrapping is a misconfig.
#
# Adding a new secret:
#   1. Store in Infisical under /<tool>/<KEY>:
#        infisical secrets folders create --env=prod --name=<tool> --path=/
#        infisical secrets set --env=prod --path=/<tool> "<KEY>=@/path/to/file"
#   2. Append a row to the SECRETS array below.

INFISICAL_ENV="${INFISICAL_ENV:-prod}"

ensure_system_package infisical infisical infisical infisical || {
  log_error "secrets: install infisical CLI manually:"
  log_error "  npm i -g @infisical/cli   (or see https://infisical.com/docs/cli/overview)"
  return 1
}

# Verify login state. `user get token` exits non-zero if not authenticated.
if ! infisical user get token >/dev/null 2>&1; then
  log_error "secrets: not logged in to Infisical."
  log_error "  run: infisical login"
  return 1
fi

# Verify project is initialized in $HOME/.config/infisical. `infisical init`
# unconditionally drops .infisical.json in $PWD with no flag to redirect, so
# we cd there first. The init flow itself is interactive (org + project
# picker, no non-interactive mode); run it inline if we have a TTY,
# otherwise tell the user what to do and bail.
infisical_dir="$HOME/.config/infisical"
if [[ ! -f "$infisical_dir/.infisical.json" ]]; then
  if [[ -t 0 && -t 1 ]]; then
    log_info "secrets: no .infisical.json at $infisical_dir; running 'infisical init' interactively"
    mkdir -p "$infisical_dir"
    ( cd "$infisical_dir" && infisical init )
  else
    log_error "secrets: no .infisical.json found at $infisical_dir"
    log_error "  no TTY available for interactive init; run manually:"
    log_error "    mkdir -p $infisical_dir && cd $infisical_dir && infisical init"
    return 1
  fi
fi
if [[ ! -f "$infisical_dir/.infisical.json" ]]; then
  log_error "secrets: init did not produce $infisical_dir/.infisical.json; aborting"
  return 1
fi

# Manifest. One row per file to materialize.
# Format: "<infisical_path>|<infisical_key>|<dest_path>|<mode>"
# - <dest_path> may use $HOME; expanded below.
# - Parent directory is created with mode 0700.
SECRETS=(
  "/todoist|TODOIST_CLI_CONFIG|$HOME/.config/todoist-cli/config.json|0600"
  "/gh|HOSTS_YML|$HOME/.config/gh/hosts.yml|0600"
  "/kagi|KAGI_SESSION_TOKEN|$HOME/.config/kagi/session-token|0600"
)

fetch_secret() {
  local infisical_path="$1" key="$2" dest="$3" mode="$4"
  local dest_dir
  dest_dir="$(dirname "$dest")"

  # Fetch into a temp file in the same dir for atomic rename + correct fs perms.
  mkdir -p "$dest_dir"
  chmod 700 "$dest_dir" 2>/dev/null || true

  local tmp
  tmp="$(mktemp "$dest_dir/.infisical-XXXXXX")"
  # Make sure tmp file isn't world-readable even briefly.
  chmod "$mode" "$tmp"

  if ! ( cd "$infisical_dir" && infisical secrets get "$key" \
            --env="$INFISICAL_ENV" --path="$infisical_path" --plain \
            > "$tmp" ) 2>/dev/null; then
    rm -f "$tmp"
    log_error "secrets: failed to fetch $infisical_path/$key from Infisical"
    return 1
  fi

  # `infisical secrets get --plain` appends a trailing newline. Strip one.
  # Use printf instead of sed -i to avoid platform diffs.
  if [[ -s "$tmp" ]] && [[ "$(tail -c 1 "$tmp" | xxd -p)" == "0a" ]]; then
    truncate -s -1 "$tmp"
  fi

  mv -f "$tmp" "$dest"
  chmod "$mode" "$dest"
  log_info "secrets: wrote $dest"
}

for row in "${SECRETS[@]}"; do
  IFS='|' read -r ipath ikey dest mode <<< "$row"
  fetch_secret "$ipath" "$ikey" "$dest" "$mode" || {
    log_error "secrets: aborting (failed on $ipath/$ikey)"
    return 1
  }
done

log_info "secrets: all credentials materialized from Infisical ($INFISICAL_ENV)"
