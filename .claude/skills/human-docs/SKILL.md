---
name: human-docs
description: "Rewrite one human-facing page (a README.md or a file in docs/) in the plain register of docs/writing-guide.md, moving technical evidence into the study's results.md or .claude/rules/ai-notes.md, then checking it with the cold-reader agent. Run as /human-docs <file>."
disable-model-invocation: true
argument-hint: "<path to a README.md or a docs/ file>"
---

<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# Rewrite a page for people

The page to rewrite is `$ARGUMENTS`. It must be a `README.md` or under `docs/`. If it is
anything else, stop and say so: a study's `results.md` is evidence and keeps its detail,
and agent files keep their dense register.

This is main-session work: every number on the page is evidence.

## 1. Read

- `docs/writing-guide.md`: the register to write in.
- The page itself, in full.
- For a study `README.md`: the study's `results.md`, in full. It is the source of truth.
- `.claude/rules/ai-notes.md`, for the traps the page may need to explain.

## 2. List the claims before touching anything

Write every result, number, rule of thumb and open question the page states into a
scratch file, one line each, with where it comes from in `results.md`. This is the fact
list: the rewrite must keep every line of it. A number you cannot find in `results.md`
is a defect: report it, do not keep or fix it silently.

## 3. Move the evidence out

For each source citation, counter name, SDK internal, or detail only someone reproducing
the work needs:

- If `results.md` already holds it, drop it from the page.
- If not, add it to `results.md` first (or, for a reusable measurement trap, to
  `.claude/rules/ai-notes.md`).
- Names a reader has to type (a scenario, a setting) stay on the page, in a code block or
  a table.

## 4. Rewrite

Follow the checklist in `docs/writing-guide.md`: the question, what fooled us, the
answer, rules of thumb, what is still open.

- **Never change a result.** Rounding only, and in the direction `results.md` supports.
  If a result looks wrong, leave it and tell the user.
- Keep the headings other files link to, or update every link
  (`grep -rn '<file>#' --include=*.md .`).
- Keep the SPDX header.

## 5. Cold read

Run the `cold-reader` agent on the rewritten file. Fix what it reports, as long as the
fix keeps the facts. If the page is long or was badly rated, run it once more.

## 6. Check

- Every line of the fact list maps to a sentence in the new page.
- `.github/scripts/docs-checks.sh` passes.
- Every relative link in the page still resolves.

Report to the user:
- the cold-reader counts, before and after;
- every fact moved into `results.md` or `ai-notes.md`;
- any result you think is wrong but did not change.
