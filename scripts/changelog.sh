#!/usr/bin/env bash
# Changelog from the commit messages (merges left out), grouped by their
# Conventional Commit type (see Commit messages in CONTRIBUTING.md). It's for
# the nightly release: real releases have release-please's CHANGELOG.md.
#
#   scripts/changelog.sh        the whole changelog, newest first: what's not
#                               released yet, then every release
#   scripts/changelog.sh REF    only one section: a release's tag, or what REF
#                               has that isn't released (HEAD)
#
# Run it in the repo.
set -euo pipefail

git rev-parse --verify --quiet HEAD >/dev/null || { echo "changelog: no commits" >&2; exit 1; }

# Links to commits and diffs, if the repo is on GitHub
slug=${GITHUB_REPOSITORY:-$(git remote get-url origin 2>/dev/null |
        sed -nE 's#^.*github\.com[:/]+([^/]+/[^/]+)$#\1#p' | sed 's/\.git$//')}
url=${slug:+https://github.com/$slug}

# Releases are the tags ending in a version, however release-please is set to
# write them (1.2.3, v1.2.3, name-v1.2.3). nightly is a tag that moves.
is_release() { [[ $1 =~ (^|[-v])[0-9]+\.[0-9]+\.[0-9]+$ ]] && git rev-parse --verify --quiet "refs/tags/$1" >/dev/null; }

# The newest release reachable from $1 (itself included), if any
last_release() { git describe --tags --abbrev=0 --exclude nightly "$1" 2>/dev/null || true; }

# section TITLE FROM TO: the commits in FROM..TO (or everything up to TO)
section() {
        local title=$1 from=$2 to=$3 date
        local log
        log=$(git log --no-merges --format='%H %s' "${from:+$from..}$to")
        [ -n "$log" ] || return 0

        is_release "$title" && date=" - $(git log -1 --format=%cs "$title")" || date=
        printf '## %s%s\n' "$title" "$date"
        printf '%s\n' "$log" | awk -v url="$url" '
        {
                hash = $1
                msg = substr($0, length(hash) + 2)
                if (msg ~ /^[a-z]+(\([^)]*\))?!: /) group = "Breaking"
                else if (msg ~ /^feat(\([^)]*\))?: /) group = "Added"
                else if (msg ~ /^fix(\([^)]*\))?: /) group = "Fixed"
                else group = "Changed"
                short = substr(hash, 1, 7)
                ref = url ? "[" short "](" url "/commit/" hash ")" : short
                items[group] = items[group] "- " msg " (" ref ")\n"
        }
        END {
                split("Breaking Added Changed Fixed", order, " ")
                for (i = 1; i <= 4; i++)
                        if (order[i] in items) printf "\n### %s\n\n%s", order[i], items[order[i]]
        }'
        if [ -n "$from" ] && [ -n "$url" ]; then
                # GitHub can't compare to HEAD, so the unreleased one uses its hash
                is_release "$to" || to=$(git rev-parse --short "$to")
                printf '\n**Full diff**: [%s...%s](%s/compare/%s...%s)\n' "$from" "$to" "$url" "$from" "$to"
        fi
        echo
}

# The release section for tag $1, or the unreleased one up to commit $1
one() {
        if is_release "$1"; then
                section "$1" "$(last_release "$1^")" "$1"
        else
                section Unreleased "$(last_release "$1")" "$1"
        fi
}

if [ $# -gt 0 ]; then
        git rev-parse --verify --quiet "$1^{commit}" >/dev/null || { echo "changelog: no such ref: $1" >&2; exit 1; }
        one "$1"
        exit
fi

echo "# Changelog"
echo
one HEAD
for tag in $(git tag --list --merged HEAD --sort=-v:refname); do
        if is_release "$tag"; then one "$tag"; fi
done
