import { tabRows, validOwners } from "./names.js";

export const OWNER_KEY = "renamer.titles.v1";

// read() returns current live data, not the render that queued this sync.
// run("tab.rename") may be queued: an intended name is not confirmed ownership.
export function syncNames({ read, saved, save, rename }) {
  const initial = read();
  const before = validOwners(saved());
  const owners = { ...before };
  const live = new Map(initial.spaces.filter(s => !s.machine).flatMap(s => s.tabs).map(t => [t.id, t]));
  for (const [id, owner] of Object.entries(owners)) {
    const tab = live.get(id);
    if (!tab) { delete owners[id]; continue; }
    if (owner.pending) {
      const { name, from } = owner.pending;
      if (tab.named && tab.name === name) {
        owners[id] = { name, terminal: owner.terminal };
      } else if (tab.named !== from.named || (tab.named && tab.name !== from.name)) {
        delete owners[id]; // An observed manual rename wins, even during a request.
      }
      // Unchanged origin: wait. Never automatically resend an uncertain command.
    } else if (tab.named && tab.name !== owner.name) {
      delete owners[id];
    }
  }

  const errors = [];
  for (const planned of tabRows(initial, owners)) {
    if (!planned.following || owners[planned.id]?.pending
        || !planned.candidate || planned.candidate === planned.name) continue;
    // Another copy or a user can win before this command. Never use stale rows.
    const current = tabRows(read(), owners).find(row => row.id === planned.id);
    if (!current?.following || current.terminal !== planned.terminal
        || current.candidate !== planned.candidate) continue;
    try {
      rename(current.id, current.candidate);
      owners[current.id] = {
        name: current.name, terminal: current.terminal,
        pending: { name: current.candidate, from: { name: current.name, named: current.named } },
      };
    } catch {
      errors.push(`Could not rename "${current.name}". Will retry on the next relevant data change.`);
    }
  }
  if (JSON.stringify(owners) !== JSON.stringify(before)) save(owners);
  return errors;
}
