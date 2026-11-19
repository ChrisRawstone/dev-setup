import { View, div } from "gpui-kit";
import { spaces, panes, terminals, shared, setShared, run, props, closeOverlay } from "herdr";
import { tabRows } from "./names.js";
import { OWNER_KEY, syncNames } from "./controller.js";

function snapshot() {
  return { spaces: spaces(), panes: panes(), terminals: terminals() };
}

function client() {
  return {
    read: snapshot,
    saved: () => shared(OWNER_KEY),
    save: owners => setShared(OWNER_KEY, owners),
    rename: (id, name) => run("tab.rename", { id, name }),
  };
}

export default class Renamer extends View {
  init(_props, cx) {
    this.queued = false;
    this.signature = null;
    this.lastError = "";
    this.overlay = props()?.overlay ?? null;
    // Reject the old window entry point: this mod runs only as layout content.
    if (this.overlay) cx.timer.after(0, () => closeOverlay(this.overlay));
  }

  queue(cx) {
    if (this.queued) return;
    this.queued = true;
    cx.timer.after(0, () => {
      this.queued = false;
      const error = syncNames(client()).join(" ");
      if (error && error !== this.lastError) console.log(`[Renamer] ${error}`);
      this.lastError = error;
    });
  }

  render(cx) {
    if (this.overlay) return div().w(0).h(0);
    const owners = shared(OWNER_KEY);
    const data = snapshot();
    const rows = tabRows(data, owners);
    const tabs = data.spaces.filter(s => !s.machine).flatMap(s => s.tabs)
      .map(({ id, name, named }) => [id, name, named]);
    // Live data drives updates, not a poll or animated raw terminal titles.
    // Non-agent tabs stay in the signature so closed ownership is pruned.
    const signature = JSON.stringify([rows, owners, tabs]);
    if (this.signature !== signature) {
      this.signature = signature;
      this.queue(cx);
    }
    // A non-hidden layout float starts this View. Empty content has no frame,
    // background or footprint. Do not use mod.open: there is no control UI.
    return div().id("renamer").w(0).h(0);
  }
}
