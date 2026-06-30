---
applyTo: '**'
---

# Web search via the `kagi` CLI

Combine training data with `kagi` web search — your prior is stale (cutoff
is well past), search is biased toward popular sites. Both have blind
spots.

- **Search** for: current versions, releases, recent CVEs, unfamiliar
  errors, fast-moving ecosystems, anything "latest".
- **Don't search** for: stable language semantics, workspace-local
  answers, pure reasoning.
- **Niche/long-tail:** LLMs hallucinate confidently in gaps; search is
  honest about zero results. Use the LLM to extract precise terminology,
  then verify with `kagi` using those exact terms.
- Cite the URL when a claim is non-obvious or contested.

## CLI usage

`kagi` is on PATH (installed by dev-setup). Auth: `KAGI_SESSION_TOKEN`
exported from the shell rc files (sourced via dev-setup/shell/env.sh,
backed by `~/.config/kagi/session-token` from Infisical) — works in
every interactive shell, no per-project `.kagi.toml`.

Use `kagi` only for raw retrieval — `search` and `news`. Avoid every
LLM-backed subcommand (`quick`, `summarize`, `ask-page`, `fastgpt`,
`enrich`): they hallucinate. (`KAGI_API_TOKEN` is also unset here, so the
API-keyed ones fail anyway.)

Always use `--format compact` and pipe through `jq` to keep tool output
small.

| Need | Command |
|---|---|
| Search results | `kagi search "<q>" --format compact \| jq '.data[:5][]\|{title,url,snippet}'` |
| News | `kagi news --format compact` |

`search` filters: `--time {day,week,month,year}`, `--from-date YYYY-MM-DD`,
`--region`, `--order recency`, `--snap reddit`.

To answer a question from the web, reason over raw `kagi search` snippets
yourself, or kick off a subagent to search, read pages, and return a cited
answer.
