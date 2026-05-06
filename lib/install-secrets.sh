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

# Default workspace ID for this personal setup. The workspace ID is not a
# credential; it's an opaque project identifier (think GitHub org login).
# Without an auth token from `infisical login` it grants nothing. Hardcoding
# it lets us skip the interactive `infisical init` flow entirely on fresh
# machines. Override with INFISICAL_WORKSPACE_ID for forks / other tenants.
INFISICAL_WORKSPACE_ID="${INFISICAL_WORKSPACE_ID:-38eb9fac-447b-46a9-9ed2-bdfb32e0e8f0}"

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

# Materialize ~/.config/infisical/.infisical.json ourselves instead of
# shelling out to `infisical init`, which is purely interactive (no flags,
# no env-var override) and would block in a `curl | bash` install. The file
# format is trivial — only `workspaceId` matters for `secrets get`.
infisical_dir="$HOME/.config/infisical"
infisical_project="$infisical_dir/.infisical.json"
mkdir -p "$infisical_dir"
if [[ ! -f "$infisical_project" ]]; then
  log_info "secrets: writing $infisical_project (workspace $INFISICAL_WORKSPACE_ID)"
  cat > "$infisical_project" <<EOF
{
    "workspaceId": "$INFISICAL_WORKSPACE_ID",
    "defaultEnvironment": "",
    "gitBranchToEnvironmentMapping": null
}
EOF
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
