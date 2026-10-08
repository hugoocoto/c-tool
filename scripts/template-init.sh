#!/usr/bin/env bash
# Turn this template into a new project. Run it once, right after creating a
# repo from the template:
#
#   scripts/template-init.sh [NAME [DESCRIPTION]]
#
# It asks for the name, a one-line description, the GitHub repo and the
# author, suggesting what it finds: NAME or the git repo's name, DESCRIPTION
# or the GitHub repo's description, origin, and git config. Then it asks which
# optional parts to keep (see parts below), and removes the others.
#
# Every placeholder in every file is then replaced, so everything names the
# new project. The program's name is __NAME__ in the template (and
# __NAME_UPPER__, __NAME_ID__ where it can't have a -, \_\_NAME\_\_ in Markdown
# text), a token nothing else has, so only it gets replaced. The rest are the
# template's own values, unique enough as they are. Then it registers the
# submodules, enables the git hooks and deletes itself. Review and commit.
#
# Without a terminal it takes the suggestions without asking: every part is
# kept, but the ones in $TEMPLATE_WITHOUT (like "docs appimage").
set -euo pipefail
cd "$(dirname "$0")/.."

die() { echo "template-init: $*" >&2; exit 1; }
# Escape for the pattern and for the replacement of a sed s///
pat() { printf '%s' "$1" | sed 's/[]\/$*.^[]/\\&/g'; }
rep() { printf '%s' "$1" | sed 's/[&/\]/\\&/g'; }

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

# The placeholders, as they are in the template
old_name=__NAME__
old_upper=__NAME_UPPER__
old_id=__NAME_ID__
old_md='\_\_NAME\_\_'
old_slug=hugoocoto/c-tool
old_author="Hugo Coto Florez"
old_email=hugocoto100305@gmail.com
old_desc="Greet everyone listed in a Lua config"

git rev-parse --show-toplevel >/dev/null || die "not in a git repo (git says why above)"
remote=$(git remote get-url origin 2>/dev/null || true)

