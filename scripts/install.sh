#!/usr/bin/env bash
# Install template from its GitHub releases, nothing to build:
#
#   curl -fsSL https://raw.githubusercontent.com/hugoocoto/template/main/scripts/install.sh | bash
#
# It installs the static binary for this machine (template-x86_64-static or
# template-aarch64-static, from `uname -m`) to ~/.local/bin, the man page and
# the bash, zsh and fish completions, checking them against the release's
# SHA256SUMS.
# Arguments go after `bash -s --`:
#
#   ... | bash -s -- v1.2.3      that release instead of the latest one
#   ... | bash -s -- nightly     the build of the last commit on main
#   ... | bash -s -- --appimage  the AppImage instead of the static binary (it
#                                needs FUSE), with its applications menu entry
#                                and icon. Can go with a version
#   ... | bash -s -- uninstall   remove everything it installed
#
# PREFIX changes where (default ~/.local): ... | sudo PREFIX=/usr/local bash
set -euo pipefail

NAME=template
REPO=${REPO:-hugoocoto/template}
GITHUB=${GITHUB:-https://github.com}

PREFIX=${PREFIX:-$HOME/.local}
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
tmp=
# The AppImage's menu entry and icon (only with --appimage)
APPSDIR=$PREFIX/share/applications
ICONSDIR=$PREFIX/share/icons
FILES=("$BINDIR/$NAME" "$MANDIR/$NAME.1" "$BASHDIR/$NAME" "$ZSHDIR/_$NAME" "$FISHDIR/$NAME.fish"
        "$APPSDIR/$NAME.desktop" "$ICONSDIR"/hicolor/*/apps/"$NAME".{svg,png})

say() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }
fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }

# Check FILE (in the current dir) against the line for it in SHA256SUMS
verify() {
        grep "  $1\$" SHA256SUMS | sha256sum -c --quiet - >/dev/null 2>&1 ||
                die "$1 doesn't match the release's SHA256SUMS"
}

uninstall() {
        rm -f "${FILES[@]}"
        refresh_desktop
        say "Removed $NAME from $PREFIX"
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
                say "warning: couldn't get the menu entry out of the AppImage"
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

# The whole script runs from here, at its last line: if the download is cut,
# bash runs nothing instead of half of it
main() {
        local tag=latest appimage= arch url bin version

        for arg; do
                case $arg in
                --appimage) appimage=1 ;;
                uninstall) tag=uninstall ;;
                -*) die "unknown option $arg" ;;
                *) tag=$arg ;;
                esac
        done

        [ "$(uname -s)" = Linux ] || die "there are only Linux builds"
        command -v curl >/dev/null || die "needs curl"
        command -v sha256sum >/dev/null || die "needs sha256sum"
        [ "$tag" != uninstall ] || { uninstall; return; }

        case $(uname -m) in
        x86_64 | amd64) arch=x86_64 ;;
        aarch64 | arm64) arch=aarch64 ;;
        *) die "there is no build for $(uname -m)" ;;
        esac
        bin=$NAME-$arch-static
        [ -z "$appimage" ] || bin=$NAME-$arch.AppImage

        if [ "$tag" = latest ]; then
                # releases/latest redirects to releases/tag/<tag>, or to
                # releases if there are none
                tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$GITHUB/$REPO/releases/latest") ||
                        die "can't reach $GITHUB/$REPO"
                tag=${tag##*/}
                [ "$tag" != releases ] && [ "$tag" != latest ] ||
                        die "$REPO has no releases yet, install nightly: ... | bash -s -- nightly"
        fi

        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        cd "$tmp"

        say "Downloading $NAME $tag ($arch)"
        url=$GITHUB/$REPO/releases/download/$tag
        fetch "$url/SHA256SUMS" SHA256SUMS || die "$REPO has no release $tag, or it has no SHA256SUMS"
        fetch "$url/$bin" "$bin" || die "release $tag has no $bin"
        fetch "$url/$NAME-completions.tar.gz" "$NAME-completions.tar.gz" || die "release $tag has no completions"
        fetch "$url/$NAME.1" "$NAME.1" || die "release $tag has no man page"
        verify "$bin"
        verify "$NAME-completions.tar.gz"
        verify "$NAME.1"
        tar -xzf "$NAME-completions.tar.gz"

        install -Dm755 "$bin" "$BINDIR/$NAME"
        install -Dm644 "$NAME-completions/$NAME.bash" "$BASHDIR/$NAME"
        install -Dm644 "$NAME-completions/_$NAME" "$ZSHDIR/_$NAME"
        install -Dm644 "$NAME-completions/$NAME.fish" "$FISHDIR/$NAME.fish"
        install -Dm644 "$NAME.1" "$MANDIR/$NAME.1"
        [ -z "$appimage" ] || integrate_desktop "$bin"

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
        case ${SHELL:-} in
        */zsh) say "For the zsh completions, add to ~/.zshrc before compinit: fpath=($ZSHDIR \$fpath)" ;;
        esac
}

main "$@"
