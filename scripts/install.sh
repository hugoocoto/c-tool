#!/usr/bin/env bash
# Install template from its GitHub releases, nothing to build:
#
#   curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash
#
# It installs the static binary for this machine (template-x86_64-static or
# template-aarch64-static, from `uname -m`), the man page and the bash, zsh
# and fish completions, checking them against the release's SHA256SUMS, and
# SHA256SUMS against the release's build attestation when gh is logged in.
# Nothing is replaced until everything is downloaded and checked. See usage()
# for the arguments, which go after `bash -s --`.
set -euo pipefail

NAME=template
REPO=${REPO:-hugoocoto/c-tool}
GITHUB=${GITHUB:-https://github.com}

usage() {
        cat <<EOF
Usage: ... | bash -s -- [OPTIONS] [VERSION | nightly | uninstall]

Installs $NAME from $GITHUB/$REPO/releases.

  VERSION              that release (v1.2.3 or 1.2.3) instead of the latest one
  nightly              the build of the last commit on main
  uninstall            remove everything this script installs
  --appimage           the AppImage instead of the static binary (it needs
                       FUSE), with its applications menu entry and icon
  --strict             fail if the release's attestation can't be checked
                       (needs gh, logged in)
  --skip-attestation   don't check the attestation, for releases made
                       before there were any
  -h, --help           this help

PREFIX is where it goes: ~/.local by default, /usr/local as root
(... | sudo bash). A relative PREFIX is taken from the current directory.
EOF
}

if [ -n "${PREFIX:-}" ]; then
        case $PREFIX in
        /*) ;;
        *) PREFIX=$PWD/$PREFIX ;; # the install runs from a temp dir
        esac
elif [ "$(id -u)" = 0 ]; then
        # Not root's ~/.local, nor, under a sudo that keeps HOME, root-owned
        # files in the user's
        PREFIX=/usr/local
else
        PREFIX=$HOME/.local
fi
PREFIX=${PREFIX%/}
BINDIR=$PREFIX/bin
MANDIR=$PREFIX/share/man/man1
BASHDIR=$PREFIX/share/bash-completion/completions
ZSHDIR=$PREFIX/share/zsh/site-functions
# fish only looks for a user's completions in its own config dir
if [ "$PREFIX" = "$HOME/.local" ]; then
        FISHDIR=$HOME/.config/fish/completions
else
        FISHDIR=$PREFIX/share/fish/vendor_completions.d
fi
# The AppImage's menu entry and icon (only with --appimage)
APPSDIR=$PREFIX/share/applications
ICONSDIR=$PREFIX/share/icons
DESKTOP_FILES=("$APPSDIR/$NAME.desktop" "$ICONSDIR"/hicolor/*/apps/"$NAME".{svg,png})
FILES=("$BINDIR/$NAME" "$MANDIR/$NAME.1" "$BASHDIR/$NAME" "$ZSHDIR/_$NAME" "$FISHDIR/$NAME.fish"
        "${DESKTOP_FILES[@]}")

tmp=''
staged=()

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }
fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }

cleanup() {
        local f
        for f in "${staged[@]}"; do rm -f "$f.$NAME-new"; done
        [ -z "$tmp" ] || rm -rf "$tmp"
}

# Check FILE (in the current dir) against its line in SHA256SUMS
verify() {
        local line
        line=$(awk -v f="$1" '$2 == f || $2 == "*" f' SHA256SUMS)
        [ -n "$line" ] || die "$1 is not in the release's SHA256SUMS"
        printf '%s\n' "$line" | sha256sum -c --quiet - >/dev/null 2>&1 ||
                die "$1 doesn't match the release's SHA256SUMS"
}

