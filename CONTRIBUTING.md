# Contributing to \_\_NAME\_\_

Thanks for helping! Bug reports, ideas, docs and code are all welcome.

## Reporting bugs

[Open an issue](../../issues/new/choose). The more of this it has, the
faster it gets fixed:

- what you ran (the command, and the config if it matters),
- what happened (the full output) and what you expected,
- the output of `__NAME__ --version`, and how you installed it,
- your distro and architecture.

Search the open issues first: someone may have reported it already.

<!-- template-init: begin community -->
A security problem goes privately instead, not in an issue: see
[SECURITY.md](.github/SECURITY.md).
<!-- template-init: end community -->

## Suggesting features

Open an issue describing the problem you want to solve, not just the
solution. For anything that needs more than a few lines of code, agree on it
in the issue before writing it: it saves everyone's time.

## Setting up

You need a C compiler (gcc or clang), make and Lua 5.4 (or 5.1, or LuaJIT)
with its headers: see [Building](README.md#building).

```sh
git clone --recursive https://github.com/__REPO__ __NAME__
cd __NAME__
make hooks   # check commit messages, and run the tests before every push
make debug   # build with the sanitizers while working
make test
```

Editors that use clangd get the right flags from `src/.clangd` and
`test/.clangd`, and the code style from `.clang-format` and `.editorconfig`.

### Project layout

```
src/                     the program, every .c is compiled to build/src/*.o
src/thirdparty/          git submodules: flag.h (flags), cum.h (macros), conf.h (Lua config)
test/                    one self-contained test per .c (a program) or .sh (a bash script)
scripts/test.sh          runs the tests (make test)
scripts/check-commit.sh  checks that a commit title is a Conventional Commit
scripts/github-setup.sh  sets up the GitHub repo's settings, with gh
docs/__NAME__.1          the man page
docs/*.typ               Typst documents, to PDF with make docs
assets/                  the AppImage icon
scripts/install.sh       the install script, attached to every release
scripts/test-install.sh  tests it on a release (CI)
scripts/changelog.sh     writes the nightly release's notes
scripts/hooks/           git hooks (make hooks)
```

## Making a change

1. Fork the repo and make a branch from main.
2. Make the change, with a test (see [Tests](#tests)).
3. Update the docs if it changes what users see (see [Documentation](#documentation)).
4. Check it: `make test`, `make test SANITIZE=thread` and `make check-format`.
5. Open a pull request, saying what it changes and why, with a
   [Conventional Commit](#commit-messages) as its title. Link the issue it
   fixes (`Fixes #123`).

CI runs the tests with gcc and clang, with every sanitizer. A pull request is
merged when CI is green and it has been reviewed. Small pull requests are
reviewed much faster than big ones: split them when you can.

## Code style

- C99 (`-std=c99`), with POSIX (`_DEFAULT_SOURCE`). No warnings with
  `-Wall -Wextra -Wformat=2 -Wshadow`: CI builds with `make WERROR=1`, which
  makes them errors (do the same to check). Warnings in `src/thirdparty/`
  don't count, its headers are included with `-isystem`.
- Format with `make format` (it leaves `src/thirdparty/` alone). CI checks it
  with the clang-format version in the Makefile (`CLANG_FORMAT_VERSION`): if
  yours formats differently, install that one with
  `pipx install clang-format==<version>` and run
  `make format CLANG_FORMAT=~/.local/bin/clang-format`.
- Functions that can fail return 0 on success and non-zero on error, and
  print the error themselves, starting with the program's name.
- Free what you allocate: the sanitizers fail the tests on any leak.
- Comments say why, not what. Keep them short.

## Tests

Every `test/*.c` is a self-contained program, and every `test/*.sh` a bash
script: it exits 0 if it passes and anything else if it fails. `make test`
builds the program and each C test with sanitizers, then `scripts/test.sh`
runs the tests in random order from the project root with a 10s timeout, and
fails if any of them does.

The sanitizers make a test fail on things that would otherwise pass silently:

- `make test` (address,undefined): out of bounds accesses, use after free,
  double free, memory leaks, signed overflow, misaligned or NULL pointers...
- `make test SANITIZE=thread`: data races and lock order inversions. It
  can't be combined with the address sanitizer, so it's a separate run.

Writing tests:

- Tests can include anything in `src/` and `src/thirdparty/`, and link with
  pthreads and Lua.
- `$TEST_BIN` is the program, also built with the sanitizers, for tests that
  run it: a leak in the program fails those tests too.
- Shell tests are for what's easier to check from outside, like
  `test/docs.sh`, which checks the docs against `--help`.
- Tests don't depend on each other or on the order they run in.

## Documentation

A change users can see updates, in the same pull request:

- `--help` (in `src/main.c`) and Usage in the README, for a flag
- `config.lua` and Configuration in the README, for the config
- the man page, `docs/__NAME__.1` (check it with `man docs/__NAME__.1`)
- the manual, `docs/*.typ`

`make test` checks them against `--help` (`test/docs.sh`): the README's
Usage must be exactly what it prints, and the other docs must have every
flag.
<!-- template-init: begin completions -->
The shell completions come from flag.h (`__NAME__ --completions SHELL`), so
they always have every flag.
<!-- template-init: end completions -->

## Commit messages

Pull requests are squashed, and their title becomes the commit on main, so
the title must be a [Conventional Commit](https://www.conventionalcommits.org)
(CI checks it):

```
type[(scope)][!]: description
```

The types are `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
`build`, `ci`, `chore` and `revert`. For example `feat: add --quiet` or
`fix(config): handle an empty file`. A `!` marks a breaking change, and a
`BREAKING CHANGE:` footer in the pull request's description explains it.

<!-- template-init: begin hooks -->
`make hooks` checks your commits the same way as you make them.
<!-- template-init: end hooks -->

<!-- template-init: begin releases -->
The titles are the changelog, so write them for users. `fix` makes a patch
release, `feat` a minor one, and a breaking change a major one (minor before
1.0.0). The other types don't make a release on their own.
<!-- template-init: end releases -->

## Third-party code

`src/thirdparty/` holds git submodules. Fix bugs in them upstream; to update
one by hand:

```sh
git -C src/thirdparty/flag pull origin main
git add src/thirdparty/flag
```

<!-- template-init: begin dependabot -->
Dependabot also opens a pull request every week when they have new commits,
and CI tests it.
<!-- template-init: end dependabot -->

<!-- template-init: begin releases -->
## Releases

[release-please](https://github.com/googleapis/release-please) keeps a pull
request open with the next version and `CHANGELOG.md`. Maintainers release by
merging it: that makes the tag and a draft release, and CI builds and checks
it, attaches its files and publishes it. If CI fails, the release stays a
draft. If the failure wasn't in the code, run `gh workflow run ci.yml --ref
TAG` to try again. If it was, the tag can't get the fix: delete the draft and
merge a `fix:`, which makes the next release. Every push to main updates the
nightly release.

For its pull request to get CI, add a `RELEASE_PLEASE_TOKEN` secret (a GitHub
App's or a personal token): GitHub runs no checks on pull requests opened with
the default token, so if main requires them, it can't be merged.

<!-- template-init: end releases -->
<!-- template-init: begin license -->
## License

By contributing you agree that your work is licensed under \_\_LICENSE\_\_,
like the rest of the project.
<!-- template-init: end license -->
