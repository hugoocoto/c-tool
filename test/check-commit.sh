#!/usr/bin/env bash
# scripts/check-commit.sh takes Conventional Commits, and nothing else
set -uo pipefail

failed=0
good() { scripts/check-commit.sh "$1" 2>/dev/null || { echo "rejected: $1"; failed=1; }; }
bad() { ! scripts/check-commit.sh "$1" 2>/dev/null || { echo "accepted: $1"; failed=1; }; }

good 'feat: add --quiet'
good 'fix(config): handle an empty file'
good 'feat!: remove --old'
good 'refactor(src/main.c)!: split parsing'
good 'chore(main): release 1.2.3'
good 'ci(deps): bump the actions group with 2 updates'

bad 'Add --quiet'
bad 'feat add --quiet'
bad 'feat:add --quiet'
bad 'feat:  two spaces'
bad 'feat: '
bad 'feature: add --quiet'
bad 'Feat: add --quiet'
bad 'feat(): empty scope'
bad 'Merge branch main'

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
file() { printf '%b' "$1" >"$dir/msg"; scripts/check-commit.sh --file "$dir/msg" 2>/dev/null; }

file '# a comment\n\nfeat: add it\n\nBody.\n' || { echo "rejected a message after comments"; failed=1; }
file 'Merge branch main\n' || { echo "rejected a merge"; failed=1; }
file 'fixup! feat: add it\n' || { echo "rejected a fixup"; failed=1; }
file '# only a comment\n' || { echo "rejected an empty message, which git aborts"; failed=1; }
! file 'Add it\n' || { echo "accepted a bad message"; failed=1; }

exit $failed
