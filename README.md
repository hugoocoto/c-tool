# \_\_NAME\_\_

[![CI](https://github.com/hugoocoto/c-tool/actions/workflows/ci.yml/badge.svg)](https://github.com/hugoocoto/c-tool/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/hugoocoto/c-tool)](https://github.com/hugoocoto/c-tool/releases/latest)
[![License](https://img.shields.io/github/license/hugoocoto/c-tool)](LICENSE)

Greet everyone listed in a Lua config.

<!-- template-init: remove from here -->
> **This is a template for C command line tools.** Create a repo from it
> (GitHub's *Use this template* button, or a copy), clone it with
> `--recursive` and run `scripts/template-init.sh`. It asks for the name, a
> one-line description, the GitHub repo and the author, suggesting what it
> finds in git, then names everything after it (binary, config dir, man
> page, completions, AppImage, install script, these docs: `__NAME__` is the
> placeholder for the name, so the word "template" is never touched), puts
> you in as the author, registers the submodules, enables the git hooks,
> removes this note and deletes itself. What's left to write is the program,
> its tests, and the [Usage](#usage) and [Configuration](#configuration)
> sections of this README, which say so in comments.

<!-- template-init: to here -->
## Install

```sh
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash
```

It asks what to install and where, with its suggestion filled in (Enter
takes it): the latest release, in `~/.local` (`/usr/local` as root), as the
static binary for your machine (`__NAME__-x86_64-static` or
`__NAME__-aarch64-static`, for any x86_64 or aarch64 Linux), or as the
AppImage if that's what you have installed. With the program come its man
page and its bash, zsh and fish completions. Being static, it needs nothing
else installed. Everything is checked against the release's `SHA256SUMS`, and
if [`gh`](https://cli.github.com) is installed and logged in, `SHA256SUMS` is
checked against the release's attestation, proof that CI built it from this
repo. Nothing is replaced until it all checks out. Arguments, after
`bash -s --`, change the suggestions, and `--yes` takes them without asking
(`--help` lists them all):

```sh
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash -s -- v1.2.3     # that release
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash -s -- nightly    # the last commit on main
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash -s -- --appimage # the AppImage instead
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash -s -- --strict   # fail without the attestation check
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash -s -- uninstall
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | bash -s -- --yes      # no questions
curl -fsSL https://raw.githubusercontent.com/hugoocoto/c-tool/main/scripts/install.sh | PREFIX=~/opt bash     # somewhere else
```

`--appimage` installs `__NAME__-<arch>.AppImage` as `__NAME__` instead of the
static binary, and adds it to your applications menu, with its icon; installing
the static binary again takes them out. It can go with a version
(`--appimage v1.2.3`), and `uninstall` removes it all (also what
`make install` put in the same places). Both work the same, but the AppImage
needs FUSE (the `fuse` or `fuse3` package). Releases made before attestations
need `--skip-attestation`.

To check a file you downloaded yourself: `gh attestation verify <file> --repo hugoocoto/c-tool`.

If `~/.local/bin` is not in your `PATH` yet, add it to your shell's config.
For the zsh completions, add this to `~/.zshrc`, before `compinit`:

```zsh
fpath=(~/.local/share/zsh/site-functions $fpath)
```

### By hand

Every [release](../../releases/latest) has, for x86_64 and aarch64:

| File                            | What                                           |
|---------------------------------|------------------------------------------------|
| `__NAME__-<arch>-static`        | the program, a static binary (built with musl) |
| `__NAME__-<arch>.AppImage`      | the same program, as an AppImage               |
| `__NAME__-completions.tar.gz`   | bash, zsh and fish completions                 |
| `__NAME__.1`                    | the man page                                   |
| `__NAME__-<version>.tar.gz`     | the source code, with the submodules           |
| `*.pdf`                         | the documentation                              |
| `CHANGELOG.md`                  | what changed in every release                  |
| `SHA256SUMS`                    | checksums of all of the above                  |

The [nightly](../../releases/tag/nightly) release has the same files, built
from the last commit on main.

```sh
sha256sum -c --ignore-missing SHA256SUMS
install -Dm755 __NAME__-x86_64-static ~/.local/bin/__NAME__    # or __NAME__-aarch64-static
install -Dm644 __NAME__.1 ~/.local/share/man/man1/__NAME__.1

tar -xzf __NAME__-completions.tar.gz && cd __NAME__-completions
install -Dm644 __NAME__.bash ~/.local/share/bash-completion/completions/__NAME__
install -Dm644 ___NAME__ ~/.local/share/zsh/site-functions/___NAME__
install -Dm644 __NAME__.fish ~/.config/fish/completions/__NAME__.fish
```

### From source

See [Building](#building). `make install` installs the program, the man page
and the completions in `~/.local` (or `PREFIX`).

## Usage

<!-- Your program's --help. Keep it, the man page (docs/__NAME__.1) and the
completions (completions/) in sync with the flags. -->

```
__NAME__ [-h] [-v] [-c C]

options:
 --help, -h      Show this help
 --version, -v   Show version and exit
 --config, -c C  Use this config file
```

`man __NAME__` has the full manual.

## Configuration

<!-- What the config can have. Where it's read from is the same in every
project. -->

The config is a Lua 5.1 file. The first of these that exists is used, and
the defaults are used if none does:

1. `$XDG_CONFIG_HOME/__NAME__/config.lua` (usually `~/.config/__NAME__/config.lua`)
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
git clone --recursive https://github.com/hugoocoto/c-tool __NAME__
cd __NAME__
make
./__NAME__ --version
```

| Command                     | What it does                                                  |
|-----------------------------|---------------------------------------------------------------|
| `make`                      | build `./__NAME__` (objects in `build/`)                      |
| `make LUA=luajit`           | the same, with LuaJIT                                         |
| `make debug`                | `-O0 -ggdb` with the address and undefined sanitizers         |
| `make test`                 | build and run the tests, with the same sanitizers             |
| `make test SANITIZE=thread` | the tests again, looking for data races                       |
| `make format`               | format the code with clang-format                             |
| `make check-format`         | check it's formatted, like CI does                            |
| `make install`              | program, man page and completions to `~/.local` (`PREFIX`, `DESTDIR`) |
| `make uninstall`            | remove them                                                   |
| `make static`               | `__NAME__-<arch>-static`, a static binary (needs musl-gcc)    |
| `make appimage`             | `__NAME__-<arch>.AppImage`                                    |
| `make completions`          | `__NAME__-completions.tar.gz`                                 |
| `make dist`                 | `__NAME__-<version>.tar.gz`, the source with the submodules   |
| `make man`                  | `__NAME__.1`, the man page with its version                   |
| `make docs`                 | `docs/*.typ` to PDF (needs typst)                             |
| `make changelog`            | `CHANGELOG.md`, from the commit messages                      |
| `make clean`                | remove what the build made                                    |
| `make distclean`            | also downloads, AppImages, static binaries, tarballs and PDFs |

If you cloned without `--recursive`: `git submodule update --init`.

## Versions and releases

`__NAME__ --version` shows the version, from `git describe`: `v1.2.3` on a
release, `v1.2.3-4-gabcdef0` four commits after it, `-dirty` if built with
uncommitted changes, and `unknown` outside git.

- Every push to main that passes CI updates the
  [nightly](../../releases/tag/nightly) release.
- Releases are made with `scripts/release.sh`: it asks for the new version
  (bigger than the last one), suggesting the next one from the commits since
  the last release (major if they remove things, minor if they add things,
  else patch), tags main with it and pushes the tag, and CI
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
  `__NAME__ --version`.
- **Want a feature?** Open an issue first, so we can agree on it before you
  write the code.
- **Sending code?** Read [CONTRIBUTING.md](CONTRIBUTING.md): it has the
  setup, the tests and what a pull request needs.

## License

Copyright (C) 2026 Hugo Coto Florez

GPL-3.0-or-later, see [LICENSE](LICENSE). The libraries in `src/thirdparty/`
keep their own licenses.
