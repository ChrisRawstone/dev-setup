# Note style

The owner's preferences for notes. Update this file when they say what works or doesn't.

## Structure
- Start with the answer: a 2–4 line summary or verdict at the top (a callout `> [!summary]` works), then details.
- Short sections with plain headings; bullets and tables over paragraphs. Plain language, no jargon without a
  one-line explanation.
- End with "Sources" (a link for every fact, price and product) and, where useful, "Next steps" or "Open questions".
- Frontmatter: `updated: YYYY-MM-DD` and `tags:` (project or topic).

## Visuals (at least one per note when it helps understanding)
- How things fit together or flow (code, systems, processes): a Mermaid diagram (flowchart, sequence, timeline).
- Numbers over time or side by side: a Charts plugin chart (` ```chart `) or DataviewJS over a CSV in `_generated/`.
- Comparisons (products, options, tools): a table with one row per option, the key specs, price with a link, and a
  verdict column; recommended option first.
- Products: 1–3 photos of each recommended one (exact variant), stored small (< 200 kB) next to the note in an
  `attachments/` folder, with caption and source link.

## Kinds of note
- **Codebase explainer:** what it does in two lines, a diagram of the main parts and how data flows, where each part
  lives (file links), how to run it, gotchas.
- **Learning a technology:** what problem it solves, how it works (diagram), a tiny example, when not to use it,
  how it compares with alternatives.
- **Shopping:** what matters for this purchase, the shortlist table, the pick and why, where to buy (links, prices in
  DKK, date checked), what to avoid.
- **Overview / status:** a status table (what, state, next), a chart if there are numbers, decisions taken.
