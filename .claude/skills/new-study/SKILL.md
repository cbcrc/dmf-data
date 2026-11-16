---
name: new-study
description: "Scaffold a new measurement study under studies/<section>/<YYYY-MM>-<slug>/ from docs/study-template/, list it in the root README, and walk through the public-repo checklist. Run as /new-study <section> <YYYY-MM>-<slug>."
disable-model-invocation: true
argument-hint: "<section> <YYYY-MM>-<slug>"
---

<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# Start a study

Arguments: `$ARGUMENTS`, expected as `<section> <YYYY-MM>-<slug>`.

## 1. Check the arguments

- `<section>` is a directory under `studies/` (`infra`, `network-transport`,
  `kubernetes-cluster`, `mxl` today). If it is not, ask whether to create a new section;
  a new section also gets a `studies/<section>/README.md` and a row in the section table
  of `AGENTS.md` and the root `README.md`.
- `<YYYY-MM>` is when the measurements were taken. `<slug>` is lowercase, hyphenated, and
  names the question ("cross-numa-grain-transit"), not the tool.
- The directory does not exist yet.

## 2. Scaffold

1. Copy `docs/study-template/README.md`, `results.md` and `how-to-reproduce.md` into
   `studies/<section>/<YYYY-MM>-<slug>/`.
2. Add the study to the root `README.md`, under its section, as
   `- [<Title>](studies/<section>/<YYYY-MM>-<slug>/) (<Month YYYY>): <one or two lines>`.
   Remove the section's "no studies yet" line if it is there. Do the same in the section's
   own `README.md`.

## 3. Gather the evidence (main session, never delegated)

- Ask the user where the raw logs are, which runs count, and what the setup was (clock
  sync, governor, other tenants, transport). Do not guess a setup detail the logs do not
  record; list it as an open question instead.
- Copy raw logs into the session scratchpad only. **Never into the repository.**
- Before computing anything, read `.claude/rules/ai-notes.md`: appended logs, lane C,
  clock offsets, cache residency.
- Fill `results.md` first (setup, method, raw-data tables, caveats), then
  `how-to-reproduce.md` (numbered steps with every command, the analysis, the figures to
  compare with), then write `README.md` from `results.md`. Commands and steps go only in
  `how-to-reproduce.md`.

## 4. Public-repository pass

Before handing back:

- Replace every IP address, hostname, user name and lab path with a host role.
- `.github/scripts/docs-checks.sh` passes.
- Run the `cold-reader` agent on the study `README.md` and fix what it reports.

Report to the user: the files created, the open questions you listed, and the
cold-reader count.
