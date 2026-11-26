import { expect, test } from 'claude-code/testing'
import { elapsed, jobFor, shortModel, tokens } from './register'

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
