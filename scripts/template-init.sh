#!/usr/bin/env bash
# Turn this template into a new project. Run it once, right after creating a
# repo from the template:
#
#   scripts/template-init.sh [NAME [DESCRIPTION]]
#
# It asks for the name, a one-line description, the GitHub repo, the author
# and their email, and the license, suggesting what it finds: NAME or the git
# repo's name, DESCRIPTION or the GitHub repo's description, origin, and git
# config. Then it asks which optional parts to keep (see parts below), and
# removes the others.
#
# Everything that names the project, its repo, its author or its license is
# a placeholder in the template: __NAME__, __DESCRIPTION__, __REPO__,
# __AUTHOR__, __EMAIL__, __YEAR__, __LICENSE__ and the variants below, and in
# Markdown text the same with every _ escaped (\_\_NAME\_\_). Nothing else
# has them, so only they get replaced, and nothing of the template's own
# details is left. Then it registers the submodules, enables the git hooks,
# deletes template/ and itself, and offers to set up the GitHub repo
# (scripts/github-setup.sh). Review and commit.
#
# If it stops halfway, running it again goes on from there, with the same
# answers: they're kept in .git/template-init until it's done.
#
# Without a terminal it takes the suggestions without asking: every part is
# kept but the ones in $TEMPLATE_WITHOUT (like "docs appimage"), and the
# license is $TEMPLATE_LICENSE (GPL-3.0-or-later if it's not set).
set -euo pipefail
cd "$(dirname "$0")/.."

die() { echo "template-init: $*" >&2; exit 1; }
# Escape for the pattern and for the replacement of a sed s///
pat() { printf '%s' "$1" | sed 's/[]\/$*.^[]/\\&/g'; }
rep() { printf '%s' "$1" | sed 's/[&/\]/\\&/g'; }

# macOS has neither by default
((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3))) ||
        die "it needs bash 4.3 or newer, this is $BASH_VERSION (on macOS: brew install bash)"
sed --version >/dev/null 2>&1 || die "it needs GNU sed (on macOS: brew install gnu-sed, with its gnubin first in PATH)"

interactive=''
if { : </dev/tty; } 2>/dev/null; then interactive=1; fi

# ask VAR QUESTION SUGGESTION CHECK: the answer, with the suggestion filled in
# (Enter takes it), asked again until `CHECK answer` prints nothing (else it
# prints what's wrong). Without a terminal, the suggestion, which must pass.
ask() {
        local -n answer=$1
        local problem
        while :; do
                if [ -n "$interactive" ]; then
                        # shellcheck disable=SC2034 # answer is the caller's variable
                        read -rep "$2: " -i "$3" answer </dev/tty || die "cancelled"
                else
                        answer=$3
                fi
                problem=$("$4" "$answer")
                [ -n "$problem" ] || return 0
                [ -n "$interactive" ] || die "$problem (run it in a terminal to answer)"
                echo "$problem"
        done
}

# confirm QUESTION: yes unless answered no
confirm() {
        local ok
        read -rp "$1 [Y/n] " ok </dev/tty || die "cancelled"
        case $ok in
        '' | [yY]*) return 0 ;;
        *) return 1 ;;
        esac
}

git rev-parse --show-toplevel >/dev/null || die "not in a git repo (git says why above)"
# The answers, once they're confirmed, until it's done
state=$(git rev-parse --git-dir)/template-init

# The template's program name, in file names
old_name=__NAME__

# The licenses it offers: LICENSE has the first one, template/licenses/ the
# others but none
licenses=(GPL-3.0-or-later MIT Apache-2.0 BSD-2-Clause MPL-2.0 none)