# Check that SHA256SUMS was made by this repo's CI ($1 is --strict or empty)
attest() {
        local why=
        if [ "$GITHUB" != https://github.com ]; then
                why="$GITHUB is not GitHub"
        elif ! command -v gh >/dev/null; then
                why="gh is not installed"
        elif ! gh auth status >/dev/null 2>&1; then
                why="gh is not logged in (gh auth login)"
        fi
        if [ -n "$why" ]; then
                [ -z "$1" ] || die "can't check the release's attestation: $why"
                say "Not checking the release's attestation: $why. SHA256SUMS only catches broken"
                say "downloads, not a release whose files were all replaced."
                return
        fi
        gh attestation verify SHA256SUMS --repo "$REPO" \
                --signer-workflow "$REPO/.github/workflows/ci.yml" >/dev/null 2>&1 ||
                die "SHA256SUMS has no valid attestation from $REPO's CI (if the release is older than its attestations: --skip-attestation)"
        say "Checked the release's attestation"
}

# Install SRC as DEST, but beside it, until commit puts everything in place
stage() {
        install -Dm"$1" "$2" "$3.$NAME-new"
        staged+=("$3")
}

commit() {
        local f
        for f in "${staged[@]}"; do mv -f "$f.$NAME-new" "$f"; done
        staged=()
}

uninstall() {
        local f removed=0
        # Whatever is there: `make install` puts it in the same places
        for f in "${FILES[@]}"; do
                if [ -e "$f" ] || [ -L "$f" ]; then
                        rm -f "$f"
                        say "Removed $f"
                        removed=1
                fi
        done
        refresh_desktop
        [ "$removed" = 1 ] || say "$NAME was not installed in $PREFIX"
}

# Update the menu and icon caches, but only the ones that already exist:
# making an icon cache would hide the icons of later apps that don't update it
refresh_desktop() {
        if [ -f "$APPSDIR/mimeinfo.cache" ] && command -v update-desktop-database >/dev/null; then
                update-desktop-database -q "$APPSDIR" 2>/dev/null || true
        fi
        if [ -f "$ICONSDIR/hicolor/icon-theme.cache" ] && command -v gtk-update-icon-cache >/dev/null; then
                gtk-update-icon-cache -q -t "$ICONSDIR/hicolor" 2>/dev/null || true
        fi
}

# Put the AppImage $1 in the applications menu: its .desktop file, run from
# where it was installed, and its icon. Extracting doesn't need FUSE.
integrate_desktop() {
        local root=squashfs-root/usr/share icon
        chmod +x "$1"
        "./$1" --appimage-extract >/dev/null 2>&1 && [ -f "$root/applications/$NAME.desktop" ] || {
                warn "couldn't get the menu entry out of the AppImage"
                return 0
        }
        mkdir -p "$APPSDIR"
        sed -e "s|^Exec=.*|Exec=\"$BINDIR/$NAME\"|" -e '/^TryExec=/d' \
                -e "/^Exec=/a TryExec=$BINDIR/$NAME" "$root/applications/$NAME.desktop" >"$APPSDIR/$NAME.desktop"
        for icon in "$root"/icons/hicolor/*/apps/"$NAME".*; do
                [ -f "$icon" ] && install -Dm644 "$icon" "$ICONSDIR/${icon#"$root"/icons/}"
        done
        refresh_desktop
        say "Added $NAME to the applications menu"
}

# The menu entry of an earlier --appimage install, now that it's the static binary
remove_desktop() {
        local f removed=''
        for f in "${DESKTOP_FILES[@]}"; do
                [ -e "$f" ] && rm -f "$f" && removed=1
        done
        [ -z "$removed" ] || { refresh_desktop; say "Removed the AppImage's applications menu entry"; }
}

# The whole script runs from here, at its last line: if the download is cut,
# bash runs nothing instead of half of it
main() {
        local tag='' appimage='' strict='' skip_attest='' arch url bin version found arg

        for arg; do
                case $arg in
                -h | --help) usage; return ;;
                --appimage) appimage=1 ;;
                --strict) strict=--strict ;;
                --skip-attestation) skip_attest=1 ;;
                -*) die "unknown option $arg (see --help)" ;;
                *)
                        [ -z "$tag" ] || die "both $tag and $arg given, pick one"
                        tag=$arg
                        ;;
                esac
        done
        case $tag in
        [0-9]*) tag=v$tag ;;
        esac
        [ -z "$strict" ] || [ -z "$skip_attest" ] || die "--strict and --skip-attestation don't go together"
        if [ "$tag" = uninstall ] && [ -n "$appimage$strict$skip_attest" ]; then
                die "uninstall takes no options"
        fi

        [ "$(uname -s)" = Linux ] || die "there are only Linux builds"
        [ "$tag" != uninstall ] || { uninstall; return; }
        for arg in curl sha256sum awk tar gzip install mktemp; do
                command -v "$arg" >/dev/null || die "needs $arg"
        done

        case $(uname -m) in
        x86_64 | amd64) arch=x86_64 ;;
        aarch64 | arm64) arch=aarch64 ;;
        *) die "there is no build for $(uname -m)" ;;
        esac
        bin=$NAME-$arch-static
        [ -z "$appimage" ] || bin=$NAME-$arch.AppImage

        if [ -z "$tag" ]; then
                # releases/latest redirects to releases/tag/<tag>, or to
                # releases if there are none
                tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$GITHUB/$REPO/releases/latest") ||
                        die "can't reach $GITHUB/$REPO"
                tag=${tag##*/}
                [ "$tag" != releases ] && [ "$tag" != latest ] ||
                        die "$REPO has no releases yet, install nightly: ... | bash -s -- nightly"
        fi

        tmp=$(mktemp -d)
        trap cleanup EXIT
        cd "$tmp"

        say "Downloading $NAME $tag ($arch)"
        url=$GITHUB/$REPO/releases/download/$tag
        fetch "$url/SHA256SUMS" SHA256SUMS ||
                die "$REPO has no release $tag, or it has no SHA256SUMS (releases: $GITHUB/$REPO/releases)"
        [ -n "$skip_attest" ] || attest "$strict"
        fetch "$url/$bin" "$bin" || die "release $tag has no $bin"
        fetch "$url/$NAME-completions.tar.gz" "$NAME-completions.tar.gz" || die "release $tag has no completions"
        fetch "$url/$NAME.1" "$NAME.1" || die "release $tag has no man page"
        verify "$bin"
        verify "$NAME-completions.tar.gz"
        verify "$NAME.1"
        tar -xzf "$NAME-completions.tar.gz"

        # Everything goes beside its place first, so a failure (a full disk,
        # a dir it can't write to) leaves the old install as it was
        stage 755 "$bin" "$BINDIR/$NAME"
        stage 644 "$NAME-completions/$NAME.bash" "$BASHDIR/$NAME"
        stage 644 "$NAME-completions/_$NAME" "$ZSHDIR/_$NAME"
        stage 644 "$NAME-completions/$NAME.fish" "$FISHDIR/$NAME.fish"
        stage 644 "$NAME.1" "$MANDIR/$NAME.1"
        commit
        if [ -n "$appimage" ]; then
                integrate_desktop "$bin"
        else
                remove_desktop
        fi

        if version=$("$BINDIR/$NAME" --version 2>/dev/null); then
                say "Installed $version to $BINDIR/$NAME"
        elif [ -n "$appimage" ]; then
                say "Installed $bin to $BINDIR/$NAME, but it can't run: AppImages need FUSE"
                say "(the fuse or fuse3 package). Or install the static binary, without --appimage."
        else
                die "installed $BINDIR/$NAME, but it doesn't run"
        fi
        case ":$PATH:" in
        *":$BINDIR:"*) ;;
        *) say "$BINDIR is not in your PATH, add it to your shell's config" ;;
        esac
        found=$(type -P "$NAME" || true)
        if [ -n "$found" ] && ! [ "$found" -ef "$BINDIR/$NAME" ]; then
                warn "\`$NAME\` runs $found instead, it comes first in your PATH"
        fi
        case ${SHELL:-} in
        */zsh) say "For the zsh completions, add to ~/.zshrc before compinit: fpath=($ZSHDIR \$fpath)" ;;
        esac
}

main "$@"
