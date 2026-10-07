#!/usr/bin/env bash
# Tag HEAD as vX.Y.Z and push the tag: CI then builds and publishes the
# release. The version is asked for (or given as $1), and it must be bigger
# than every v* tag that already exists, here or on origin.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { echo "release: $*" >&2; exit 1; }

git fetch --tags --quiet origin || die "can't fetch tags from origin"

latest=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' | sed 's/^v//' | sort -V | tail -1)
echo "Latest release: ${latest:+v$latest}${latest:-none}"

version=${1:-}
[ -n "$version" ] || read -rp "New version (X.Y.Z): " version
version=${version#v}

[[ $version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
        die "'$version' is not X.Y.Z"
if [ -n "$latest" ] && [ "$(printf '%s\n%s\n' "$latest" "$version" | sort -V | tail -1)" != "$version" ] ||
        [ "$latest" = "$version" ]; then
        die "v$version is not bigger than v$latest"
fi

branch=$(git branch --show-current)
[ "$branch" = main ] || die "on '$branch', releases are made from main"
[ -z "$(git status --porcelain --untracked-files=no)" ] || die "uncommitted changes"
git fetch --quiet origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] ||
        die "HEAD is not origin/main: push or pull first"

changes=$(scripts/changelog.sh HEAD)
[ -n "$changes" ] || die "nothing to release: no commits since v$latest"
echo
printf '%s\n' "$changes" | sed "1s/.*/## v$version (changelog and release notes)/"
echo
read -rp "Tag $(git rev-parse --short HEAD) as v$version and push it? [y/N] " ok
[ "$ok" = y ] || [ "$ok" = Y ] || die "cancelled"

git tag -a "v$version" -m "v$version"
git push origin "v$version"
echo "Pushed v$version. CI publishes the release: $(gh repo view --json url -q .url 2>/dev/null || echo "see GitHub")/actions"