# The optional parts. A part is its files, the lines between its
# "template-init: begin PART" and "template-init: end PART" comments in any
# file, and the lines of README.md, CONTRIBUTING.md and src/main.c (table
# rows, code) that have its text, where a comment can't go. license isn't
# asked: it goes with no license.
parts=(docs man completions appimage static releases install hooks dependabot community macos)
declare -A part_about=(
        [docs]="the Typst manual: docs/*.typ, as PDFs in every release"
        [man]="the man page"
        [completions]="the bash, zsh and fish completion files (from flag.h's --completions), released and installed"
        [appimage]="the AppImage, built and released for x86_64 and aarch64"
        [static]="the static binary (musl), built and released for x86_64 and aarch64"
        [releases]="GitHub releases: nightly from CI, and versions and the changelog from release-please"
        [install]="the install script (curl ... | bash), attached to every release"
        [hooks]="the git hooks that check commit messages and run the tests before a push"
        [dependabot]="Dependabot: weekly pull requests updating the actions and the submodules"
        [community]="the issue forms, the pull request template and SECURITY.md"
        [macos]="the macOS build and tests in CI, for building from source there"
        [license]="LICENSE, and what says what the license is"
)
declare -A part_files=(
        [docs]="docs/manual.typ"
        [man]="docs/$old_name.1"
        [completions]="test/completions.sh"
        [appimage]="assets"
        [releases]="scripts/changelog.sh release-please-config.json .release-please-manifest.json .github/workflows/release-please.yml"
        [install]="scripts/install.sh scripts/test-install.sh"
        [hooks]="scripts/hooks"
        [dependabot]=".github/dependabot.yml"
        [community]=".github/ISSUE_TEMPLATE .github/pull_request_template.md .github/SECURITY.md"
        [license]="LICENSE"
)
# FILE<tab>TEXT: the line of FILE with TEXT in it. The project layout in
# CONTRIBUTING.md: the path, and the space after it.
declare -A part_lines=(
        [docs]=$'README.md\t| `make docs`\nREADME.md\t| `*.pdf`\nCONTRIBUTING.md\tdocs/*.typ'
        [man]=$'README.md\t| `make man`\nREADME.md\t| `__NAME__.1`\nCONTRIBUTING.md\tdocs/__NAME__.1 \nCONTRIBUTING.md\t- the man page,'
        [completions]=$'README.md\t| `make completions`\nREADME.md\t| `__NAME__-completions.tar.gz`'
        [appimage]=$'README.md\t| `make appimage`\nREADME.md\t| `__NAME__-<arch>.AppImage`\nREADME.md\tbash -s -- --appimage\nCONTRIBUTING.md\tassets/ '
        [static]=$'README.md\t| `make static`\nREADME.md\t| `__NAME__-<arch>-static`'
        [releases]=$'README.md\timg.shields.io/github/v/release\nCONTRIBUTING.md\tscripts/changelog.sh '
        [install]=$'README.md\t| `install.sh`\nCONTRIBUTING.md\tscripts/install.sh \nCONTRIBUTING.md\tscripts/test-install.sh '
        [hooks]=$'CONTRIBUTING.md\tmake hooks   # check\nCONTRIBUTING.md\tscripts/hooks/ '
        [license]=$'README.md\timg.shields.io/github/license\nsrc/main.c\tSPDX-License-Identifier'
)

