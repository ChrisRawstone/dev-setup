# /// script
# requires-python = ">=3.10"
# dependencies = ["curl_cffi", "playwright"]
# ///
"""Fetch a page past bot checks: curl_cffi fingerprints, then headless system Chrome, then Apify web-fetch.

uv run -q ~/.claude/skills/blocked-fetch/fetch.py URL [--grep REGEX] [--max N] [--html] [--no-browser] [--no-apify]

Saves the page (.html) and its embedded data (.json: JSON-LD, __NEXT_DATA__ and other JSON script tags) under
~/.cache/blocked-fetch/pages and prints their paths, the title and the first --max characters of the text, or with
--grep only the text around each match in the text and data. Remembers per site which step worked and starts there next time.
Exit 0 = real page, 2 = still blocked after every step.
"""
import argparse, hashlib, html, json, os, re, subprocess, sys
from pathlib import Path
from urllib.parse import urlsplit

CACHE = Path.home() / ".cache" / "blocked-fetch"
MEMORY = CACHE / "domains.json"  # host -> step that worked; the hook reads it too
# Challenge/block pages, which often come back as HTTP 200 ("200 is not success").
MARKERS = re.compile(
    r"Just a moment\.\.\.|cf-chl|challenge-platform|Vercel Security Checkpoint|Access to this page has been denied"
    r"|px-captcha|captcha-delivery|datadome|Pardon Our Interruption|Request unsuccessful\. Incapsula"
    r"|<title>Access Denied</title>|Attention Required! \| Cloudflare|Please enable JS and disable any ad blocker"
    r"|bm-verify|/_sec/cp_challenge|Are you a robot|unusual traffic from your computer", re.I)
BLOCK_STATUS = {401, 403, 405, 429, 503}
# Ad/analytics hosts the browser step never loads: they add nothing, and on this company Mac Defender pops up a
# "blocked by your IT admin" alert when a page calls one (e.g. pdscrb.com, Podscribe's ad pixel).
TRACKERS = re.compile(
    r"pdscrb|podscribe|doubleclick|googlesyndication|googletagmanager|google-analytics|googleadservices|adservice"
    r"|facebook\.(net|com)/tr|connect\.facebook|analytics|hotjar|segment\.(io|com)|mixpanel|amplitude|clarity\.ms"
    r"|bing\.com/bat|tiktok|snapchat|pinterest|linkedin|twitter|reddit\.com/pixel|criteo|taboola|outbrain|adnxs"
    r"|adsrvr|rubicon|pubmatic|quantserve|scorecardresearch|chartbeat|newrelic|nr-data|sentry|fullstory|optimizely"
    r"|braze|branch\.io|appsflyer|adjust\.com|pixel|beacon|tracking|/collect\b", re.I)
STEPS = ["curl:chrome131", "curl:chrome", "curl:safari", "chrome", "apify"]  # chrome131 beats Amazon's Akamai


def log(msg):
    print(msg, file=sys.stderr)


def blocked(status, body):
    if status in BLOCK_STATUS or status is None:
        return f"HTTP {status}"
    m = MARKERS.search(body[:200_000])
    if m and len(body) < 300_000:  # big real pages can mention e.g. "captcha" in a script
        return f"challenge page ({m.group(0)!r})"
    if len(body) < 1500:
        return f"near-empty body ({len(body)} bytes)"
    return None


def via_curl(url, proxy, fp):
    from curl_cffi import requests
    r = requests.get(url, impersonate=fp, timeout=30, proxy=proxy, allow_redirects=True)
    return r.status_code, r.text


def via_chrome(url, proxy):
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch(channel="chrome", headless=True, args=["--disable-blink-features=AutomationControlled"],
                              proxy={"server": proxy} if proxy else None)
        try:
            pg = b.new_page()
            ua = pg.evaluate("navigator.userAgent").replace("HeadlessChrome", "Chrome")
            pg.close()
            ctx = b.new_context(user_agent=ua, locale="en-US")
            ctx.route("**/*", lambda r: r.abort() if r.request.resource_type in ("image", "media", "font")
                      or TRACKERS.search(r.request.url) else r.continue_())
            pg = ctx.new_page()
            resp = pg.goto(url, wait_until="domcontentloaded", timeout=45000)
            body = ""
            for _ in range(4):  # JS challenges reload the page once solved
                pg.wait_for_timeout(4000)
                body = pg.content()
                if not MARKERS.search(body[:200_000]):
                    break
            status = resp.status if resp else None
            # A challenge answers 403 and then reloads into the real page: judge the final body.
            return (200 if status in BLOCK_STATUS and not blocked(200, body) else status), body
        finally:
            b.close()


def apify_token():
    if os.environ.get("APIFY_TOKEN"):
        return os.environ["APIFY_TOKEN"]
    r = subprocess.run(["security", "find-generic-password", "-s", "marketplace-mcp-apify", "-w"],
                       capture_output=True, text=True)
    return r.stdout.strip() or None


