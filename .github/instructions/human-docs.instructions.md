---
applyTo: "**/README.md,docs/**/*.md"
---

<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# This file is for people

Every `README.md` and everything in `docs/` is read by people. Before editing, read
`docs/writing-guide.md` and write to it. The rule itself is in `AGENTS.md`, "Two kinds of
documentation".

- Open with the question and why it matters. Explain every term on first use.
- Few numbers, rounded, each with its meaning. Every number must also be in the study's
  `results.md`; if the two disagree, `results.md` wins.
- No source file:line citations and no SDK internals in prose. CI rejects
  `file.cpp:123`-style citations here. Detail goes in the study's `results.md`.
- No IP addresses or hostnames: hosts are named by role.
- A readability edit never changes a result.
