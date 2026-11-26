---
name: blocked-fetch
description: Get a web page that answered 403, 429, 503, a captcha, "Just a moment", "Vercel Security Checkpoint", "Access Denied", an empty JS shell or an IP block (Cloudflare, Vercel, Akamai, PerimeterX, DataDome). Use whenever WebFetch, curl or a scraper gets blocked or bot-checked, before saying a page can't be read.
---

# Blocked fetch

A block is a reason to escalate, not to give up. Go down the ladder until a step returns the real page, and
only then report it unreadable, listing every step tried. HTTP 200 is not success: check that the body is the
page you wanted, not a challenge or an empty shell.

## Ladder

1. **One command does the automatic part of the ladder:**

   ```bash
   F=~/.claude/skills/blocked-fetch/fetch.py
   uv run -q $F 'URL' --grep 'price|rating'   # only the text around each match: cheapest, use when you know what you need
   uv run -q $F 'URL'                         # title, file paths and the first 6000 chars of text (--max N for more)
   uv run -q $F 'URL' --html                  # raw HTML to stdout
   ```

   Steps, stopping at the first real page: curl_cffi with `chrome131`, `chrome`, `safari` fingerprints (about 1 s
   each); the Mac's Google Chrome headless (solves JavaScript challenges, trackers blocked); Apify web-fetch (other
   IP plus Apify's unblocker; token from `APIFY_TOKEN` or Keychain `marketplace-mcp-apify`; costs a little, skip with
   `--no-apify`). It remembers per site which step worked (`~/.cache/blocked-fetch/domains.json`) and starts there
   next time. The full page is saved as `.html` and the data embedded in it (JSON-LD, `__NEXT_DATA__`, other JSON
   script tags: often the real content on JS sites) as `.json`; grep or read those files rather than printing whole
   pages. stderr says which step worked; exit 2 means still blocked. Tested 2026-11-17: Kalshi (Vercel), Zillow
   (PerimeterX), Amazon.com (Akamai), flysas.com at step one; G2 (DataDome) only via Apify.

   For an API or POST, use curl_cffi directly:
   `uv run -q --with curl_cffi python -I -c "from curl_cffi import requests as r; x=r.post('URL', json={...}, impersonate='chrome131'); print(x.status_code, x.text[:2000])"`.

2. **Another copy of the page:** the site's API, RSS, sitemap or `gh api` for GitHub; the Wayback Machine
   (`https://web.archive.org/web/2026/URL`, or `curl 'https://archive.org/wayback/available?url=URL'`). Say it's
   a dated copy.

3. **Codex** (the `codex:codex-rescue` agent) as a last try, then stop and say what each step returned.

## Rules

- Public pages for reading only: never get around a login, paywall or a site's terms, and no captcha-solving
  services. Keep it to a few requests, not bulk scraping.
- This Mac is company-managed with Microsoft Defender, which pops up "blocked by your IT admin" when a page calls a
  tracker IT blocks (e.g. pdscrb.com, a podcast-ad pixel). It scares the user, so never load pages in a full browser
  outside `fetch.py` (which blocks trackers), and don't download stealth browsers (Camoufox, patchright, nodriver).
- A repo that scrapes in code already has its own version: marketplace-mcp `fetch.py` (curl_cffi per site,
  back-off, Akamai solver) and `browser.py` (headless Chrome), bolig `lib/http.ts` and trip-planner (impit,
  then the home relay, then Apify residential proxy). Reuse those patterns there.
- Brief subagents with this skill's name when they will fetch pages.
