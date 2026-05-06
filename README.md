# dev-setup

Personal bootstrap for AI tooling and conventions across machines.

## Install

On any new machine or container:

```sh
curl -fsSL https://setup.lasath.dev | bash
```

This will:

1. Clone this repo to `~/.local/share/dev-setup`.
2. Add a sentinel-marked block to `~/.zshrc` / `~/.bashrc` that sources
   `shell/env.sh` from the clone. Single source of truth for env vars
   and PATH entries that the modules below depend on (npm-global PATH,
   `KAGI_SESSION_TOKEN`, etc.) — edit `shell/env.sh` to add new ones.
3. Fetch long-lived credentials from [Infisical](https://infisical.com)
   and write them to the right `~/.config/<tool>/` paths (mode 0600).
   Requires `infisical login` beforehand — see [Prerequisites](#prerequisites).
   Writes `~/.config/infisical/.infisical.json` itself (no interactive
   `init` needed).
4. Install the [Doist `td` CLI](https://github.com/Doist/todoist-cli) via
   `npm i -g @doist/todoist-cli` and the universal agent skill at
   `~/.agents/skills/todoist-cli/SKILL.md`. Auth is already in place from
   step 3.
5. Install the [`kagi` CLI](https://github.com/Microck/kagi-cli) via
   `npm i -g kagi-cli`. Auth (`KAGI_SESSION_TOKEN`) is exported by
   `shell/env.sh` from the file step 3 materialized.
6. Install [opencode](https://opencode.ai) via the system package manager
   (or the official installer on distros without a package). Required by
   VoxPilot at runtime.
7. Download and install the latest [VoxPilot](https://github.com/shocklateboy92/voxpilot)
   release tarball to `~/.local/share/voxpilot/` (overridable via `VOXPILOT_ROOT`),
   symlink the systemd unit into `~/.config/systemd/user/`, daemon-reload,
   enable, and start. Linux-only; skipped on macOS.
8. Distribute `instructions/*.instructions.md` to every installed agent
   runtime: symlinked into VS Code prompts dirs for Copilot, and
   concatenated (with frontmatter stripped) into
   `~/.config/opencode/AGENTS.md` for [opencode](https://opencode.ai).
   Skills installed at `~/.agents/skills/*/` are symlinked into
   `~/.config/opencode/skills/` so opencode discovers them too.

The script is idempotent. Re-running it refreshes secrets, upgrades
packages, and refreshes the symlinks.

## Prerequisites

The secrets module requires Infisical to be authenticated on the new
machine before running `install.sh`:

```sh
# 1. Install the CLI (install.sh does this for you on Arch/Debian/macOS;
#    only needed if its package-manager autodetection misses)
npm i -g @infisical/cli
# or: yay -S infisical-bin   (Arch)
# or: see https://infisical.com/docs/cli/overview

# 2. Browser auth (one-time per machine)
infisical login
```

That's it. `install.sh` writes `~/.config/infisical/.infisical.json`
itself with a hardcoded `workspaceId` (an opaque, non-secret project
identifier) — no interactive `infisical init` needed. Override the
default with `INFISICAL_WORKSPACE_ID=...` if you've forked this repo.

## Update

Instructions update everywhere automatically — they are symlinks into the
clone:

```sh
cd ~/.local/share/dev-setup && git pull
```

To upgrade the CLI or pick up changes to the install scripts themselves,
re-run `./install.sh` from the clone (or pipe the curl command again).

## Layout

```
dev-setup/
├── install.sh                       # entry point (curl-piped)
├── shell/
│   └── env.sh                       # env vars + PATH for interactive shells
├── lib/
│   ├── common.sh                    # logging + OS helpers
│   ├── install-shell-env.sh         # rcfile sentinel block sourcing shell/env.sh
│   ├── install-secrets.sh           # fetch credentials from Infisical
│   ├── install-todoist-cli.sh       # td + universal agent skill
│   ├── install-kagi-cli.sh          # kagi (web search for agents)
│   ├── install-opencode.sh          # opencode binary (pacman/brew/installer)
│   ├── install-voxpilot.sh          # download tarball + systemd --user unit
│   └── install-instructions.sh      # VS Code prompts symlinks +
│                                    # opencode AGENTS.md / skills
└── instructions/
    ├── todoist.instructions.md      # conventions for the td CLI
    └── kagi.instructions.md         # conventions for the kagi CLI
```

## How the Todoist integration is split

Two separate pieces of agent guidance live in two places:

- **Command reference** — Doist maintains
  `~/.agents/skills/todoist-cli/SKILL.md` (installed via
  `td skill install universal`). CI-enforced sync with the actual `td`
  source. We do not duplicate it.
- **Personal conventions** — when to create tasks, the `AI Projects`
  parent, status mapping. Lives in `instructions/todoist.instructions.md`,
  symlinked into VS Code's prompts dir so Copilot loads it.

The conventions file points agents at the SKILL.md for command syntax.

## Adding a new tool later

1. Drop a new `lib/install-<thing>.sh` (sourced; may use `log_info` /
   `ensure_system_package` from `lib/common.sh`).
2. Append it to the `modules=(...)` list in `install.sh`.
3. If the tool needs an env var or to extend `PATH` in interactive
   shells, add lines to `shell/env.sh` directly (single tracked file,
   no per-module rcfile mutations).
4. If the tool comes with agent guidance, add an
   `instructions/<thing>.instructions.md` file — `install-instructions.sh`
   will symlink it into VS Code prompts dirs and fold it into the
   generated `~/.config/opencode/AGENTS.md` automatically.

## Adding a new secret

1. Store it in Infisical (run from any directory; `--projectId` is read
   from `~/.config/infisical/.infisical.json`):

   ```sh
   cd ~/.config/infisical
   infisical secrets folders create --env=prod --name=<tool> --path=/
   infisical secrets set --env=prod --path=/<tool> \
     "<KEY>=@/path/to/local/config-file"
   ```

2. Append a row to the `SECRETS=(...)` array in
   `lib/install-secrets.sh`:

   ```
   "/<tool>|<KEY>|$HOME/.config/<tool>/<file>|0600"
   ```

3. Re-run `install.sh` on every machine that needs it.
