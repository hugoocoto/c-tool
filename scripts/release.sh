#!/usr/bin/env bash
# Tag HEAD as vX.Y.Z and push the tag: CI then builds and publishes the
# release. It asks for the version, suggesting the next one from the commits
# since the last release (or $1), and it must be bigger than every v* tag that
# already exists, here or on origin.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { echo "release: $*" >&2; exit 1; }

interactive=''
if { : </dev/tty; } 2>/dev/null; then interactive=1; fi

# ask VAR QUESTION SUGGESTION: the answer, with the suggestion filled in
# (Enter takes it). Without a terminal, the suggestion.
ask() {
        local -n answer=$1
        if [ -z "$interactive" ]; then
                answer=$3
                return
        fi
        # shellcheck disable=SC2034 # answer is the caller's variable
        read -rep "$2: " -i "$3" answer </dev/tty || die "cancelled"
}

# bump X.Y.Z PART: the version after X.Y.Z, PART being major, minor or patch
bump() {
        local major minor patch
        IFS=. read -r major minor patch <<<"$1"
        case $2 in
        major) echo "$((major + 1)).0.0" ;;
        minor) echo "$major.$((minor + 1)).0" ;;
        patch) echo "$major.$minor.$((patch + 1))" ;;
        esac
}

git fetch --tags --quiet origin || die "can't fetch tags from origin"

branch=$(git branch --show-current)
[ "$branch" = main ] || die "on '$branch', releases are made from main"
[ -z "$(git status --porcelain --untracked-files=no)" ] || die "uncommitted changes"
git fetch --quiet origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] ||
        die "HEAD is not origin/main: push or pull first"

latest=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' | sed 's/^v//' | sort -V | tail -1)
changes=$(scripts/changelog.sh HEAD)
[ -n "$changes" ] || die "nothing to release: no commits since v$latest"

# The suggestion, from the changelog's groups (scripts/changelog.sh): removing
# things breaks what used them (but before 1.0.0, minor versions can break),
# adding things is minor, the rest a patch
if [ -z "$latest" ]; then
        part=first suggestion=0.1.0
else
        if grep -q '^### Removed' <<<"$changes"; then
                part=major why="it removes things"
                [ "${latest%%.*}" != 0 ] || part=minor why="it removes things, and it's before 1.0.0"
        elif grep -q '^### Added' <<<"$changes"; then
                part=minor why="it adds things"
        else
                part=patch why="it only changes and fixes things"
        fi
        suggestion=$(bump "$latest" "$part")
fi
echo "Latest release: ${latest:+v$latest}${latest:-none}"
if [ -n "${1:-}" ]; then
        suggestion=${1#v}
elif [ "$part" != first ]; then
        echo "Suggested: v$suggestion, a $part release: $why"
fi

while :; do
        ask version "New version (X.Y.Z, or major, minor, patch)" "$suggestion"
        version=${version#v}
        case $version in
        major | minor | patch) version=$(bump "${latest:-0.0.0}" "$version") ;;
        esac
        problem=''
        if ! [[ $version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
                problem="'$version' is not X.Y.Z"
        elif [ -n "$latest" ] && { [ "$latest" = "$version" ] ||
                [ "$(printf '%s\n%s\n' "$latest" "$version" | sort -V | tail -1)" != "$version" ]; }; then
                problem="v$version is not bigger than v$latest"
        fi
        [ -n "$problem" ] || break
        [ -n "$interactive" ] || die "$problem"
        echo "$problem"
done

echo
printf '%s\n' "$changes" | sed "1s/.*/## v$version (changelog and release notes)/"
echo
[ -n "$interactive" ] || die "pushing a release tag needs a terminal, to confirm it"
read -rp "Tag $(git rev-parse --short HEAD) as v$version and push it? [y/N] " ok </dev/tty
[ "$ok" = y ] || [ "$ok" = Y ] || die "cancelled"

git tag -a "v$version" -m "v$version"
git push origin "v$version"
echo "Pushed v$version. CI publishes the release: $(gh repo view --json url -q .url 2>/dev/null || echo "see GitHub")/actions"
