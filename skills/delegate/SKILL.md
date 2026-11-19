---
name: delegate
description: Hand a task to cheap Sonnet/Haiku workers and verify their work, in one of two modes - check (one pass, then one Opus check) or manage (I push back and send work back until claims hold, max 2 rounds). Use for "/delegate", "delegate this", or when fanning out research, audits or reviews to subagents.
argument-hint: "[check|manage] <task>"
---

# Delegate

I am the manager: workers do the legwork on cheaper models, I verify against reality (tests, the cited
lines, the opened URL), never against how convincing a report reads. Two modes, so the owner can
compare them in real use.

## 0. Pick the mode

- First word `check` or `manage`: use it.
- No mode given: take the opposite of the last entry in `~/.claude/delegate-log.jsonl` (start with
  `manage` if the file is missing), and say which mode in one line. That alternation is the A/B test.

## 1. Brief the workers (both modes)

- Split the work into 1–3 independent slices; one worker per slice (not three copies of the same task:
  same-model copies share blind spots). One slice is fine.
- `Agent` with `model: "sonnet"` (pure file/code search: `model: "haiku"`), and start each
  `description` with `[delegate:<mode>]` so usage can be compared later from the transcripts.
- Each brief stands alone: goal, what is known, paths/URLs, output format, and "write your full
  result to `<scratchpad>/delegate/<slice>.md` and return a short summary". Require every claim to
  carry its evidence: file:line, command + output, or URL + quote.

## 2a. Mode `check`: one pass

1. Read the result files. Run the cheap checks yourself: the tests, the cited lines, a few URLs.
2. Only when the result will be acted on (an audit, a review, a decision, money): one fresh `Agent`
   with `model: "opus"`, description `[delegate:check] verify`, given the result file and the
   instruction to check each claim against the code/sources and list what is wrong or unsupported.
3. Answer, dropping or marking what failed.

## 2b. Mode `manage`: push back until it holds

1. Read the result files and build a claim table: claim | evidence | check | status.
2. Challenge every claim that matters and is any of: surprising or too good to be true, single
   source, no evidence, contradicted by another worker, or failing its check. Check it yourself when
   that's one cheap step; otherwise send it back to the same worker with `SendMessage` (load it with
   ToolSearch `select:SendMessage`), naming the exact gap: "claim 3 has one blog as source: find two
   independent ones or drop it", "show the measurement behind this 60%", "test X fails: fix it".
3. Re-check what comes back. Stop when every key claim is verified, or after **2 rounds**; mark the
   rest "unverified" rather than looping.
4. Answer with the verified claims, then a short "unverified / dropped" list.

## 3. Log it

Append one line to `~/.claude/delegate-log.jsonl` (create it if missing):

```json
{"date":"YYYY-MM-DD","mode":"manage","task":"<3-6 generic words, no client or work names>","workers":2,"rounds":1,"sent_back":3,"caught":2,"opus_check":false}
```

`sent_back` = claims sent back to workers; `caught` = claims that turned out wrong or unsupported
(by your checks, the pushback or the Opus check). End the reply with one line: "Mode: <mode>, caught
<n>. Rate it 1–5?" If the owner answers, add `"rating"` to that log line.
