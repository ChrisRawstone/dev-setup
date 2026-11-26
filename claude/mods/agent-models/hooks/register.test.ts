import { expect, test } from 'claude-code/testing'
import { agentFor, elapsed, jobFor, modelLine, shortModel, tokens } from './register'

test('model names', () => {
  expect(shortModel('claude-opus-5-5')).toBe('opus 5.5')
  expect(shortModel('claude-fable-5-2[1m]')).toBe('fable 5.2')
  expect(shortModel('gpt-6-astra')).toBe('astra')
  expect(shortModel('gpt-6.1-sol')).toBe('sol')
  expect(shortModel(undefined)).toBe('?')
})

test('numbers', () => {
  expect(tokens(259700)).toBe('259.7k')
  expect(tokens(1000000)).toBe('1M')
  expect(elapsed(493000)).toBe('8m13s')
  expect(elapsed(3 * 3600e3 + 60e3)).toBe('3h1m')
})

test('a codex subagent drives the first job started after it', () => {
  const t = Date.parse('2026-11-26T13:00:00Z')
  const jobs = [
    { id: 'b', startedAt: '2026-11-26T13:00:09Z', model: 'gpt-6-astra', tokens: 0 },
    { id: 'a', startedAt: '2026-11-26T12:59:00Z', model: 'gpt-6.1-sol', tokens: 0 },
    { id: 'c', startedAt: '2026-11-26T13:00:03Z', model: 'gpt-6-astra', tokens: 0 },
  ]
  expect(jobFor({ startTime: t }, jobs)?.id).toBe('c')
})

test('an Agent call row finds its agent and model', () => {
  const agents = [
    { id: 'old', description: 'scan', startTime: 1, model: 'claude-sonnet-5-5', type: 'Explore' },
    { id: 'new', description: 'scan', startTime: 2, model: 'claude-opus-5-5', type: 'Explore' },
    { id: 'x9', description: 'other', startTime: 3, model: 'claude-fable-5-2', type: 'general-purpose' },
  ] as any
  expect(agentFor({ description: 'scan' }, undefined, agents)?.id).toBe('new')
  expect(agentFor({ description: 'scan' }, 'Async agent launched. agentId: x9 (internal)', agents)?.id).toBe('x9')
  expect(modelLine(agents[2], {})).toBe('model fable 5.2')
  expect(modelLine(undefined, { model: 'haiku' })).toBe('model haiku')
  expect(modelLine(undefined, { subagent_type: 'codex:codex-rescue' })).toBe('codex')
  expect(modelLine(undefined, {})).toBe('')
})
