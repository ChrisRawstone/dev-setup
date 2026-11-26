// Add an observed per-turn timer to cxstatusline's local renderer. No network.
// Runs the renderer in this same node process: patched Codex drops any render slower than 1s
// (then shows its stock footer), and python plus a second node start often was.
import crypto from 'node:crypto';
import fs from 'node:fs';
import module from 'node:module';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const HOME = process.env.HOME;
const STATE_ROOT = path.join(HOME, '.local/state/cxstatusline/turn-timers');
const PLACEHOLDER = 'turn —';
const RUNNING = new Set(['working', 'thinking', 'running', 'compacting', 'compacting context']);

// cxstatusline next to this node (Homebrew or an nvm version), else Homebrew's.
export const RENDERER = [
  path.resolve(process.execPath, '../../lib/node_modules/cxstatusline/dist/cxstatusline.js'),
  '/opt/homebrew/lib/node_modules/cxstatusline/dist/cxstatusline.js',
].find((js) => fs.existsSync(js));

export function updateTimer(previous, running, now) {
  const state = { ...previous };
  if (running && !state.running) Object.assign(state, { start: now, elapsed: 0 });
  if (state.start != null && (running || state.running)) state.elapsed = Math.max(0, now - state.start);
  state.running = running;
  return state;
}

export function duration(total) {
  const s = Math.floor(Math.max(0, total));
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = String(s % 60);
  if (h) return `${h}h${String(m).padStart(2, '0')}m${sec.padStart(2, '0')}s`;
  return m ? `${m}m${sec.padStart(2, '0')}s` : `${sec}s`;
}

// Fill in the turn timer and, as Claude's bar does, show 8 chars of the session id and
// git-changes "(+12,-3)" as green "+12", red "-3".
export function restyle(text, label, id = '') {
  if (id) text = text.replaceAll(id, id.slice(0, 8));
  return text.replaceAll(PLACEHOLDER, label).replace(/\((\+\d+),(-\d+)\)/, '$1 \x1b[38;2;248;113;113m$2');
}

function timerLabel(data) {
  const session = data.session || {};
  if (!session.id) return PLACEHOLDER;
  const key = crypto.createHash('sha256').update(`${session.id}\0${session.started_at || ''}`).digest('hex');
  fs.mkdirSync(STATE_ROOT, { recursive: true, mode: 0o700 });
  const file = path.join(STATE_ROOT, `${key}.json`);
  if (fs.lstatSync(STATE_ROOT).isSymbolicLink() || (fs.existsSync(file) && fs.lstatSync(file).isSymbolicLink())) {
    throw new Error('symlinked timer state');
  }
  let state = {};
  try { state = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
  state = updateTimer(state, RUNNING.has(String(session.run_state || '').toLowerCase()), Date.now() / 1000);
  const temp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(temp, JSON.stringify(state), { mode: 0o600, flag: 'wx' });
  fs.renameSync(temp, file);
  return state.start != null ? `turn ${duration(state.elapsed)}` : PLACEHOLDER;
}

async function main() {
  const raw = fs.readFileSync(0);
  if (raw.length > 65536) process.exit(2);
  const data = JSON.parse(raw);
  const label = timerLabel(data), id = String(data.session?.id || '');
  // Hand the renderer the stdin we already read, and swap the placeholder in its output.
  const readFileSync = fs.readFileSync;
  fs.readFileSync = (file, ...rest) => (file === 0 ? (rest[0] ? raw.toString(rest[0]?.encoding ?? rest[0]) : raw) : readFileSync(file, ...rest));
  module.syncBuiltinESMExports();
  const write = process.stdout.write.bind(process.stdout);
  process.stdout.write = (chunk, ...rest) => write(typeof chunk === 'string' ? restyle(chunk, label, id) : chunk, ...rest);
  process.argv = [process.argv[0], RENDERER, 'render'];
  process.env.DEV = 'false';
  module.enableCompileCache?.();
  await import(pathToFileURL(RENDERER).href);
}

// Run only as a script (it is reached through a ~/.config symlink), not when a test imports it.
if (process.argv[1] && import.meta.url === pathToFileURL(fs.realpathSync(process.argv[1])).href) {
  main().catch(() => process.exit(2));
}
