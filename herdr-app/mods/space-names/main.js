// Space names: names each space after what its agent is building, from the agent's terminal
// title (Claude Code sets it to a short summary of the task). A space someone named by hand is
// left alone; renaming it to "" (Herdr's own name again) hands it back to auto names.
// Lives in the status bar as a small switch: click to pause or resume.
import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { agents, spaces, theme, run, shared, setShared, props } from "herdr";

const KEY = "space-names"; // { enabled, auto: { <space id>: <name we set> }, manual: { <space id>: true } }
const EVERY = 3000; // how often to look
const SETTLE = 12000; // a title must stay the same this long before it becomes a name
const QUIET = 6000; // after a rename, give spaces() time to catch up before judging that space
const MAX = 40; // longest name

const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").replace(/\s+/g, " ").trim();

// A title that says something: not the program's own name, a path, user@host or a bare shell.
function telling(a) {
  const t = clean(a.title);
  if (t.length < 3) return null;
  const prog = (a.program?.name ?? "").toLowerCase();
  const low = t.toLowerCase();
  if (low === prog || low === a.program?.key || low === (a.app ?? "").toLowerCase()) return null;
  if (/^(claude( code)?|codex|zsh|bash|fish|sh|shell)$/i.test(t)) return null;
  if (/^[~/]|^[A-Za-z]:\\/.test(t) || t.includes("@")) return null;
  return t.length > MAX ? t.slice(0, MAX - 1).trimEnd() + "…" : t;
}

const RANK = { blocked: 0, working: 1, done: 2, idle: 3 };

// The space's lead agent: the one in its earliest tab, busiest first, with a telling title.
function candidate(space, list) {
  const mine = list
    .filter((a) => a.space === space.id)
    .sort((x, y) => x.tab_index - y.tab_index || (RANK[x.status] ?? 9) - (RANK[y.status] ?? 9));
  for (const a of mine) {
    const name = telling(a);
    if (name) return name;
  }
  return null;
}

function state() {
  const s = shared(KEY);
  return {
    enabled: s?.enabled !== false,
    auto: { ...(s?.auto ?? {}) },
    manual: { ...(s?.manual ?? {}) },
  };
}

export default class SpaceNames extends View {
  init(_p, cx) {
    this.seen = {}; // space id -> { name, since }: a title waiting to settle
    this.renamedAt = {}; // space id -> when we last renamed it
    cx.timer.every(EVERY, () => this.tick());
    this.tick();
  }

  tick() {
    const st = state();
    if (!st.enabled) return;
    const now = Date.now();
    const list = agents();
    const all = spaces();
    let dirty = false;

    for (const s of all) {
      if (now - (this.renamedAt[s.id] ?? 0) < QUIET) continue;
      if (!s.named) {
        // Never named, or renamed to "" by the person: ours to name.
        if (st.manual[s.id] || st.auto[s.id]) { delete st.manual[s.id]; delete st.auto[s.id]; dirty = true; }
      } else if (st.auto[s.id] !== s.name) {
        // Named by someone else (the person, a worktree): theirs from now on.
        if (!st.manual[s.id]) { st.manual[s.id] = true; delete st.auto[s.id]; dirty = true; }
        continue;
      }
      if (st.manual[s.id]) continue;

      const name = candidate(s, list);
      if (!name || name === s.name) { delete this.seen[s.id]; continue; }
      const w = this.seen[s.id];
      if (!w || w.name !== name) { this.seen[s.id] = { name, since: now }; continue; }
      if (now - w.since < SETTLE) continue;

      run("space.rename", { id: s.id, name });
      st.auto[s.id] = name;
      this.renamedAt[s.id] = now;
      delete this.seen[s.id];
      dirty = true;
    }

    // Forget spaces that are gone.
    const live = new Set(all.map((s) => s.id));
    for (const m of [st.auto, st.manual]) for (const id of Object.keys(m)) if (!live.has(id)) { delete m[id]; dirty = true; }
    if (dirty) setShared(KEY, st);
  }

  render() {
    const t = theme();
    const st = state();
    const count = Object.keys(st.auto).length;
    const edge = props()?.border;
    const tip = st.enabled
      ? `Naming spaces after what their agent is working on (${count} named now).\n` +
        `Rename a space yourself to keep your name; rename it to nothing to hand it back.\nClick to pause.`
      : "Auto space names paused. Click to resume.";
    return h_flex()
      .id("space-names")
      .size_full()
      .px(10)
      .gap(6)
      .items_center()
      .justify_center()
      .bg(t.chrome)
      .text_size(11.8)
      .cursor_pointer()
      .when(edge === "top", (el) => el.border_t(1).border_color(t.border))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click(() => {
        setShared(KEY, { ...st, enabled: !st.enabled });
        if (!st.enabled) this.seen = {};
      })
      .tooltip(tip)
      .child(div().flex_none().size(6).rounded_full().bg(st.enabled ? t.working : t.dim))
      .child(div().text_color(st.enabled ? t.muted : t.dim).child(st.enabled ? "Auto names" : "Names paused"));
  }
}
