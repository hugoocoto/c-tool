#!/usr/bin/env bash
# Check scripts/template-init.sh: run it on copies of the template, keeping
# every part, without each one, without any, and with each license, and check
# what each makes: it builds and passes its tests, actionlint and shellcheck
# take it, the make targets the docs and CI mention exist, the removed parts
# and the template's own files are gone, and no placeholder, marker or detail
# of the template's own repo is left. Then that running it again after it
# stopped halfway goes on with the first answers.
#
#   template/test.sh [CASE...]   only these cases ("PARTS:LICENSE", see cases)
#
# CI runs it on every change to the template (.github/workflows/template.yml),
# and template-init deletes it. It needs what the project needs to build and
# test, shellcheck and actionlint; zsh and fish if they're to be tried too.
set -euo pipefail
cd "$(dirname "$0")/.."
template=$PWD

# The parts to remove (, between them, - for none), and the license
cases=(
        "-:GPL-3.0-or-later"
        "docs:MIT"
        "man:none"
        "completions:Apache-2.0"
        "appimage:BSD-2-Clause"
        "static:MPL-2.0"
        "releases:GPL-3.0-or-later"
        "install:MIT"
        "hooks:none"
        "dependabot:GPL-3.0-or-later"
        "community:MIT"
        "macos:Apache-2.0"
        "appimage,static:GPL-3.0-or-later"
        "docs,man,completions,appimage,static,releases,install,hooks,dependabot,community,macos:none"
)
[ $# = 0 ] || cases=("$@")

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failed=()

# A copy of the template, git repo and all, with git set up as a new
# project's would be: init suggests what it finds there
copy() {
        local dir=$tmp/$1
        mkdir -p "$dir" &&
                tar -C "$template" -cf - --exclude=./build . | tar -xf - -C "$dir" &&
                git -C "$dir" config user.name "Ada Lovelace" &&
                git -C "$dir" config user.email ada@example.com &&
                { git -C "$dir" remote set-url origin https://github.com/ada/my-tool.git 2>/dev/null ||
                        git -C "$dir" remote add origin https://github.com/ada/my-tool.git; } &&
                echo "$dir"
}

# init DIR PARTS LICENSE: template-init in DIR, without a terminal
init() {
        local run=()
        command -v setsid >/dev/null && run=(setsid -w)
        (cd "$1" && TEMPLATE_WITHOUT=${2//,/ } TEMPLATE_LICENSE=$3 \
                ${run[@]+"${run[@]}"} bash scripts/template-init.sh my-tool "Do things" </dev/null 2>&1)
}

# What every project gets, and what its parts add
always="README.md CONTRIBUTING.md Makefile src/main.c test/docs.sh test/check-commit.sh scripts/test.sh scripts/check-commit.sh scripts/github-setup.sh .github/workflows/ci.yml .github/workflows/commit-title.yml"
declare -A part_files=(
        [docs]=docs/manual.typ [man]=docs/my-tool.1 [completions]=test/completions.sh
        [appimage]=assets/icon.svg [releases]=.github/workflows/release-please.yml [install]=scripts/install.sh
        [hooks]=scripts/hooks/commit-msg [dependabot]=.github/dependabot.yml
        [community]=.github/SECURITY.md
)
declare -A license_heading=(
        [GPL-3.0-or-later]="GNU GENERAL PUBLIC LICENSE" [MIT]="MIT License"
        [Apache-2.0]="Apache License" [BSD-2-Clause]="BSD 2-Clause License"
        [MPL-2.0]="Mozilla Public License Version 2.0"
)

# check DIR PARTS LICENSE: what init made in DIR, without PARTS. Prints
# what's wrong.
check() {
        local dir=$1 license=$3 part file target found
        local -a without
        IFS=, read -ra without <<<"${2#-}"
        # install goes with releases, or with both binaries
        if [[ " ${without[*]} " == *" releases "* ]] ||
                [[ " ${without[*]} " == *" appimage "* && " ${without[*]} " == *" static "* ]]; then
                without+=(install)
        fi
        cd "$dir"

        make -s WERROR=1 >/dev/null 2>&1 || echo "it doesn't build"
        make -s test 2>&1 | tail -1 | grep -q ' 0 failed' || echo "its tests fail: $(make -s test 2>&1 | grep FAIL)"
        SHELLCHECK_OPTS=--severity=warning actionlint .github/workflows/*.yml || echo "actionlint fails"
        find scripts test -type f \( -path 'scripts/*' -o -name '*.sh' \) -exec shellcheck {} + || echo "shellcheck fails"

        # Every `make X` the docs and CI run: in backquotes, or first in a
        # line or a run:
        targets=$(make -pRrq : 2>/dev/null | grep -oE '^[a-z][a-z-]*:' | tr -d :)
        grep -ohE '(`|^[[:space:]]*(run: )?)g?make( -s)? [a-z][a-z-]+' .github/workflows/*.yml README.md CONTRIBUTING.md |
                awk '{print $NF}' | sort -u |
                while read -r target; do
                        grep -qx "$target" <<<"$targets" || echo "no make target $target, which the docs or CI mention"
                done

        # Placeholders, markers and the template itself
        found=$(grep -rnIE --exclude-dir=.git --exclude-dir=thirdparty --exclude-dir=build --exclude=.gitmodules \
                '__(NAME|NAME_UPPER|DESCRIPTION|DESCRIPTION_LOWER|REPO|AUTHOR|EMAIL|YEAR|LICENSE)__|\\_\\_[A-Z]|template-init|hugoocoto|c-tool|Hugo|Coto|Florez|gmail' . || true)
        [ -z "$found" ] || echo "the template is left in: $found"
        for file in template .github/workflows/template.yml scripts/template-init.sh .git/template-init; do
                [ ! -e "$file" ] || echo "$file is still there"
        done

        # The parts' files, and the ones every project has
        for file in $always; do [ -e "$file" ] || echo "$file is missing"; done
        for part in "${!part_files[@]}"; do
                if [[ " ${without[*]} " == *" $part "* ]]; then
                        [ ! -e "${part_files[$part]}" ] || echo "$part was removed, but ${part_files[$part]} is there"
                else
                        [ -e "${part_files[$part]}" ] || echo "$part was kept, but ${part_files[$part]} is missing"
                fi
        done

        # The license, everywhere it's said
        if [ "$license" = none ]; then
                [ ! -e LICENSE ] || echo "no license, but LICENSE is there"
                ! grep -q SPDX-License-Identifier src/main.c || echo "no license, but src/main.c has an SPDX line"
                ! grep -q 'img.shields.io/github/license' README.md || echo "no license, but the README has its badge"
                ! grep -q '^## License' CONTRIBUTING.md || echo "no license, but CONTRIBUTING.md has a License section"
        else
                [ "$(head -1 LICENSE | sed 's/^ *//')" = "${license_heading[$license]}" ] || echo "LICENSE isn't $license: $(head -1 LICENSE)"
                ! grep -q '__\|\[year\]\|\[fullname\]' LICENSE || echo "LICENSE has placeholders left"
                grep -qx "// SPDX-License-Identifier: $license" src/main.c || echo "src/main.c's SPDX line isn't $license"
                grep -q "^$license, see \[LICENSE\](LICENSE)" README.md || echo "the README doesn't say the license is $license"
        fi
        grep -q "Copyright (C) $(date +%Y) Ada Lovelace" README.md || echo "the README's copyright isn't Ada Lovelace's"
        if [ -e .github/SECURITY.md ]; then
                grep -q 'ada@example.com' .github/SECURITY.md || echo "SECURITY.md doesn't have the author's email"
                grep -q 'github.com/ada/my-tool/security' .github/SECURITY.md || echo "SECURITY.md doesn't link to the repo"
        fi
        grep -q 'github.com/ada/my-tool' README.md || echo "the README doesn't link to the repo"
}

for case in "${cases[@]}"; do
        parts=${case%%:*} license=${case#*:}
        echo "== without ${parts}, license $license"
        dir=$(copy "case-${parts//,/-}-$license") || exit 1
        if ! out=$(init "$dir" "${parts#-}" "$license"); then
                printf '%s\n' "$out" | sed 's/^/  /'
                failed+=("$case")
                continue
        fi
        problems=$(check "$dir" "$parts" "$license"
                printf '%s\n' "$out" | grep -E '^warning:|still look like the template' || true)
        if [ -n "$problems" ]; then
                printf '%s\n' "$problems" | sed 's/^/  /'
                failed+=("$case")
        else
                echo "  ok"
        fi
        rm -rf "$dir"
done

# Stopped halfway (git config fails), then run again with other answers: it
# goes on with the first ones
if [ $# = 0 ]; then
        echo "== stopped halfway, then run again"
        dir=$(copy resume) || exit 1
        real_git=$(command -v git)
        mkdir -p "$tmp/bin"
        # git, but config core.hooksPath fails while $tmp/fail is there
        cat >"$tmp/bin/git" <<EOF
#!/bin/sh
[ "\$1 \$2" = "config core.hooksPath" ] && [ -e "$tmp/fail" ] && exit 1
exec "$real_git" "\$@"
EOF
        chmod +x "$tmp/bin/git"
        touch "$tmp/fail"
        problems=''
        if PATH=$tmp/bin:$PATH init "$dir" man none >/dev/null; then
                problems+="it didn't stop"$'\n'
        fi
        rm "$tmp/fail"
        out=$(PATH=$tmp/bin:$PATH init "$dir" docs MIT) || problems+="the second run failed: $out"$'\n'
        grep -q 'going on with the same answers' <<<"$out" || problems+="the second run didn't go on"$'\n'
        problems+=$(check "$dir" man none)
        if [ -n "$problems" ]; then
                printf '%s\n' "$problems" | sed 's/^/  /'
                failed+=(resume)
        else
                echo "  ok"
        fi
fi

echo "${#failed[@]} failed${failed[*]:+: ${failed[*]}}"
[ ${#failed[@]} = 0 ]
