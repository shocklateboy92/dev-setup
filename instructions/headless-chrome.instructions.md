---
applyTo: '**'
---

# Headless Chrome (CDP) for scraping

When `kagi` snippets aren't enough and `fetch_webpage` gets 403'd (eBay,
Cloudflare-fronted sites, JS-rendered SPAs), connect to the existing
`wl-chrome` service at `https://cdp.apps.lasath.com` (CDP, fronted by
Caddy; `cdp.staging.lasath.com` is the staging host). Real desktop
Chromium with the user's logged-in session, so login walls and most bot
checks pass. LAN-only and unauthenticated, reachable from any host
running these instructions.

Use Playwright (`from playwright.sync_api import sync_playwright`,
`p.chromium.connect_over_cdp("https://cdp.apps.lasath.com")`); don't
launch a new browser. Reuse `browser.contexts[0]` to inherit the
logged-in session — `browser.new_context()` gives you a fresh,
logged-out profile. (Caddy rewrites the `Host` header Chrome demands and
rewrites `webSocketDebuggerUrl` to `wss://cdp.apps.lasath.com`, so
`connect_over_cdp` dials back through the proxy transparently — no
manual endpoint fixup needed.)

**If you hit a captcha or login challenge, stop and tell the user** —
they can solve it interactively in the wl-chrome desktop UI (KasmVNC) at
`https://chrome.apps.lasath.com`. Don't burn turns trying to bypass it.

If `python-playwright` (or equivalent) isn't installed, install it via
the host's native package manager rather than `pip`.
