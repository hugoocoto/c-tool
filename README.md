# \_\_NAME\_\_

[![CI](https://github.com/__REPO__/actions/workflows/ci.yml/badge.svg)](https://github.com/__REPO__/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/__REPO__)](https://github.com/__REPO__/releases/latest)
[![License](https://img.shields.io/github/license/__REPO__)](LICENSE)

\_\_DESCRIPTION\_\_.

<!-- template-init: remove from here -->
> **This is a template for C command line tools.** Create a repo from it
> (GitHub's *Use this template* button, or a copy), clone it with
> `--recursive` and run `scripts/template-init.sh`. It asks for the name, a
> one-line description, the GitHub repo, the author and their email, and
> the license (GPL-3.0-or-later, MIT, Apache-2.0, BSD-2-Clause, MPL-2.0 or
> none), suggesting what it finds in git, and which optional parts to keep:
> the Typst manual, the man page, the shell completions, the AppImage, the
> static binary, GitHub releases, the install script, the git hooks,
> Dependabot, the issue and pull request templates and the macOS build.
> Then it removes the rest and fills in the placeholders: everything that
> names the project, its repo or its author is one (`__NAME__`, `__REPO__`,
> `__AUTHOR__`, `__EMAIL__`...), so nothing else is ever touched, and none
> of this template's own details end up in your project. It registers the
> submodules, removes this note, `template/` and itself, and offers to set
> up the GitHub repo (`scripts/github-setup.sh`). What's left to write is the
> program, its tests, and the [Usage](#usage) and
> [Configuration](#configuration) sections of this README, which say so in
> comments.

<!-- template-init: to here -->
## Install

<!-- template-init: begin install -->
```sh
curl -fsSL https://github.com/__REPO__/releases/latest/download/install.sh | bash
```

It asks what to install and where, with its suggestion filled in (Enter
takes it): the latest release, in `~/.local` (`/usr/local` as root), the
binary for your machine (x86_64 or aarch64 Linux) with what comes with it.
Everything is checked against the release's `SHA256SUMS`, and if
[`gh`](https://cli.github.com) is installed and logged in, `SHA256SUMS` is
checked against the release's attestation, proof that CI built it from this
repo. Nothing is replaced until it all checks out. Arguments, after
`bash -s --`, change the suggestions, and `--yes` takes them without asking
(`--help` lists them all):

```sh
curl -fsSL https://github.com/__REPO__/releases/latest/download/install.sh | bash -s -- v1.2.3     # that release
curl -fsSL https://github.com/__REPO__/releases/latest/download/install.sh | bash -s -- nightly    # the last commit on main
curl -fsSL https://github.com/__REPO__/releases/latest/download/install.sh | bash -s -- --appimage # the AppImage instead
curl -fsSL https://github.com/__REPO__/releases/latest/download/install.sh | bash -s -- --strict   # fail without the attestation check
curl -fsSL https://github.com/__REPO__/releases/latest/download/install.sh | bash -s -- uninstall
curl -fsSL https://github.com/__REPO__/releases/latest/download/install.sh | bash -s -- --yes      # no questions
curl -fsSL https://github.com/__REPO__/releases/latest/download/install.sh | PREFIX=~/opt bash     # somewhere else
```

<!-- template-init: begin appimage -->
<!-- template-init: begin static -->
It installs the static binary, which needs nothing else installed, unless
you have the AppImage installed or ask for it with `--appimage`.
<!-- template-init: end static -->
The AppImage is installed as `__NAME__` too, and added to your applications
menu, with its icon (installing the static binary again takes them out). It
works the same, but needs FUSE (the `fuse` or `fuse3` package).

<!-- template-init: end appimage -->
`uninstall` removes it all, also what `make install` put in the same places.
Releases made before attestations need `--skip-attestation`.

The script comes from the latest release, attested like everything in it. To
check it before running it:

```sh
curl -fsSLO https://github.com/__REPO__/releases/latest/download/install.sh
gh attestation verify install.sh --repo __REPO__ && bash install.sh
```

The same checks any file you downloaded yourself: `gh attestation verify <file> --repo __REPO__`.

If `~/.local/bin` is not in your `PATH` yet, add it to your shell's config.
<!-- template-init: begin completions -->
For the zsh completions, add this to `~/.zshrc`, before `compinit`:

```zsh
fpath=(~/.local/share/zsh/site-functions $fpath)
```
<!-- template-init: end completions -->

<!-- template-init: end install -->
<!-- template-init: begin releases -->
### By hand

Every [release](../../releases/latest) has, for x86_64 and aarch64:

| File                            | What                                           |
|---------------------------------|------------------------------------------------|
| `__NAME__-<arch>-static`        | the program, a static binary (built with musl) |
| `__NAME__-<arch>.AppImage`      | the program, as an AppImage                    |
| `__NAME__-completions.tar.gz`   | bash, zsh and fish completions                 |
| `__NAME__.1`                    | the man page                                   |
| `__NAME__-<version>.tar.gz`     | the source code, with the submodules           |
| `*.pdf`                         | the documentation                              |
| `install.sh`                    | the install script                             |
| `CHANGELOG.md`                  | what changed in every release                  |
| `SHA256SUMS`                    | checksums of all of the above                  |

The [nightly](../../releases/tag/nightly) release has the same files, built
from the last commit on main. Check what you downloaded first:

```sh
sha256sum -c --ignore-missing SHA256SUMS
```

<!-- template-init: begin static -->
```sh
install -Dm755 __NAME__-x86_64-static ~/.local/bin/__NAME__    # or __NAME__-aarch64-static
```

<!-- template-init: end static -->
<!-- template-init: begin man -->
```sh
install -Dm644 __NAME__.1 ~/.local/share/man/man1/__NAME__.1
```

<!-- template-init: end man -->
<!-- template-init: begin completions -->
Or have `__NAME__` print them, e.g. `source <(__NAME__ --completions bash)` in
`~/.bashrc` (also `zsh` and `fish`):

```sh
tar -xzf __NAME__-completions.tar.gz && cd __NAME__-completions
install -Dm644 __NAME__.bash ~/.local/share/bash-completion/completions/__NAME__
install -Dm644 ___NAME__ ~/.local/share/zsh/site-functions/___NAME__
install -Dm644 __NAME__.fish ~/.config/fish/completions/__NAME__.fish
```

<!-- template-init: end completions -->
<!-- template-init: end releases -->
### From source

See [Building](#building). `make install` installs it in `~/.local` (or
`PREFIX`).

## Usage

<!-- Your program's --help, exactly: `make test` fails until it is (see
Documentation in CONTRIBUTING.md). -->

```
usage: __NAME__ [-h] [--completions C] [-v] [-c C]

__DESCRIPTION__

options:
 --help, -h       Show this help
 --completions C  Print completions for bash, zsh or fish
 --version, -v    Show version and exit
 --config, -c C   Use this config file
```

<!-- template-init: begin man -->
`man __NAME__` has the full manual.
<!-- template-init: end man -->

## Configuration

<!-- What the config can have. Where it's read from is the same in every
project. -->

The config is a Lua 5.4 file: `$XDG_CONFIG_HOME/__NAME__/config.lua`
(usually `~/.config/__NAME__/config.lua`), or the one given with `-c`. Without
one, the defaults are used. A `config.lua` in the current directory is never
read on its own: it can run any command, so running `__NAME__` inside a
downloaded directory would run that directory's code. Use `-c config.lua` for
that one.

```lua
Config = {
}
```

It's plain Lua, so it can compute values, read environment variables, etc.

## Building

Needs a C compiler, make and Lua 5.4 with its headers (or Lua 5.1 or
LuaJIT, with `make LUA=lua5.1` or `make LUA=luajit`):

| Distro        | Packages        |
|---------------|-----------------|
| Arch          | `lua54`         |
| Debian/Ubuntu | `liblua5.4-dev` |

<!-- template-init: begin static -->
`make static` also needs musl-gcc: `musl` on Arch, `musl-tools` on
Debian/Ubuntu.

<!-- template-init: end static -->
<!-- template-init: begin macos -->
On macOS, it needs Homebrew's Lua and GNU make, as macOS's own make is too
old: `brew install lua make`, then `gmake` wherever this says `make`.

<!-- template-init: end macos -->

```sh
git clone --recursive https://github.com/__REPO__ __NAME__
cd __NAME__
make
./__NAME__ --version
```

| Command                     | What it does                                                  |
|-----------------------------|---------------------------------------------------------------|
| `make`                      | build `./__NAME__` (objects in `build/`), hardened            |
| `make WERROR=1`             | the same, failing on any warning, like CI                     |
| `make LUA=luajit`           | the same, with LuaJIT (or `LUA=lua5.1`)                       |
| `make debug`                | `-O0 -ggdb` with the address and undefined sanitizers         |
| `make test`                 | build and run the tests, with the same sanitizers             |
| `make test SANITIZE=thread` | the tests again, looking for data races                       |
| `make format`               | format the code with clang-format                             |
| `make check-format`         | check it's formatted, like CI does                            |
| `make install`              | install it to `~/.local` (`PREFIX`, `DESTDIR`)                |
| `make uninstall`            | remove them                                                   |
| `make static`               | `__NAME__-<arch>-static`, a static binary (needs musl-gcc)    |
| `make appimage`             | `__NAME__-<arch>.AppImage` (downloads its pinned tools)       |
| `make completions`          | `__NAME__-completions.tar.gz`, from `__NAME__ --completions`  |
| `make dist`                 | `__NAME__-<version>.tar.gz`, the source with the submodules   |
| `make man`                  | `__NAME__.1`, the man page with its version                   |
| `make docs`                 | `docs/*.typ` to PDF (needs typst)                             |
| `make clean`                | remove what the build made                                    |
| `make distclean`            | also the downloads and everything packaged                    |

If you cloned without `--recursive`: `git submodule update --init`.

## Versions

`__NAME__ --version` shows the version, from `git describe`: `v1.2.3` on a
release, `v1.2.3-4-gabcdef0` four commits after it, `-dirty` if built with
uncommitted changes, and `unknown` outside git.

<!-- template-init: begin releases -->
- Every push to main that passes CI updates the
  [nightly](../../releases/tag/nightly) release.
- [release-please](https://github.com/googleapis/release-please) keeps a pull
  request open with the next version and `CHANGELOG.md`, from the Conventional
  Commits on main: `fix` is a patch, `feat` a minor version, and a breaking
  change a major one (minor before 1.0.0). Merging it tags the release, and CI
  builds, checks and publishes it.

<!-- template-init: end releases -->
## CI

CI builds and tests every push to main and every pull request with gcc and
clang, each with AddressSanitizer, LeakSanitizer and
UndefinedBehaviorSanitizer, and again with ThreadSanitizer: a memory error,
leak, undefined behavior or data race fails it, and so does any compiler
warning or anything clang's static analyzer finds. It also checks the code
is formatted and the docs match `--help`, runs every file it packages, and
builds the source tarball on its own.
<!-- template-init: begin macos -->
It builds and runs the tests on macOS too.
<!-- template-init: end macos -->
<!-- template-init: begin install -->
It runs the install script on what it packaged before anything is
published, and again on each release once it is.
<!-- template-init: end install -->

- The build is hardened by default: `_FORTIFY_SOURCE=3`, stack protector
  and PIE, and on Linux, stack clash protection and full RELRO.
- Everything the build downloads is pinned to a version and checked against
  its sha256 before every use, and the GitHub Actions are pinned to commits.
- The tarballs are reproducible: built again from the same commit, they're
  the same bytes. CI builds them twice to check.
<!-- template-init: begin releases -->
- Every release file is attested (signed as built by this workflow, from its
  commit), so it can be checked to be what CI built from this repo.
<!-- template-init: end releases -->

<!-- template-init: begin dependabot -->
Dependabot keeps the GitHub Actions (their pinned commits) and the
submodules up to date with weekly pull requests.
<!-- template-init: end dependabot -->
The tools in the Makefile are updated by hand: their versions and checksums
are together there.

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

Copyright (C) \_\_YEAR\_\_ \_\_AUTHOR\_\_

<!-- template-init: begin license -->
\_\_LICENSE\_\_, see [LICENSE](LICENSE).
<!-- template-init: end license -->
The libraries in `src/thirdparty/` keep their own licenses.
