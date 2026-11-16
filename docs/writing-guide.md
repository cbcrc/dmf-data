<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

# Writing for people

## Why this page exists

A measurement is only useful if the people who make deployment decisions read it. They
will not read 1,600 lines of counter tables. They will read a page and a half that tells
them what we asked, what we found, and what to do about it, as long as they trust that
the tables exist behind it.

So every study here has three files with three different jobs:

- **`README.md`, the executive summary.** Read by anyone deciding how to deploy
  something: architects, operations, managers, other teams. It tells the story and ends
  with rules of thumb.
- **`results.md`, the detailed results.** Read by whoever wants to check or challenge the
  work. It holds every table, every setting and every caveat.
- **`how-to-reproduce.md`, the steps.** Read by whoever wants to run it again, on their own
  hardware. Numbered steps, each with the commands to type.

When one file tries to do both, the summary drowns in numbers and the decision it was
meant to inform goes through unread. This page is about the first kind, and about the
parts of the second kind that people still have to follow.

## Who you are writing for

Picture a **broadcast engineer**. They know video and audio: frame rates, resolutions,
latency budgets, lip-sync, what a dropped frame looks like on air. They have not read the
MXL source. They have never looked at a CPU's cache hierarchy or configured an RDMA NIC,
and they do not know this team's vocabulary yet. If they can follow your summary, everyone
else can too.

## The checklist

1. **Start with the question and why it matters.** What decision does this study inform,
   and for whom? "Can a reader on the other CPU socket keep up with a 4K flow?" comes
   before any mechanism.
2. **Explain each term the first time it appears.** One plain sentence, with an image if
   one fits: "a server is essentially two computers glued together; each socket has its own
   cores, cache and memory".
3. **One idea per paragraph.** Short sentences. A concrete example beats an abstract rule.
4. **Few numbers, rounded, with their meaning.** "About 1 ms per frame, out of a 33 ms
   frame budget" says more than a table. Every number in the summary must be in
   `results.md`.
5. **Tell the reader what fooled you.** Measurements lie in predictable ways: a cache that
   holds the whole test, a power-saving CPU, clocks that disagree. Saying how you were
   fooled, and how you fixed it, is what earns the reader's trust in the final number. A
   short "plot twist" per trap works well.
6. **Leave the evidence out of the prose.** No source file and line numbers, no SDK
   internals, no counter names mid-sentence. If a reader must type something (a setting, a
   scenario name), put it in a code block or a table.
7. **End with what to do.** Rules of thumb, numbered, each one sentence plus its reason.
   Then the questions still open.
8. **Link down for the detail.** "The tables, settings and caveats are in
   `results.md`."

## The detailed results: complete, but still readable

`results.md` may be long and dense; that is its job. It is still read by people, so:

- Open with a short **bottom line** that matches the summary, then the setup.
- Name hosts by **role** ("host A, the writer"), never by address or name.
- Every table says what one row is and what the units are. Explain a metric the first time
  it appears, in one sentence.
- Raw-data tables are the statistics the conclusions were drawn from, per run: counts,
  failures, min, p50, p90, p99, max. Say which runs were excluded and why.
- The **caveats** list everything that was not controlled.
- **No commands.** How to run it again goes in `how-to-reproduce.md`. The method section says
  *what* each run did; the steps page says *how* to do it.

## An example

Before, from the detailed results of the cross-NUMA study:

> | 2160p copy | Local reader (node 0) | Cross reader (node 1) | Cross - local |
> |---|---|---|---|
> | Writer fill (`memset` 22 MB), with the reader at head+1 | 1.484 / 1.641 | 1.985 / 2.009 | +0.50 (+34 %) |
>
> The fill is slower whenever the reader is on node 1: the reader's read leaves the line
> in state A in the memory directory, so the writer's RFO waits for the snoop of node 1.

After, in the summary:

> **The writer gets slowed down too.** Surprisingly, the writer on socket 0 also slows down,
> by about half a millisecond. The remote reader leaves a note in the memory directory, and
> when the writer later overwrites that memory, it first has to ask across the bridge
> whether socket 1 still holds a copy.

The facts did not change. The second version says what happens and why it matters. The
table, the counter names and the exact figures stay in `results.md`.

## What enforces this

- **CI** fails a `README.md` or a file in `docs/` that cites a source line
  (`file.cpp:123`), a study without its three files or without an entry in the root README,
  a private IP address, and any raw log. Run `.github/scripts/docs-checks.sh` locally.
- **Claude Code** loads a short reminder of this page whenever it edits a human page, and
  offers `/human-docs` to rewrite one this way. Its `cold-reader` agent reads a page as the
  engineer above would and lists every term it had to guess.
- **Copilot** gets the same reminder through
  `.github/instructions/human-docs.instructions.md`.
- **Reviewers:** if you had to read a paragraph twice, say so in the review. That is a real
  defect.
