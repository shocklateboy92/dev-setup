# dev-setup

Personal bootstrap for AI tooling and conventions across machines.

## Install

On any new machine or container:

```sh
curl -fsSL https://raw.githubusercontent.com/shocklateboy92/dev-setup/main/install.sh | bash
```

This will:

1. Clone this repo to `~/.local/share/dev-setup`.
2. Install the [Doist `td` CLI](https://github.com/Doist/todoist-cli) via
   `npm i -g @doist/todoist-cli` and the universal agent skill at
   `~/.agents/skills/todoist-cli/SKILL.md`.
3. Run `td auth login` (opens a browser; falls back to a code) unless
   already authenticated or `TODOIST_API_TOKEN` is set. Token is stored in
   the OS credential manager (libsecret on Linux).
4. Symlink files from `instructions/` into the local VS Code prompts
   directory (both desktop and Remote-SSH server paths, if present).

The script is idempotent. Re-running it upgrades the npm package, the
agent skill, and refreshes the symlinks.

### Headless / CI

If there is no TTY, the auth step is skipped — set `TODOIST_API_TOKEN` in
the environment instead, or run `td auth login` interactively later.

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
├── lib/
│   ├── common.sh                    # logging + OS helpers
│   ├── install-todoist-cli.sh       # td + universal agent skill
│   ├── setup-todoist-auth.sh        # td auth login (idempotent)
│   └── install-instructions.sh      # symlinks into VS Code prompts
└── instructions/
    └── todoist.instructions.md      # Copilot conventions for Todoist
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
3. If the tool comes with agent guidance, add an
   `instructions/<thing>.instructions.md` file —
   `install-instructions.sh` will symlink any `*.instructions.md`
   automatically.
