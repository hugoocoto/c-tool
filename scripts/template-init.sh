#!/usr/bin/env bash
# Turn this template into a new project. Run it once, right after creating a
# repo from the template:
#
#   scripts/template-init.sh [NAME [DESCRIPTION]]
#
# It asks for the name, a one-line description, the GitHub repo and the
# author, suggesting what it finds: NAME or the git repo's name, DESCRIPTION
# or the GitHub repo's description, origin, and git config. Every placeholder
# in every file is then replaced, so the code, the docs, the man page, the
# completions, install.sh, the issue forms and the README all name the new
# project. Then it registers the submodules, enables the git hooks and
# deletes itself. Review and commit. Without a terminal it takes the
# suggestions without asking.
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
old_name=template
old_slug=hugoocoto/c-tool
old_author="Hugo Coto Florez"
old_email=hugocoto100305@gmail.com
old_desc="Greet everyone listed in a Lua config"

git rev-parse --show-toplevel >/dev/null || die "not in a git repo (git says why above)"
remote=$(git remote get-url origin 2>/dev/null || true)

check_name() {
        if ! [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
                echo "'$1' can't be a program name: letters, digits, - and _"
        elif [ "$1" = "$old_name" ]; then
                echo "that's the template's name, pick the new one"
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
[ "$name" != "$old_name" ] || name=''
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
if [ -n "$interactive" ]; then
        read -rp "Initialize the project with these? [Y/n] " ok </dev/tty
        [ "${ok:-y}" = y ] || [ "${ok:-y}" = Y ] || die "cancelled"
fi

# The README part about using the template
sed -i '/<!-- template-init: remove from here -->/,/<!-- template-init: to here -->/d' README.md

# Every text file with a placeholder, except the ones that aren't ours
mapfile -t files < <(grep -rIl --exclude-dir=.git --exclude-dir=thirdparty --exclude-dir=build \
        --exclude=LICENSE --exclude=.clang-format --exclude="$(basename "$0")" \
        -e "$old_name" -e "${old_name^^}" -e "$old_slug" -e "$old_author" -e "$old_email" \
        -e "$old_desc" -e "${old_desc,}" .)

sed -i \
        -e "s/$(pat "$old_slug")/$(rep "$slug")/g" \
        -e "s/Copyright (C) [0-9]\{4\} $(pat "$old_author")/Copyright (C) $year $(rep "$author")/g" \
        -e "s/$(pat "$old_author")/$(rep "$author")/g" \
        -e "s/$(pat "$old_email")/$(rep "$email")/g" \
        -e "s/$(pat "$old_desc")/$(rep "$desc")/g" \
        -e "s/$(pat "${old_desc,}")/$(rep "$desc_lower")/g" \
        -e "s/_${old_name}_complete/_${name//-/_}_complete/g" \
        -e "s/_$old_name\b/_$name/g" \
        -e "s/\b$old_name\b/$name/g" \
        -e "s/\b${old_name^^}\b/${name^^}/g" \
        "${files[@]}"

move() { git mv -f "$1" "$2" 2>/dev/null || mv "$1" "$2"; }
for f in docs/$old_name.1 completions/$old_name.bash completions/_$old_name completions/$old_name.fish; do
        move "$f" "${f//$old_name/$name}"
done
rm -f "$old_name"

# Submodules: a copy of the template may have them registered or not
for lib in flag cum conf; do
        path=src/thirdparty/$lib
        git ls-files --stage -- "$path" | grep -q '^160000' ||
                git submodule add "https://github.com/hugoocoto/$lib.h" "$path"
done
git submodule update --init

git config core.hooksPath scripts/hooks
rm -- "$0"

echo
echo "Done: ${#files[@]} files updated. Review them with 'git status' and 'git diff',"
echo "build with 'make', and commit. What's left is your program: src/, test/,"
echo "config.lua, the man page, the completions and Usage and Configuration in"
echo "README.md, which say what to keep in sync."
