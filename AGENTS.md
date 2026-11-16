<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# Agent guide: DMF measurement results

**This file is the master rule set. It applies to everyone and every tool.**

Claude Code reads it via [`CLAUDE.md`](CLAUDE.md); GitHub Copilot reads it via
[`.github/copilot-instructions.md`](.github/copilot-instructions.md). Those two files are
pointers: they hold only tool-specific extras. **Rules that apply to everybody are
edited here, once.** Never copy a rule into a tool-specific file; that is how the people
using different tools drift apart.

## What this repository is

The published results of measurements made around the EBU **Dynamic Media Facility**
(DMF): the hosts, the network, the Kubernetes cluster, and MXL, the shared-memory media
exchange the media functions use. One directory per study, grouped by section:

| Section | Holds |
|---|---|
| `studies/infra/` | Compute hosts: CPU, sockets and NUMA, caches, power and frequency tuning, memory bandwidth |
| `studies/network-transport/` | Moving media between hosts: RDMA, MXL fabrics, NICs, ST 2110, PTP |
| `studies/kubernetes-cluster/` | Scheduling and isolation on the cluster: CPU manager, topology, noisy neighbours, QoS |
| `studies/mxl/` | Behaviour and cost of the MXL SDK and its API, independent of the host |

A study that fits two sections goes where its *takeaways* apply, and the other
section's README links to it. A new section is added when its first study lands, not
before.

The repository is **public** and holds **results, not tools**. The tools live in their
own repositories (for MXL, [`cbcrc/mxl-api-bench`](https://github.com/cbcrc/mxl-api-bench)),
and each study names the exact tool commit and scenario that produced its numbers.

## Anatomy of a study

```
studies/<section>/<YYYY-MM>-<slug>/
  README.md    the executive summary, for people (docs/writing-guide.md)
  results.md   the detailed results: setup, method, every number, caveats, how to reproduce
```

- `<YYYY-MM>` is when the measurements were taken, not when they were written up.
- **`README.md`** tells the story: the question, what fooled us on the way, the answer,
  and the rules of thumb that follow. Few numbers, rounded. It links to `results.md` for
  everything else.
- **`results.md`** is the evidence. It may be dense. It must contain:
  1. **Setup**: hardware, software versions, host settings, all with host *roles*
     ("host A"), never addresses or names.
  2. **Method**: what each run did and what each metric means.
  3. **Raw-data tables**: the per-run statistics the conclusions were drawn from
     (min / p50 / p90 / p99 / max, call counts, failures), not only the summary.
  4. **Caveats and open questions.**
  5. **Reproduce**: the tool repository and commit (or image tag), the scenario files,
     the compose files and overrides, and the analysis command.
- Every study is listed in the root [`README.md`](README.md) under its section, with one
  or two lines saying what it found. CI fails a study that is not listed.
- A number in `README.md` must appear, or be derivable, in `results.md`. When the two
  disagree, `results.md` wins and `README.md` is the bug.

Start a study from [`docs/study-template/`](docs/study-template/). Claude Code users:
`/new-study` scaffolds it.

## General behaviour

1. **Think before writing.** State your assumptions out loud. If the request is
   ambiguous, ask. Stop when confused and name what is unclear; do not pick an
   interpretation silently.
2. **Never invent or "clean up" a number.** Every figure comes from a measurement you
   can point to: a stats run, a counter, a log. Rounding happens only in `README.md`,
   and only in the direction the evidence supports. If a number looks wrong, flag it;
   do not fix it by hand.
3. **Say what was not controlled.** Clock sync, governor, other tenants on the host,
   cache residency: if it could move the result, the caveats say whether it was
   controlled. [`.claude/rules/ai-notes.md`](.claude/rules/ai-notes.md) lists the traps
   that have already fooled us.
4. **Surgical changes.** Touch only what the task requires. A readability edit never
   changes a result. A correction to a published result says so at the top of the
   study, with the date and what changed.
5. **Keep the index in sync.** Adding, renaming or moving a study updates the root
   README in the same change.

## Two kinds of documentation

| Kind | Files | Register |
|---|---|---|
| **For people** | `README.md` (root, section and study), everything in `docs/`, PR descriptions | Plain words, per [`docs/writing-guide.md`](docs/writing-guide.md): the question first, terms explained on first use, few rounded numbers, what to do at the end |
| **Evidence** | Each study's `results.md` | Complete and exact: tables, versions, settings, commands. Still written in sentences, still explains its terms, but completeness wins over brevity |
| **For agents** | `AGENTS.md`, `CLAUDE.md`, `.claude/**`, `.github/*instructions*` | Dense and exact |

- Human pages never cite source code lines (`file.cpp:123`) or SDK internals. CI
  rejects a citation in a `README.md` or in `docs/`. The explanation goes in `results.md`;
  a reusable measurement trap goes in `.claude/rules/ai-notes.md`.
- A readability edit never changes a result. If you find a result that looks wrong while
  rewording it, raise it separately.

## Public repository

Everything here is published. On every change, without exception:

- **No lab addresses or host names.** No IP addresses, no hostnames, no usernames, no
  home-directory paths from the lab. Hosts are named by role: "host A (writer)",
  "host B (reader)". CI fails on a private IP address.
- **No raw logs.** NDJSON event logs, perf captures and archives stay on the lab hosts or
  in internal storage. The repository carries the derived tables and the recipe to
  reproduce them. CI fails on `*.ndjson` and on any file over 5 MB.
- **No credentials.** No keys, tokens or passwords, not even placeholders that look real.
- **Nothing confidential.** No vendor pricing, contracts or names of people outside the
  team. Hardware models and public software versions are fine.

## Pull requests

Keep them small: one study, or one change to the rules, per PR. One approval merges.
A PR that adds or changes a study says in its description which numbers changed and
why.
