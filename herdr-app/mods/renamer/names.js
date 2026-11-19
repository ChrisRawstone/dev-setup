// Native titles only. No transcript reads, subprocesses or naming-model calls.
const HARNESSES = {
  "claude-code": "claude", claude: "claude",
  pi: "pi", omp: "omp", "oh-my-pi": "omp",
  codex: "codex", opencode: "opencode",
};
const SPIN = /^(?:[·✳✽✻✢✶\u2800-\u28ff◐-◓🌑-🌚]\s*)+/u;
const PRIVATE_GLYPH = /^[\uE000-\uF8FF\u{F0000}-\u{FFFFD}\u{100000}-\u{10FFFD}]\s*/u;
const PLACEHOLDER = /^(?:untitled|new (?:session|conversation)|session|ready|thinking|working|idle|waiting|done|blocked|error|claude(?: code)?|codex|opencode|pi|π|omp|oh-my-pi|terminal|zsh|bash|fish|sh|node)(?:\.{1,3}|…)?$/i;

function clean(value) {
  return String(value ?? "")
    .replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "")
    .replace(/[\r\n\t]/g, " ")
    .replace(/[\u0000-\u001f\u007f-\u009f]/g, "")
    .replace(/\s+/g, " ").trim();
}

function basename(path) {
  return String(path ?? "").replace(/\\/g, "/").replace(/\/+$/, "").split("/").pop() ?? "";
}

// Use only the pane's exact terminal. A same-folder session is not evidence.
export function agentSources(panes, terminals, tab) {
  const byAddress = new Map(terminals.map(t => [t.address, t]));
  return panes.filter(p => p.tab === tab && p.terminal).flatMap(pane => {
    const terminal = byAddress.get(pane.terminal);
    if (pane.program?.shell || terminal?.program?.shell) return [];
    // A live shell/another app must not inherit an earlier agent's title.
    const app = pane.app ?? terminal?.report?.app;
    const key = app ?? pane.program?.key ?? terminal?.program?.key;
    const identity = String(key ?? "").toLowerCase();
    const harness = Object.hasOwn(HARNESSES, identity) ? HARNESSES[identity] : null;
    if (!harness || terminal?.state === "finished") return [];
    return [{ ...pane, harness, title: pane.title || terminal?.title || "" }];
  });
}

function piTitle(title, cwd, harness) {
  const branded = /^(?:π|pi)(?=$|[\s:])/iu.test(title);
  if (!branded) return title.replace(SPIN, "");
  const omp = harness === "omp" || /^π\s*[>!:]/u.test(title);
  let text = title.replace(/^(?:π|pi)\s*/iu, "");
  text = text.replace(/^[->!:|\\/]\s*/, "").trim();
  text = text.replace(SPIN, "").replace(/^-\s+/, "").trim();
  const glyph = PRIVATE_GLYPH.test(text);
  text = text.replace(PRIVATE_GLYPH, "");
  if (omp || glyph) text = text.replace(/^[A-Z0-9]{2,6}:\s+/, "");
  // Stock Pi: "π - Session Name - folder". pi-autoname omits the folder.
  const suffix = ` - ${basename(cwd)}`;
  if (basename(cwd) && text.endsWith(suffix)) text = text.slice(0, -suffix.length);
  return text.trim();
}

function titleCase(text) {
  // Keep harness spelling for mixed-case names/acronyms: iOS, OAuth, GitHub, API.
  return text.replace(/\p{L}[\p{L}\p{M}\p{N}'’]*/gu, word =>
    /\p{Lu}/u.test(word) ? word : word.replace(/^\p{L}/u, first => first.toUpperCase()));
}

export function nativeName(source) {
  let title = clean(source.title);
  if (source.harness === "pi" || source.harness === "omp") {
    title = piTitle(title, source.cwd, source.harness);
  } else {
    title = title.replace(SPIN, "");
    if (source.harness === "codex" || source.harness === "opencode") {
      title = title.replace(/^(?:codex|opencode)\s*[:–—-]\s*/i, "").replace(SPIN, "");
    }
  }
  title = clean(title);
  const defaults = [source.cwd, basename(source.cwd), source.terminal, source.program?.name]
    .filter(Boolean).map(value => clean(value).toLowerCase());
  if (!title || !/[\p{L}\p{N}]/u.test(title) || /^\d+$/.test(title)
      || PLACEHOLDER.test(title) || defaults.includes(title.toLowerCase())
      || title.startsWith("/") || title.startsWith("~/") || /^[A-Za-z]:\\/.test(title)) return null;
  const label = titleCase(title);
  const chars = Array.from(label);
  return chars.length > 80 ? chars.slice(0, 79).join("").trimEnd() + "…" : label;
}

// First agent in pane order, sticky while it exists. Focus and status never
// pick a different split. Background children without panes are not candidates.
export function sourceFor(sources, previousTerminal) {
  return sources.find(p => p.terminal === previousTerminal) ?? sources[0] ?? null;
}

export function validOwners(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(Object.entries(value).filter(([, entry]) =>
    entry && typeof entry.name === "string" && typeof entry.terminal === "string"
      && (!entry.pending || (typeof entry.pending.name === "string"
        && typeof entry.pending.from?.name === "string" && typeof entry.pending.from?.named === "boolean"))));
}

export function tabRows(snapshot, saved) {
  const owners = validOwners(saved);
  // A remote rename sends data off this machine; it needs separate approval.
  return snapshot.spaces.filter(s => !s.machine).flatMap(space => space.tabs.map(tab => {
    const owner = owners[tab.id];
    const source = sourceFor(agentSources(snapshot.panes, snapshot.terminals, tab.id), owner?.terminal);
    if (!source) return null;
    const following = !tab.named || owner?.name === tab.name || owner?.pending?.name === tab.name;
    return {
      id: tab.id, space: space.name, name: tab.name, named: tab.named,
      terminal: source.terminal, harness: source.harness,
      candidate: nativeName(source), following,
    };
  }).filter(Boolean));
}
