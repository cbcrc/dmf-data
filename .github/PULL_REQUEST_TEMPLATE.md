<!--
SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
SPDX-License-Identifier: CC-BY-4.0
-->

## What this changes

<!-- One or two sentences. Which study, or which rule. -->

## Which kind of change

- [ ] **New study** in `studies/<section>/`
- [ ] **Correction to a published study**: the study says so at the top, with the date and
      what changed. List the numbers that changed and why below.
- [ ] Docs, rules or CI only

## Where the numbers come from

<!-- New study or correction: the tool repository and commit, the scenarios, and the
     analysis command. Same as the study's "Reproduce" section is fine. -->

## Checklist

- [ ] Every number in the study `README.md` is in its `results.md`.
- [ ] `results.md` has setup, method, raw-data tables, caveats and a "Reproduce" section.
- [ ] The caveats say what was **not** controlled (clocks, governor, other tenants, cache).
- [ ] The study is listed in the root `README.md` with a one- or two-line summary.
- [ ] I ran the `cold-reader` agent (or had a newcomer read it) on the study `README.md`.
- [ ] **Public repository:** no IP addresses, hostnames, usernames or lab paths; no raw
      logs; no credentials. `.github/scripts/docs-checks.sh` passes.
