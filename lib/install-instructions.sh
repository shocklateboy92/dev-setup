# shellcheck shell=bash
# Symlink instructions/*.md into VS Code prompt directories.
# Sourced by install.sh.

instructions_src="$DEV_SETUP_ROOT/instructions"

if [[ ! -d "$instructions_src" ]]; then
  log_warn "no instructions directory at $instructions_src; skipping"
  return 0
fi

# Candidate prompts directories. We install into every one that exists *or*
# whose parent (User/) exists — which catches both desktop and Remote-SSH server.
candidate_dirs=(
  "$HOME/.config/Code/User/prompts"
  "$HOME/.vscode-server/data/User/prompts"
  "$HOME/.config/Code - Insiders/User/prompts"
  "$HOME/.vscode-server-insiders/data/User/prompts"
)

linked_any=0
for dir in "${candidate_dirs[@]}"; do
  parent="$(dirname "$dir")"
  if [[ ! -d "$parent" ]]; then
    continue
  fi
  mkdir -p "$dir"
  for src in "$instructions_src"/*.instructions.md; do
    [[ -e "$src" ]] || continue
    name="$(basename "$src")"
    target="$dir/$name"
    if [[ -L "$target" && "$(readlink "$target")" == "$src" ]]; then
      log_info "up to date: $target"
    elif [[ -e "$target" && ! -L "$target" ]]; then
      log_warn "skipping $target (exists and is not a symlink; remove it manually to let dev-setup manage it)"
    else
      ln -sfn "$src" "$target"
      log_info "linked $target -> $src"
      linked_any=1
    fi
  done
done

# OpenCode global rules: symlink the Todoist instructions to ~/.config/opencode/AGENTS.md.
# OpenCode reads AGENTS.md as always-on rules, the equivalent of VS Code's
# *.instructions.md prompt files. The skill itself (~/.agents/skills/todoist-cli)
# is already auto-discovered by OpenCode and needs no install step here.
opencode_dir="$HOME/.config/opencode"
opencode_src="$instructions_src/todoist.instructions.md"
if [[ -d "$opencode_dir" && -f "$opencode_src" ]]; then
  target="$opencode_dir/AGENTS.md"
  if [[ -L "$target" && "$(readlink "$target")" == "$opencode_src" ]]; then
    log_info "up to date: $target"
  elif [[ -e "$target" && ! -L "$target" ]]; then
    log_warn "skipping $target (exists and is not a symlink; remove it manually to let dev-setup manage it)"
  else
    ln -sfn "$opencode_src" "$target"
    log_info "linked $target -> $opencode_src"
    linked_any=1
  fi
fi

if [[ $linked_any -eq 0 ]]; then
  log_info "no new instruction symlinks created"
fi