def via_apify(url, _proxy):
    from curl_cffi import requests
    token = apify_token()
    if not token:
        raise RuntimeError("no Apify token (APIFY_TOKEN or Keychain marketplace-mcp-apify)")
    for _ in range(2):  # Apify's unblocker picks a route per call; a bad route gives a near-empty page
        r = requests.get("https://apify--web-fetch.apify.actor/", params={"url": url, "formats": "html"},
                         headers={"Authorization": f"Bearer {token}"}, timeout=120)
        if r.status_code != 200:
            return r.status_code, r.text
        d = r.json()
        status, body = d.get("fetch", {}).get("httpStatusCode"), d.get("html") or ""
        if not blocked(status, body):
            break
    return status, body


def run_step(step, url, proxy):
    if step.startswith("curl:"):
        return via_curl(url, proxy, step[5:])
    return (via_chrome if step == "chrome" else via_apify)(url, proxy)


def embedded_data(body):
    out = {}
    for m in re.finditer(r'(?is)<script[^>]*type=["\']application/(?:ld\+)?json["\'][^>]*>(.*?)</script>', body):
        tag = re.search(r'id=["\']([^"\']+)', m.group(0)[:200])
        try:
            out.setdefault(tag.group(1) if tag else "ld+json", []).append(json.loads(m.group(1)))
        except ValueError:
            pass
    return out


def to_text(body):
    body = re.sub(r"(?is)<(script|style|noscript|svg|template)\b.*?</\1>", " ", body)
    body = re.sub(r"(?s)<[^>]+>", " ", body)
    return re.sub(r"[ \t\r\f\v]*\n\s*", "\n", re.sub(r"[ \t]+", " ", html.unescape(body))).strip()


def load_memory():
    try:
        return json.loads(MEMORY.read_text())
    except (OSError, ValueError):
        return {}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("url")
    ap.add_argument("--grep", help="print only lines of text and embedded data matching this regex (case-insensitive)")
    ap.add_argument("--max", type=int, default=6000, help="characters of text to print (default 6000)")
    ap.add_argument("--html", action="store_true", help="print the raw HTML instead")
    ap.add_argument("--proxy", help="proxy URL for the local steps")
    ap.add_argument("--no-browser", action="store_true", help="skip headless Chrome")
    ap.add_argument("--no-apify", action="store_true", help="skip Apify (it costs a little per call)")
    a = ap.parse_args()

    host = urlsplit(a.url).hostname or ""
    memory = load_memory()
    steps = [s for s in STEPS if not (a.no_browser and s == "chrome") and not (a.no_apify and s == "apify")]
    if memory.get(host) in steps:  # start with what worked last time for this site
        steps.remove(memory[host])
        steps.insert(0, memory[host])

    body = None
    for step in steps:
        try:
            status, text = run_step(step, a.url, a.proxy)
            why = blocked(status, text)
        except Exception as e:
            why = f"{type(e).__name__}: {e}"[:200]
        log(f"[{step}] {why or 'OK'}")
        if not why:
            body = text
            break
    if body is None:
        log("STILL BLOCKED: try an archive copy or the site's API, then Codex (see the blocked-fetch skill).")
        sys.exit(2)

    CACHE.mkdir(parents=True, exist_ok=True)
    memory[host] = step
    MEMORY.write_text(json.dumps(memory, indent=1))
    if a.html:
        print(body)
        return
    base = CACHE / "pages" / f"{host}-{hashlib.sha1(a.url.encode()).hexdigest()[:8]}.x"  # .x: with_suffix swaps it
    base.parent.mkdir(exist_ok=True)
    base.with_suffix(".html").write_text(body)
    data = embedded_data(body)
    text = to_text(body)
    title = re.search(r"(?is)<title[^>]*>(.*?)</title>", body)
    print(f"step: {step} | title: {html.unescape(title.group(1)).strip()[:150] if title else '-'}")
    print(f"html: {base.with_suffix('.html')} ({len(body):,} chars)")
    if data:
        dump = json.dumps(data, indent=1, ensure_ascii=False)
        base.with_suffix(".json").write_text(dump)
        print(f"data: {base.with_suffix('.json')} ({len(dump):,} chars; keys: {', '.join(data)})")
    if a.grep:
        rx = re.compile(a.grep, re.I)
        flat = " ".join(text.split()) + " ||| " + (" ".join(json.dumps(data, ensure_ascii=False).split()) if data else "")
        hits = [flat[max(0, m.start() - 150):m.end() + 250] for m in rx.finditer(flat)]
        print(f"--- {len(hits)} matches (150 chars before, 250 after; first 30) ---")
        print("\n…\n".join(hits[:30]))
    else:
        print(f"--- text ({len(text):,} chars{', cut' if len(text) > a.max else ''}) ---")
        print(text[:a.max])


if __name__ == "__main__":
    main()
