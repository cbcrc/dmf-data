#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 CBC/Radio-Canada
# SPDX-License-Identifier: Apache-2.0
#
# The checks CI runs on every push and PR (AGENTS.md). Run it locally before pushing:
#   .github/scripts/docs-checks.sh
# It looks at tracked files plus untracked, non-ignored ones, so it works before a commit.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail=0
err() { echo "::error::$*"; fail=1; }
files() { git ls-files --cached --others --exclude-standard "$@"; }
# This script quotes the patterns it forbids, so it excludes itself.
SELF=(':!.github/scripts/docs-checks.sh')

# 1. Human pages carry no source citations (docs/writing-guide.md). The writing guide is
#    excluded: its before/after example quotes one.
if git grep --untracked -nE '\.(c|cc|cpp|h|hpp|rs|py|go|js|ts):[0-9]' -- '*README.md' 'docs/*.md' \
     ':!docs/writing-guide.md'; then
  err "README.md files and docs/ are for people. Move source citations out (docs/writing-guide.md)."
fi

# 2. Every study has its three files.
studies=$(files 'studies/*/*/*' | awk -F/ 'NF>=4 {print $1"/"$2"/"$3}' | sort -u)
for s in ${studies}; do
  for f in README.md results.md how-to-reproduce.md; do
    [ -f "${s}/${f}" ] || err "${s} has no ${f} (AGENTS.md, \"Anatomy of a study\")."
  done
done

# 3. Every study is listed in the root README.
for s in ${studies}; do
  grep -qF "(${s}/" README.md || grep -qF "(${s})" README.md \
    || err "${s} is not linked from the root README.md."
done

# 4. Public repository: no private IP addresses or lab home paths. Host names cannot be
#    pattern-matched without publishing them; reviewers check those (PR template).
#    /home/mxl/ is allowed: it is a path inside the MXL demo container images.
if git grep --untracked -nIE \
     -e '\b10(\.[0-9]{1,3}){3}\b' \
     -e '\b192\.168(\.[0-9]{1,3}){2}\b' \
     -e '\b172\.(1[6-9]|2[0-9]|3[01])(\.[0-9]{1,3}){2}\b' \
     -e '/home/([^m]|m[^x]|mx[^l])[a-z0-9._-]*/' \
     -- . "${SELF[@]}"; then
  err "Private addresses, lab host names or lab paths found. Name hosts by role (AGENTS.md, \"Public repository\")."
fi

# 5. No raw logs, no large files.
if files | grep -E '\.ndjson(\.|$)'; then
  err "Raw NDJSON logs do not go in this repository. Publish the derived tables instead."
fi
while IFS= read -r f; do
  [ -f "${f}" ] || continue
  size=$(wc -c < "${f}")
  [ "${size}" -le 5242880 ] || err "${f} is $((size / 1048576)) MB; the limit is 5 MB."
done < <(files)

[ "${fail}" -eq 0 ] && echo "docs checks OK"
exit "${fail}"
