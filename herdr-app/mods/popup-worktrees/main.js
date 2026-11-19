// Herdr's old popup keys, for herdr-app: a mod opened with `mod.open` runs a script in a new core
// terminal (in the focused pane's folder, HERDR_FOCUSED_TERMINAL set to the focused terminal) and
// shows it in a centered dialog that closes when the script exits.
import { View, div } from "gpui-kit";
import { focused, hc, home, openOverlay, closeOverlay, props, notify } from "herdr";

const script = "worktrees", args = [], width = 0.8, height = 0.6;

export default class Popup extends View {
  init(_props, cx) {
    const f = focused(), self = props()?.overlay;
    if (!self) return; // not opened by mod.open (e.g. herdr-app check)
    cx.spawn(async () => {
      const r = await hc(["run", "--bg", "--json", "--rm", "--cwd", f?.cwd || home(), "--",
        // Through zsh -lic like herdr-app's own tabs, so PATH from ~/.zshrc (bun, nvm) applies.
        "/bin/zsh", "-lic", 'exec "$@"', "zsh", "env", `HERDR_FOCUSED_TERMINAL=${f?.terminal ?? ""}`, `${home()}/.config/herdr/${script}`, ...args]);
      const t = r.code === 0 && JSON.parse(r.stdout).address;
      if (t) openOverlay({ kind: "dialog", modal: true, layout: { type: "block", content: { terminal: t } }, width, height });
      else notify({ title: `${script} didn't start`, body: r.stderr, level: "error" });
      // Last: closing this overlay cancels this task.
      closeOverlay(self);
    });
  }
  render() { return div(); }
}
