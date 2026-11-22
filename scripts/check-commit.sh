#!/usr/bin/env bash
# Check that a commit title is a Conventional Commit:
#
#   type[(scope)][!]: description
#
#   scripts/check-commit.sh "feat(config): add --quiet"   a title (CI, on PRs)
#   scripts/check-commit.sh --file FILE                   a message (commit-msg)
#
# A message file may also be what git writes itself (Merge, Revert, fixup!,
# squash!, amend!): those never reach main, as pull requests are squashed.
set -euo pipefail

types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
pattern="^($types)(\([a-z0-9._/-]+\))?!?: [^ ].*$"

if [ "${1:-}" = --file ] && [ $# = 2 ]; then
        # The first line with text that isn't one of git's comments
        title=$(awk '!/^#/ && NF { print; exit }' "$2")
        # An empty message: git aborts the commit itself
        [ -n "$title" ] || exit 0
        case $title in
        'Merge '* | 'Revert "'* | 'fixup! '* | 'squash! '* | 'amend! '*) exit 0 ;;
        esac
elif [ $# = 1 ] && [ "$1" != --file ]; then
        title=$1
else
        echo "usage: check-commit.sh TITLE | --file FILE" >&2
        exit 2
fi

if ! [[ $title =~ $pattern ]]; then
        cat >&2 <<EOF
Not a Conventional Commit: $title

Write it as: type[(scope)][!]: description
Types: ${types//|/, }
Like: feat: add --quiet, fix(config): handle an empty file
A ! after the type or scope marks a breaking change.
EOF
        exit 1
fi
