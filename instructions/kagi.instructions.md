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

`KAGI_API_TOKEN` is **not** set on these machines, so `fastgpt`,
`enrich`, and the public (non-`--subscriber`) `summarize` will fail.
Use `--subscriber` for `summarize`.

Always use `--format compact` and pipe through `jq` to keep tool output
small.

| Need | Command |
|---|---|
| Search results | `kagi search "<q>" --format compact \| jq '.data[:5][]\|{title,url,snippet}'` |
| Quick factual answer | `kagi quick "<q>" --format compact \| jq -r '.message.markdown'` |
| Summarize URL | `kagi summarize --url <URL> --subscriber --summary-type {summary\|keypoints\|eli5}` |
| Ask about a page | `kagi ask-page --url <URL> "<q>"` |
| News | `kagi news --format compact` |

`search` filters: `--time {day,week,month,year}`, `--from-date YYYY-MM-DD`,
`--region`, `--order recency`, `--snap reddit`.
