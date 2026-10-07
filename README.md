# template

[![CI](https://github.com/hugoocoto/c-tool/actions/workflows/ci.yml/badge.svg)](https://github.com/hugoocoto/c-tool/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/hugoocoto/c-tool)](https://github.com/hugoocoto/c-tool/releases/latest)
[![License](https://img.shields.io/github/license/hugoocoto/c-tool)](LICENSE)

Greet everyone listed in a Lua config.

<!-- template-init: remove from here -->
> **This is a template for C command line tools.** Create a repo from it
> (GitHub's *Use this template* button, or a copy), clone it with
> `--recursive` and run `scripts/template-init.sh`. It asks for a one-line
> description, then names everything after the repo (binary, config dir, man
> page, completions, AppImage, install script, these docs), puts your name
> from git config as the author, registers the submodules, enables the git
> hooks, removes this note and deletes itself. What's left to write is the
> program, its tests, and the [Usage](#usage) and
> [Configuration](#configuration) sections of this README, which say so in
> comments.

<!-- template-init: to here -->
## Install

```sh
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash
```

This installs the latest release in `~/.local`: the static binary for your
machine (`template-x86_64-static` or `template-aarch64-static`, for any
x86_64 or aarch64 Linux), its man page and its bash, zsh and fish
completions, after checking them against the release's `SHA256SUMS`. Being
static, it needs nothing else installed. Arguments go after `bash -s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash -s -- v1.2.3     # that release
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash -s -- nightly    # the last commit on main
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash -s -- --appimage # the AppImage instead
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash -s -- uninstall
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | sudo PREFIX=/usr/local bash
```

`--appimage` installs `template-<arch>.AppImage` as `template` instead of the
static binary, and adds it to your applications menu, with its icon. It can
go with a version (`--appimage v1.2.3`), and `uninstall` removes it all. Both
work the same, but the AppImage needs FUSE (the `fuse` or `fuse3` package).

If `~/.local/bin` is not in your `PATH` yet, add it to your shell's config.
For the zsh completions, add this to `~/.zshrc`, before `compinit`:

```zsh
fpath=(~/.local/share/zsh/site-functions $fpath)
```

### By hand

Every [release](../../releases/latest) has, for x86_64 and aarch64:

| File                            | What                                           |
|---------------------------------|------------------------------------------------|
| `template-<arch>-static`        | the program, a static binary (built with musl) |
| `template-<arch>.AppImage`      | the same program, as an AppImage               |
| `template-completions.tar.gz`   | bash, zsh and fish completions                 |
| `template.1`                    | the man page                                   |
| `template-<version>.tar.gz`     | the source code, with the submodules           |
| `*.pdf`                         | the documentation                              |
| `CHANGELOG.md`                  | what changed in every release                  |
| `SHA256SUMS`                    | checksums of all of the above                  |

The [nightly](../../releases/tag/nightly) release has the same files, built
from the last commit on main.

```sh
sha256sum -c --ignore-missing SHA256SUMS
install -Dm755 template-x86_64-static ~/.local/bin/template    # or template-aarch64-static
install -Dm644 template.1 ~/.local/share/man/man1/template.1

tar -xzf template-completions.tar.gz && cd template-completions
install -Dm644 template.bash ~/.local/share/bash-completion/completions/template
install -Dm644 _template ~/.local/share/zsh/site-functions/_template
install -Dm644 template.fish ~/.config/fish/completions/template.fish
```

### From source

See [Building](#building). `make install` installs the program, the man page
and the completions in `~/.local` (or `PREFIX`).

## Usage

<!-- Your program's --help. Keep it, the man page (docs/template.1) and the
completions (completions/) in sync with the flags. -->

```
template [-h] [-v] [-c C]

options:
 --help, -h      Show this help
 --version, -v   Show version and exit
 --config, -c C  Use this config file
```

`man template` has the full manual.

## Configuration

<!-- What the config can have. Where it's read from is the same in every
project. -->

The config is a Lua 5.1 file. The first of these that exists is used, and
the defaults are used if none does:

1. `$XDG_CONFIG_HOME/template/config.lua` (usually `~/.config/template/config.lua`)
2. `./config.lua`

```lua
Config = {
    greeting = "Hello",
    times = 1,
    names = { "world", os.getenv("USER") },
}
```

It's plain Lua, so it can compute values, read environment variables, etc.

## Building

Needs a C compiler, make and Lua 5.1 (or LuaJIT) with its headers:

| Distro        | Packages                | For `make static` |
|---------------|-------------------------|-------------------|
| Arch          | `lua51` (or `luajit`)   | `musl`            |
| Debian/Ubuntu | `liblua5.1-0-dev`       | `musl-tools`      |

```sh
git clone --recursive https://github.com/hugoocoto/c-tool template
cd template
make
./template --version
```

| Command                     | What it does                                                  |
|-----------------------------|---------------------------------------------------------------|
| `make`                      | build `./template` (objects in `build/`)                      |
| `make LUA=luajit`           | the same, with LuaJIT                                         |
| `make debug`                | `-O0 -ggdb` with the address and undefined sanitizers         |
| `make test`                 | build and run the tests, with the same sanitizers             |
| `make test SANITIZE=thread` | the tests again, looking for data races                       |
| `make format`               | format the code with clang-format                             |
| `make check-format`         | check it's formatted, like CI does                            |
| `make install`              | program, man page and completions to `~/.local` (`PREFIX`, `DESTDIR`) |
| `make uninstall`            | remove them                                                   |
| `make static`               | `template-<arch>-static`, a static binary (needs musl-gcc)    |
| `make appimage`             | `template-<arch>.AppImage`                                    |
| `make completions`          | `template-completions.tar.gz`                                 |
| `make dist`                 | `template-<version>.tar.gz`, the source with the submodules   |
| `make man`                  | `template.1`, the man page with its version                   |
| `make docs`                 | `docs/*.typ` to PDF (needs typst)                             |
| `make changelog`            | `CHANGELOG.md`, from the commit messages                      |
| `make clean`                | remove what the build made                                    |
| `make distclean`            | also downloads, AppImages, static binaries, tarballs and PDFs |

If you cloned without `--recursive`: `git submodule update --init`.

## Versions and releases

`template --version` shows the version, from `git describe`: `v1.2.3` on a
release, `v1.2.3-4-gabcdef0` four commits after it, `-dirty` if built with
uncommitted changes, and `unknown` outside git.

- Every push to main that passes CI updates the
  [nightly](../../releases/tag/nightly) release.
- Releases are made with `scripts/release.sh`: it asks for the new version
  (bigger than the last one), tags main with it and pushes the tag, and CI
  builds and publishes the release.
- Each release's notes list its commits, grouped in Added, Changed, Fixed and
  Removed by their first word, and `CHANGELOG.md` in every release has them
  for all releases.

CI builds and tests every push and pull request with gcc and clang, each with
AddressSanitizer, LeakSanitizer and UndefinedBehaviorSanitizer, and again with
ThreadSanitizer: a memory error, leak, undefined behavior or data race fails
it. It also checks the code is formatted, and runs every file it's about to
release: the binaries, the man page, and a build from the source tarball.
Dependabot keeps the GitHub Actions and the submodules up to date with weekly
pull requests.

## Contributing

Bug reports, ideas and pull requests are welcome.

- **Found a bug?** [Open an issue](../../issues/new/choose) with what you
  ran, what happened, what you expected, and the output of
  `template --version`.
- **Want a feature?** Open an issue first, so we can agree on it before you
  write the code.
- **Sending code?** Read [CONTRIBUTING.md](CONTRIBUTING.md): it has the
  setup, the tests and what a pull request needs.

## License

Copyright (C) 2026 Hugo Coto Florez

GPL-3.0-or-later, see [LICENSE](LICENSE). The libraries in `src/thirdparty/`
keep their own licenses.
