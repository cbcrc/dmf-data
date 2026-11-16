<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# GitHub Copilot: DMF measurement results

## Read [`AGENTS.md`](../AGENTS.md) first

**[`../AGENTS.md`](../AGENTS.md) is the master rule set for this repository**: what a study
is, the two kinds of documentation, and the public-repository rules. It applies to every
tool and every person.

This file holds only what is specific to Copilot. **Never put a general rule here**: it
belongs in `AGENTS.md`, where the whole team gets it.

## Files to open explicitly

Claude Code auto-loads some rule files that Copilot does not. Open these yourself:

| File | When |
|---|---|
| [`../.claude/rules/ai-notes.md`](../.claude/rules/ai-notes.md) | **Before planning or interpreting any measurement.** The traps that already fooled us. |
| [`../docs/writing-guide.md`](../docs/writing-guide.md) | Before editing any `README.md` or anything in `docs/`. |
| [`../docs/study-template/`](../docs/study-template/) | When starting a study. |

They live under `.claude/` for historical reasons; their content is tool-neutral.

**Editing a `README.md` or `docs/`?** Those files are for people.
[`instructions/human-docs.instructions.md`](instructions/human-docs.instructions.md) applies
this automatically where Copilot supports path-specific instructions; elsewhere, open the
writing guide yourself.

## Public repository: always

- No IP addresses, hostnames, usernames or lab paths. Hosts are named by role ("host A").
- No raw logs (`*.ndjson`), no file over 5 MB.
- No credentials, not even placeholders that look real.

Run `.github/scripts/docs-checks.sh` before you push; CI runs the same script.
