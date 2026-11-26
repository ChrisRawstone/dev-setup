import type { AgentInfo, EngineInterface, Register } from 'claude-code'

// The status line command only ever sees the main session, so this mod shows the rest:
// each subagent's model in the agent list, the viewed agent's model and context above
// the prompt, and Codex jobs (started through the codex plugin) with the model they run.

type CodexJob = { id: string; startedAt: string; threadId?: string; title?: string; model: string; tokens: number }

const REFRESH_MS = 5000

/** claude-opus-5-5[1m] -> "opus 5.5", gpt-6-astra -> "astra", gpt-6.1-sol -> "sol" */
export function shortModel(id?: string): string {
  if (!id) return '?'
  const m = id.replace(/\[.*\]$/, '')
  const claude = m.match(/^claude-([a-z]+)-(\d+)-(\d+)/)
  if (claude) return `${claude[1]} ${claude[2]}.${claude[3]}`
  return m.match(/^gpt-[\d.]+-([a-z]+)/)?.[1] ?? m
}

export function tokens(n: number): string {
  if (n >= 1e6) return `${Math.round(n / 1e5) / 10}M`
  if (n >= 1e3) return `${Math.round(n / 100) / 10}k`
  return String(n)
}

export function elapsed(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000))
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60)
  return h ? `${h}h${m}m` : m ? `${m}m${s % 60}s` : `${s}s`
}

/** The running Codex job a codex:* subagent drives: the first one started after it. */
export function jobFor(agent: { startTime: number }, jobs: CodexJob[]): CodexJob | undefined {
  return jobs
    .filter(j => Date.parse(j.startedAt) >= agent.startTime - 2000)
    .sort((a, b) => Date.parse(a.startedAt) - Date.parse(b.startedAt))[0]
}

let jobs: CodexJob[] = [] // module cache, rebuilt each tick (a reload starts it over)
let debug = '' // with AGENT_MODELS_DEBUG=1, what the last refresh saw, drawn above the prompt

async function refresh($: EngineInterface) {
  let err = ''
  const home = await $.env.get('HOME')
  const sid = await $.session.id()
  const root = `${home}/.claude/plugins/data/codex-openai-codex/state`
  const running: Omit<CodexJob, 'model' | 'tokens'>[] = []
  const dirs = await $.fs.list(root).catch((e: unknown) => { err = `list failed: ${e}`; return [] })
  for (const dir of dirs) {
    if (dir.kind !== 'dir') continue
    const text = await $.fs.read(`${root}/${dir.name}/state.json`).catch(() => '')
    if (typeof text !== 'string' || !text) continue
    try {
      for (const j of JSON.parse(text).jobs ?? []) {
        if (j.sessionId === sid && (j.status === 'running' || j.status === 'queued')) running.push(j)
      }
    } catch {} // the companion writes state.json in place; a torn read waits for the next tick
  }
  // Codex's own thread table has the model a job really ran on and its tokens.
  const threads = new Map<string, { model: string; tokens: number }>()
  const ids = running.map(j => j.threadId).filter((t): t is string => !!t && /^[0-9a-f-]+$/.test(t))
  if (ids.length) {
    const sql = `select id, model, tokens_used from threads where id in (${ids.map(i => `'${i}'`).join(',')})`
    const out = await $.process.run(['sqlite3', '-readonly', `${home}/.codex/state_5.sqlite`, sql], { timeoutMs: 3000 })
      .catch((e: unknown) => { err = `sqlite3 failed: ${e}`; return null })
    for (const line of out?.stdout.split('\n') ?? []) {
      const [id, model, used] = line.split('|')
      if (id) threads.set(id, { model: model ?? 'codex', tokens: Number(used) || 0 })
    }
  }
  const next = running.map(j => ({ ...j, model: threads.get(j.threadId ?? '')?.model ?? 'codex', tokens: threads.get(j.threadId ?? '')?.tokens ?? 0 }))
  jobs = next
  if (await $.env.get('AGENT_MODELS_DEBUG')) debug = `sid ${sid.slice(0, 8)} · ${dirs.length} dirs · ${running.length} running · ${threads.size} threads${err ? ' · ' + err : ''}`
  // Redraw each tick: elapsed times, tokens and the viewed agent's context move.
  $.ui.invalidate('ui.render')
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await refresh($).catch((err: unknown) => { debug = `refresh failed: ${err}` })
    $.clock.every(REFRESH_MS, () => { refresh($).catch((err: unknown) => { debug = `refresh failed: ${err}` }) })
    return next(e)
  })

  // Agent list: put the model in front of every subagent's words.
  on('ui.render', { component: 'AgentRow' }, ($, e, next) => {
    const p = e.props
    const job = p.type.startsWith('codex') ? jobFor(p, jobs) : undefined
    const tag = p.type.startsWith('codex') ? `codex ${job ? shortModel(job.model) : ''}`.trim() : shortModel(p.model)
    return next({ ...e, props: { ...p, label: `[${tag}] ${p.label}` } })
  })

  // Above the prompt: the viewed subagent, and Codex jobs of this session.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const rows: string[] = []
    const viewed = e.props.view?.agentId
    if (viewed) {
      const a: AgentInfo | undefined = (await $.agent.list()).find(x => x.id === viewed)
      if (a) {
        const ctx = a.contextWindowSize ? ` · ctx ${Math.round((a.tokenCount / a.contextWindowSize) * 100)}% (${tokens(a.tokenCount)}/${tokens(a.contextWindowSize)})` : ''
        const eff = a.effort !== undefined ? ` · eff ${a.effort}` : ''
        rows.push(`▸ viewing ${a.name ?? a.type} · ${shortModel(a.model)}${eff}${ctx} · ${elapsed(Date.now() - a.startTime)}`)
      }
    }
    const now = Date.now()
    for (const j of jobs) {
      rows.push(`◆ codex ${shortModel(j.model)} · ${tokens(j.tokens)} tokens · ${elapsed(now - Date.parse(j.startedAt))} · ${j.title ?? j.id}`)
    }
    if (debug) rows.push(`agent-models: ${debug}`)
    if (!rows.length) return next(e)
    const { Box, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="column">
        {rows.map((r, i) => <Text key={String(i)} dimColor>{r}</Text>)}
      </Box>
    )
  })
}
