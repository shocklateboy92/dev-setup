---
applyTo: '**'
---

# Headless Chrome (CDP) for scraping

When `kagi` snippets aren't enough and `fetch_webpage` gets 403'd (eBay,
Cloudflare-fronted sites, JS-rendered SPAs), connect to the existing
`wl-chrome` service at `http://192.168.3.70:9223` (CDP). Real desktop
Chromium with the user's logged-in session, so login walls and most bot
checks pass. The address is LAN-reachable from any host running these
instructions.

Use Playwright (`from playwright.sync_api import sync_playwright`,
`p.chromium.connect_over_cdp(...)`); don't launch a new browser. Reuse
`browser.contexts[0]` to inherit the logged-in session —
`browser.new_context()` gives you a fresh, logged-out profile.

**If you hit a captcha or login challenge, stop and tell the user** —
they can solve it interactively in the wl-chrome web UI (port 3001 in
`watchlist/compose.yaml` in the `config` repo, currently commented out
— uncomment if needed). Don't burn turns trying to bypass it.

If `python-playwright` (or equivalent) isn't installed, install it via
the host's native package manager rather than `pip`.