# Answer checks: they print what's wrong, if anything. The binary is built at
# the top of the repo, ignored there by .gitignore, removed by `make clean`
# (rm -rf) and a make target: it can't be the name of anything else at the
# top, nor of another target. The description goes in C strings, the
# Makefile and the docs.
reserved=" build template $(sed -n 's/^\.PHONY: *//p' Makefile | tr '\n' ' ') "
check_name() {
        if ! [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
                echo "'$1' can't be a program name: letters, digits, - and _"
        elif [ -e "$1" ] || [[ $reserved == *" $1 "* ]]; then
                echo "'$1' is already a file, dir or make target here, pick another name"
        fi
}
check_desc() {
        if [ -z "$1" ]; then
                echo "the description can't be empty"
        elif [[ $1 == *[\"\\\$\`#]* ]]; then
                echo "the description can't have \" \\ \$ \` or #"
        fi
}
check_slug() {
        [[ $1 =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || echo "'$1' is not owner/repo"
}
check_author() { [ -n "$1" ] || echo "the author can't be empty"; }
check_email() { [[ $1 == ?*@?* ]] || echo "'$1' is not an email"; }
check_license() {
        local l
        for l in "${licenses[@]}"; do [ "${1,,}" != "${l,,}" ] || return 0; done
        echo "'$1' is not one of: ${licenses[*]}"
}

if [ -f "$state" ]; then
        # shellcheck source=/dev/null
        source "$state"
        echo "It stopped halfway before: going on with the same answers. To start over"
        echo "instead, restore the files from git, and delete $state."
else
        remote=$(git remote get-url origin 2>/dev/null || true)
        # owner/repo on GitHub: badges, links, install.sh. Not origin's if
        # origin is a template, like this one cloned instead of used: that's
        # not where the project goes.
        slug=$(printf '%s' "$remote" | sed -nE 's#^.*github\.com[:/]+([^/]+/[^/]+)$#\1#p' | sed 's/\.git$//')
        if [ -n "$slug" ] && [ "$(gh repo view "$slug" --json isTemplate --jq .isTemplate 2>/dev/null)" = true ]; then
                slug='' remote=''
        fi
        [ -n "$slug" ] || echo "origin is not this project's GitHub repo: say which repo the links should point to"
        name=${1:-$(basename "${slug:-${remote:-$(git rev-parse --show-toplevel)}}" .git)}
        author=$(git config user.name || true)
        email=$(git config user.email || true)
        license=${TEMPLATE_LICENSE:-${licenses[0]}}
        year=$(date +%Y)

        desc=${2:-}
        if [ -z "$desc" ] && [ -n "$slug" ] && command -v gh >/dev/null; then
                desc=$(gh repo view "$slug" --json description -q .description 2>/dev/null || true)
        fi

        [ -z "$interactive" ] || echo "Enter takes the suggestion, Ctrl-C quits"
        ask name "Program name" "$name" check_name
        ask desc "One-line description (like \"Greet everyone listed in a Lua config\")" "$desc" check_desc
        # Not on GitHub yet: where it'll most likely go
        if [ -z "$slug" ]; then
                owner=$(gh api user -q .login 2>/dev/null || true)
                slug=${owner:-${USER:-owner}}/$name
        fi
        ask slug "GitHub repo (owner/repo)" "$slug" check_slug
        ask author "Author" "$author" check_author
        ask email "Author's email (also where SECURITY.md sends reports)" "$email" check_email
        [ -z "$interactive" ] || cat <<'EOF'
Licenses: GPL-3.0-or-later (who shares it, changed or not, shares its source
too, under the same license), MPL-2.0 (the same, but file by file), MIT and
BSD-2-Clause (anyone can do anything with it, keeping the copyright notice),
Apache-2.0 (the same, with a patent license), or none (no one else may use,
change or share it).
EOF
        ask license "License (${licenses[*]})" "$license" check_license
        for l in "${licenses[@]}"; do [ "${license,,}" != "${l,,}" ] || license=$l; done

        # Which parts to keep: every one, but those in $TEMPLATE_WITHOUT
        declare -A keep
        for part in "${parts[@]}"; do keep[$part]=1; done
        without=${TEMPLATE_WITHOUT:-}
        for part in ${without//,/ }; do
                [[ " ${parts[*]} " == *" $part "* ]] || die "TEMPLATE_WITHOUT: no part called '$part' (${parts[*]})"
                keep[$part]=''
        done
        [ -z "$interactive" ] || echo "Which parts to keep? Enter keeps it, n removes it"
        for part in "${parts[@]}"; do
                # The install script installs a release's binary
                if [ "$part" = install ] && { [ -z "${keep[releases]}" ] || [ -z "${keep[appimage]}${keep[static]}" ]; }; then
                        keep[install]=''
                        [ -z "$interactive" ] || echo "  install: removed too, it needs releases and a binary to install"
                        continue
                fi
                [ -n "$interactive" ] || continue
                if [ -n "${keep[$part]}" ]; then default=Y/n; else default=y/N; fi
                read -rp "  $part, ${part_about[$part]}? [$default] " ok </dev/tty || die "cancelled"
                case $ok in
                [yY]*) keep[$part]=1 ;;
                [nN]*) keep[$part]='' ;;
                esac
        done
        keep[license]=1
        [ "$license" != none ] || keep[license]=''

        desc=${desc%.}
        desc=${desc^}
        # For the man page and comments: "foo - do things", unless it starts
        # with an acronym
        desc_lower=$desc
        [[ ${desc:1:1} != [[:lower:]] ]] || desc_lower=${desc,}
fi

kept='' removed=''
for part in "${parts[@]}"; do
        if [ -n "${keep[$part]}" ]; then kept+=" $part"; else removed+=" $part"; fi
done

echo
echo "name:        $name"
echo "description: $desc"
echo "repo:        $slug"
echo "author:      $author <$email>"
echo "license:     $license"
echo "keeps:      ${kept:- nothing optional}"
echo "removes:    ${removed:- nothing}"
if [ -n "$interactive" ] && ! [ -f "$state" ]; then
        confirm "Initialize the project with these?" || die "cancelled"
fi

# If anything fails from here, running it again goes on where it stopped,
# with the same answers: every step is skipped once done
declare -p name desc desc_lower slug author email license year keep >"$state"
trap 'echo "template-init: stopped halfway. Fix what it says above and run it again, it goes on from there." >&2' ERR

# Submodules first, as they need the network: a copy of the template may have
# them registered or not
for lib in flag cum conf; do
        path=src/thirdparty/$lib
        git ls-files --stage -- "$path" | grep -q '^160000' ||
                git submodule add "https://github.com/hugoocoto/$lib.h" "$path"
done
git submodule update --init

# The README part about using the template
sed -i '/<!-- template-init: remove from here -->/,/<!-- template-init: to here -->/d' README.md

# The parts, unless done already (no marker is left then). Lines first: a
# block removed after can have some of them.
gone=$removed
[ -n "${keep[license]}" ] || gone+=" license"
mapfile -t marked < <(grep -rIlE --exclude-dir=.git --exclude-dir=thirdparty --exclude-dir=build \
        --exclude-dir=template --exclude="$(basename "$0")" 'template-init: (begin|end) [a-z]+' . || true)
if [ ${#marked[@]} != 0 ]; then
        for part in $gone; do
                while IFS=$'\t' read -r file text; do
                        [ -n "$file" ] || continue
                        if grep -qF -- "$text" "$file"; then
                                grep -vF -- "$text" "$file" >"$file.new" && mv "$file.new" "$file"
                        else
                                echo "warning: $part: no line with '$text' in $file to remove" >&2
                        fi
                done <<<"${part_lines[$part]:-}"
        done
        for part in "${parts[@]}" license; do
                if [ -n "${keep[$part]}" ]; then
                        sed -i -E "/template-init: (begin|end) $part\b/d" "${marked[@]}"
                else
                        sed -i "/template-init: begin $part\b/,/template-init: end $part\b/d" "${marked[@]}"
                fi
        done
        # Their files last: some of them have markers, which the loop edits
        for part in $gone; do
                # shellcheck disable=SC2086 # a list of paths
                rm -rf ${part_files[$part]:-}
        done
        # What a removed block leaves: two blank lines where it was
        for f in "${marked[@]}"; do
                [ ! -f "$f" ] || sed -i '/^$/N;/^\n$/D' "$f"
        done
        rmdir docs 2>/dev/null || true
fi

# LICENSE has the first license, template/licenses/ the others
if [ "$license" != none ] && [ "$license" != "${licenses[0]}" ]; then
        cp "template/licenses/$license.txt" LICENSE
fi

# Every placeholder, and what it becomes. In Markdown text, every _ is
# escaped, or __NAME__ would be NAME in bold.
declare -A value=(
        [__NAME__]=$name
        [__NAME_UPPER__]=${name^^}
        [__DESCRIPTION__]=$desc
        [__DESCRIPTION_LOWER__]=$desc_lower
        [__REPO__]=$slug
        [__AUTHOR__]=$author
        [__EMAIL__]=$email
        [__YEAR__]=$year
        [__LICENSE__]=$license
)
tokens=() exprs=()
for token in "${!value[@]}"; do
        md=${token//_/\\_}
        tokens+=(-e "$token" -e "$md")
        exprs+=(-e "s/$(pat "$token")/$(rep "${value[$token]}")/g" -e "s/$(pat "$md")/$(rep "${value[$token]}")/g")
done
# Every text file with one, but the template's own
mapfile -t files < <(grep -rIlF --exclude-dir=.git --exclude-dir=thirdparty --exclude-dir=build \
        --exclude-dir=template --exclude="$(basename "$0")" "${tokens[@]}" . || true)
[ ${#files[@]} = 0 ] || sed -i "${exprs[@]}" "${files[@]}"

# Renamed already, on a run that stopped halfway, is done
move() {
        if [ -e "$1" ]; then
                git mv -f "$1" "$2" 2>/dev/null || mv "$1" "$2"
        elif ! [ -e "$2" ]; then
                echo "template-init: neither $1 nor $2 exist" >&2
                return 1
        fi
}
[ -z "${keep[man]}" ] || move "docs/$old_name.1" "docs/$name.1"
rm -f "$old_name"

[ -z "${keep[hooks]}" ] || git config core.hooksPath scripts/hooks
trap - ERR

# What's left of the template is worth a look: a placeholder misspelled, or
# a marker
left=$(grep -rInF --exclude-dir=.git --exclude-dir=thirdparty --exclude-dir=build \
        --exclude-dir=template --exclude="$(basename "$0")" "${tokens[@]}" \
        -e 'template-init: begin' -e 'template-init: end' -e 'template-init: remove' . || true)
# The template's own files, then this one: it's done
rm -rf template .github/workflows/template.yml "$state"
rm -- "$0"

echo
echo "Done: ${#files[@]} files updated."
if [ -n "$left" ]; then
        echo "These lines still look like the template:"
        printf '%s\n' "$left" | sed 's/^/  /'
fi
if [ -n "$interactive" ]; then
        if confirm "Build it and run '$name --version' to check?"; then
                if make --no-print-directory && "./$name" --version; then
                        echo "It builds and runs."
                else
                        echo "It doesn't build or run: see above."
                fi
        fi
        if ! command -v gh >/dev/null; then
                echo "To set up the GitHub repo later, install gh (https://cli.github.com) and run scripts/github-setup.sh"
        elif confirm "Set up the GitHub repo $slug now? scripts/github-setup.sh asks about each setting, and you can run it later too"; then
                scripts/github-setup.sh "$slug" || echo "The GitHub setup didn't finish: run scripts/github-setup.sh again once it's fixed"
        fi
fi
echo "Review the changes with 'git status' and 'git diff', and commit. What's left"
echo "is your program: src/, test/, config.lua and what describes it, which"
echo "Documentation in CONTRIBUTING.md lists."
