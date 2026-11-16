<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# Claude Code: DMF measurement results

## Read [`AGENTS.md`](AGENTS.md) first

**[`AGENTS.md`](AGENTS.md) is the master rule set for this repository**: what a study is,
the two kinds of documentation, and the public-repository rules. It applies to every
tool and every person. Read it before anything else.

This file holds only what is specific to Claude Code. Not everyone on this team uses
Claude, so **never put a general rule here.** It belongs in `AGENTS.md`.

## Automatically loaded

Claude Code loads `.claude/rules/ai-notes.md` (measurement traps) into every session, and
`.claude/rules/human-docs.md` whenever a human-facing page is edited. Copilot does not
load them; that is why `AGENTS.md` links them explicitly.

## Commands

| Command | Use it to |
|---|---|
| `/new-study <section> <YYYY-MM>-<slug>` | Scaffold a study from `docs/study-template/` and add it to the root README |
| `/human-docs <file>` | Rewrite one human-facing page in the register of `docs/writing-guide.md`, then cold-read it |

## Delegation

**Stay in the main session** for every number: pulling stats, building raw-data tables,
choosing what a result means, and writing `results.md`. Those are the evidence, and a
cheap model that rounds or pairs runs wrongly corrupts it silently.

**Delegate** with the agent in `.claude/agents/`, whose model is pinned in its frontmatter:

| Agent | Model | Give it |
|---|---|---|
| `cold-reader` | `sonnet` | One human page (a study `README.md`, a section README, the root README, a `docs/` page) to read as a newcomer; it reports undefined terms, rereads and unclear points, and never edits |

Run `cold-reader` on every new or rewritten study `README.md` before the PR.

**A subagent's report is evidence, not truth.** Judge it in the main session.

## Before you commit

Run the same checks CI runs: `.github/scripts/docs-checks.sh`.
