# Review checklist

Review a change before it becomes a PR. We want clean, simple, short code that a person can read
at a glance, and as little of it to maintain as possible. Read the diff, then the code it
touches: callers of changed functions, what they call, the tests, and the project's guidance
(`AGENTS.md`, `CLAUDE.md`, any architecture notes they link). Do not edit any file.

Look for:

1. **Bugs:** wrong results, crashes, missed edge cases (empty, zero, last item, time zones),
   callers broken by a changed signature or behaviour, and existing caps, limits, filters or
   ranking outside the diff that the change runs into.
2. **Security:** unchecked input at trust boundaries, injection, secrets in code or logs,
   missing authorisation, data exposed to the wrong user.
3. **Scale:** fine for one user, wrong for many: a query or request per item, lists or memory
   that only grow, O(n²) on real input, check-then-write races, state that should be shared.
4. **Real data:** a new data source, column or join on real values: casing and spelling that
   differ between sources, duplicates, nulls, and volume (how many rows before and after).
5. **Rollout:** what users see between deploy and any rebuild, backfill or migration, and old
   links, saved URLs, clients and stored data that still use the old shape.
6. **Placement:** code or files in the wrong module or layer for this project's structure.
7. **Size and structure:** files growing past about 400 lines, functions doing several jobs,
   copied logic that should be shared, names that hide what something does.
8. **Bloat:** code that can be deleted, dead code, abstractions, wrappers, options or config
   nobody needs yet.
9. **Reinvented wheels:** code that the standard library, an installed dependency, or a
   well-maintained free package already does better. Name the package and check it exists and
   is maintained.
10. **Tests:** tests that add no value (they test the framework or a mock, restate the
    implementation, or duplicate another test), and risky new logic with no test.
11. **Readability:** anything a new teammate would have to decode.

Skip what linters, formatters and type checkers already catch, style preferences, and praise.

For items 1–5, report every issue you find, including ones you are unsure of or think minor,
with the evidence (the line, the input that breaks it, what you ran). Don't filter them
yourself: a separate checker verifies each one. For items 6–11, report only what you would ask
the author to change.

## Output

One block per finding, most severe first, or the single line `No findings.`

```
### <short title>
- where: path/to/file.py:42
- kind: bug | security | scale | data | rollout | placement | size | bloat | reinvented | tests | readability
- severity: high | medium | low
- confidence: 0-100 (how sure you are it is real and matters here)
- problem: what is wrong and what it breaks, in plain words
- fix: the smallest change that solves it
```
