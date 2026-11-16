---
paths:
  - "**/README.md"
  - "docs/**/*.md"
---

# This file is for people

Every `README.md` and everything in `docs/` is read by people. Before editing, read
[`docs/writing-guide.md`](../../docs/writing-guide.md) and write to it:

- Open with the question and why it matters. Explain every term on first use.
- Few numbers, rounded, each with its meaning. Each one must be in the study's
  `results.md`; if they disagree, `results.md` wins.
- Say what fooled us on the way, then the answer, then numbered rules of thumb.
- No source file:line citations, SDK internals or counter names in prose. CI rejects
  `file.cpp:123`-style citations here. Detail goes in `results.md`.
- No IP addresses, hostnames or lab paths: hosts are named by role.
- A readability edit never changes a result.

To rewrite a whole page, use `/human-docs <file>`. To check one, run the `cold-reader`
agent on it.