# The binary is built at the top of the repo, ignored there by .gitignore,
# removed by `make clean` (rm -rf) and a make target: it can't be the name of
# anything else at the top, nor of another target
reserved=" build $(sed -n 's/^\.PHONY: *//p' Makefile | tr '\n' ' ') "
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
        elif [[ $1 == *[\"\\\$\`]* ]]; then
                echo "the description can't have \" \\ \$ or \`"
        fi
}
check_slug() {
        [[ $1 =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || echo "'$1' is not owner/repo"
}
check_author() { [ -n "$1" ] || echo "the author can't be empty"; }
check_email() { [[ $1 == ?*@?* ]] || echo "'$1' is not an email"; }

name=${1:-$(basename "${remote:-$(git rev-parse --show-toplevel)}" .git)}
# owner/repo on GitHub: badges, links, install.sh
slug=$(printf '%s' "$remote" | sed -nE 's#^.*github\.com[:/]+([^/]+/[^/]+)$#\1#p' | sed 's/\.git$//')
[ -n "$slug" ] || echo "origin is not on GitHub: say which repo the links should point to"
author=$(git config user.name || echo "$old_author")
email=$(git config user.email || echo "$old_email")
year=$(date +%Y)

desc=${2:-}
if [ -z "$desc" ] && [ -n "$slug" ] && command -v gh >/dev/null; then
        desc=$(gh repo view "$slug" --json description -q .description 2>/dev/null || true)
fi

[ -z "$interactive" ] || echo "Enter takes the suggestion, Ctrl-C quits"
ask name "Program name" "$name" check_name
ask desc "One-line description (like \"$old_desc\")" "$desc" check_desc
# Not on GitHub yet: where it'll most likely go
if [ -z "$slug" ]; then
        owner=$(gh api user -q .login 2>/dev/null || true)
        slug=${owner:-${USER:-owner}}/$name
fi
ask slug "GitHub repo (owner/repo)" "$slug" check_slug
ask author "Author" "$author" check_author
ask email "Author's email" "$email" check_email

# The optional parts. A part is its files, the lines between its
# "template-init: begin PART" and "template-init: end PART" comments in any
# file, and the lines of README.md and CONTRIBUTING.md (table rows, code)
# that have its text, where a comment can't go.
parts=(docs man completions appimage static releases install hooks dependabot community)
declare -A part_about=(
        [docs]="the Typst manual: docs/*.typ, as PDFs in every release"
        [man]="the man page"
        [completions]="the bash, zsh and fish completions"
        [appimage]="the AppImage, built and released for x86_64 and aarch64"
        [static]="the static binary (musl), built and released for x86_64 and aarch64"
        [releases]="GitHub releases: nightly and vX.Y.Z from CI, scripts/release.sh and the changelog"
        [install]="the install script (curl ... | bash), attached to every release"
        [hooks]="the git pre-push hook that runs the tests"
        [dependabot]="Dependabot: weekly pull requests updating the actions and the submodules"
        [community]="the issue forms, the pull request template and SECURITY.md"
)
declare -A part_files=(
        [docs]="docs/manual.typ"
        [man]="docs/$old_name.1"
        [completions]="completions"
        [appimage]="assets"
        [releases]="scripts/release.sh scripts/changelog.sh"
        [install]="scripts/install.sh"
        [hooks]="scripts/hooks"
        [dependabot]=".github/dependabot.yml"
        [community]=".github/ISSUE_TEMPLATE .github/pull_request_template.md .github/SECURITY.md"
)
# FILE<tab>TEXT: the line of FILE with TEXT in it
declare -A part_lines=(
        [docs]=$'README.md\t| `make docs`\nREADME.md\t| `*.pdf`\nCONTRIBUTING.md\tdocs/*.typ'
        [man]=$'README.md\t| `make man`\nREADME.md\t| `__NAME__.1`\nCONTRIBUTING.md\tdocs/__NAME__.1      the man page\nCONTRIBUTING.md\t- the man page,'
        [completions]=$'README.md\t| `make completions`\nREADME.md\t| `__NAME__-completions.tar.gz`\nCONTRIBUTING.md\tcompletions/         bash\nCONTRIBUTING.md\t- the three files in `completions/`'
        [appimage]=$'README.md\t| `make appimage`\nREADME.md\t| `__NAME__-<arch>.AppImage`\nREADME.md\tbash -s -- --appimage\nCONTRIBUTING.md\tassets/              the AppImage icon'
        [static]=$'README.md\t| `make static`\nREADME.md\t| `__NAME__-<arch>-static`'
        [releases]=$'README.md\t| `make changelog`\nREADME.md\timg.shields.io/github/v/release\nCONTRIBUTING.md\tscripts/release.sh   tags'
        [install]=$'README.md\t| `install.sh`\nCONTRIBUTING.md\tscripts/install.sh   the install'
        [hooks]=$'CONTRIBUTING.md\tmake hooks   # run\nCONTRIBUTING.md\tscripts/hooks/       git hooks'
)

# Which to keep: every one, but those in $TEMPLATE_WITHOUT
declare -A keep
for part in "${parts[@]}"; do keep[$part]=1; done
without=${TEMPLATE_WITHOUT:-}
for part in ${without//,/ }; do
        [ -n "${part_about[$part]:-}" ] || die "TEMPLATE_WITHOUT: no part called '$part' (${parts[*]})"
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
kept='' removed=''
for part in "${parts[@]}"; do
        if [ -n "${keep[$part]}" ]; then kept+=" $part"; else removed+=" $part"; fi
done

desc=${desc%.}
desc=${desc^}
# For the man page and comments: "foo - do things", unless it starts with
# an acronym
desc_lower=$desc
[[ ${desc:1:1} != [[:lower:]] ]] || desc_lower=${desc,}

echo
echo "name:        $name"
echo "description: $desc"
echo "repo:        $slug"
echo "author:      $author <$email>"
echo "keeps:      ${kept:- nothing optional}"
echo "removes:    ${removed:- nothing}"
if [ -n "$interactive" ]; then
        read -rp "Initialize the project with these? [Y/n] " ok </dev/tty
        [ "${ok:-y}" = y ] || [ "${ok:-y}" = Y ] || die "cancelled"
fi

# If anything fails from here, running it again goes on where it stopped:
# every step is skipped once done
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
mapfile -t marked < <(grep -rIlE --exclude-dir=.git --exclude-dir=thirdparty --exclude-dir=build \
        --exclude="$(basename "$0")" 'template-init: (begin|end) [a-z]+' . || true)
if [ ${#marked[@]} != 0 ]; then
        for part in $removed; do
                while IFS=$'\t' read -r file text; do
                        [ -n "$file" ] || continue
                        if grep -qF -- "$text" "$file"; then
                                grep -vF -- "$text" "$file" >"$file.new" && mv "$file.new" "$file"
                        else
                                echo "warning: $part: no line with '$text' in $file to remove" >&2
                        fi
                done <<<"${part_lines[$part]:-}"
        done
        for part in "${parts[@]}"; do
                if [ -n "${keep[$part]}" ]; then
                        sed -i -E "/template-init: (begin|end) $part\b/d" "${marked[@]}"
                else
                        sed -i "/template-init: begin $part\b/,/template-init: end $part\b/d" "${marked[@]}"
                fi
        done
        # Their files last: some of them have markers, which the loop edits
        for part in $removed; do
                # shellcheck disable=SC2086 # a list of paths
                rm -rf ${part_files[$part]:-}
        done
        # What a removed block leaves: two blank lines where it was
        for f in "${marked[@]}"; do
                [ ! -f "$f" ] || sed -i '/^$/N;/^\n$/D' "$f"
        done
        rmdir docs 2>/dev/null || true
fi

# Every text file with a placeholder, except the ones that aren't ours
mapfile -t files < <(grep -rIl --exclude-dir=.git --exclude-dir=thirdparty --exclude-dir=build \
        --exclude=LICENSE --exclude=.clang-format --exclude="$(basename "$0")" \
        -e "__NAME" -e 'NAME\\_\\_' -e "$old_slug" -e "$old_author" -e "$old_email" \
        -e "$old_desc" -e "${old_desc,}" . || true)

[ ${#files[@]} = 0 ] || sed -i \
        -e "s/$(pat "$old_slug")/$(rep "$slug")/g" \
        -e "s/Copyright (C) [0-9]\{4\} $(pat "$old_author")/Copyright (C) $year $(rep "$author")/g" \
        -e "s/$(pat "$old_author")/$(rep "$author")/g" \
        -e "s/$(pat "$old_email")/$(rep "$email")/g" \
        -e "s/$(pat "$old_desc")/$(rep "$desc")/g" \
        -e "s/$(pat "${old_desc,}")/$(rep "$desc_lower")/g" \
        -e "s/$old_id/${name//-/_}/g" \
        -e "s/$old_upper/${name^^}/g" \
        -e "s/$(pat "$old_md")/$name/g" \
        -e "s/$old_name/$name/g" \
        "${files[@]}"

# Renamed already, on a run that stopped halfway, is done
move() {
        if [ -e "$1" ]; then
                git mv -f "$1" "$2" 2>/dev/null || mv "$1" "$2"
        elif ! [ -e "$2" ]; then
                echo "template-init: neither $1 nor $2 exist" >&2
                return 1
        fi
}
renames=()
[ -z "${keep[man]}" ] || renames+=("docs/$old_name.1")
[ -z "${keep[completions]}" ] || renames+=("completions/$old_name.bash" "completions/_$old_name" "completions/$old_name.fish")
for f in "${renames[@]}"; do
        move "$f" "${f//$old_name/$name}"
done
rm -f "$old_name"

[ -z "${keep[hooks]}" ] || git config core.hooksPath scripts/hooks
trap - ERR

# What's left of the template is worth a look: a token misspelled, or one of
# its values written differently
left=$(grep -rInE --exclude-dir=.git --exclude-dir=thirdparty --exclude-dir=build \
        --exclude=LICENSE --exclude=.clang-format --exclude="$(basename "$0")" \
        -e "__NAME" -e 'NAME\\_\\_' -e "$old_slug" -e "$old_author" -e "$old_email" -e "$old_desc" \
        -e 'template-init: (begin|end)' . || true)
rm -- "$0"

echo
echo "Done: ${#files[@]} files updated."
if [ -n "$left" ]; then
        echo "These lines still look like the template:"
        printf '%s\n' "$left" | sed 's/^/  /'
fi
if [ -n "$interactive" ]; then
        read -rp "Build it and run '$name --version' to check? [Y/n] " ok </dev/tty
        if [ "${ok:-y}" = y ] || [ "${ok:-y}" = Y ]; then
                if make --no-print-directory && "./$name" --version; then
                        echo "It builds and runs."
                else
                        echo "It doesn't build or run: see above."
                fi
        fi
fi
echo "Review the changes with 'git status' and 'git diff', and commit. What's left"
echo "is your program: src/, test/, config.lua and what describes it, which"
echo "Documentation in CONTRIBUTING.md lists."
