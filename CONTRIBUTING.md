# Contributing to template

Thanks for helping! Bug reports, ideas, docs and code are all welcome.

## Reporting bugs

[Open an issue](../../issues/new/choose) using the bug report form. The more
of this it has, the faster it gets fixed:

- what you ran (the command, and the config if it matters),
- what happened (the full output) and what you expected,
- the output of `template --version`, and how you installed it,
- your distro and architecture.

Search the open issues first: someone may have reported it already.

## Suggesting features

Open an issue describing the problem you want to solve, not just the
solution. For anything that needs more than a few lines of code, agree on it
in the issue before writing it: it saves everyone's time.

## Setting up

You need a C compiler (gcc or clang), make and Lua 5.1 or LuaJIT with its
headers: see [Building](README.md#building).

```sh
git clone --recursive https://github.com/<you>/template
cd template
make hooks   # run the tests before every push
make debug   # build with the sanitizers while working
make test
```

Editors that use clangd get the right flags from `src/.clangd` and
`test/.clangd`, and the code style from `.clang-format` and `.editorconfig`.

### Project layout

```
src/              the program, every .c is compiled to build/src/*.o
src/thirdparty/   git submodules: flag.h (flags), cum.h (macros), conf.h (Lua config)
test/             one self-contained test program per .c
docs/             the man page (template.1) and Typst documents
completions/      bash, zsh and fish completions
scripts/          install.sh, test.sh, release.sh, hooks/
assets/           the AppImage icon
```

## Making a change

1. Fork the repo and make a branch from main.
2. Make the change, with a test (see [Tests](#tests)).
3. Update the docs if it changes what users see (see [Documentation](#documentation)).
4. Check it: `make test`, `make test SANITIZE=thread` and `make check-format`.
5. Open a pull request, saying what it changes and why. Link the issue it
   fixes (`Fixes #123`).

CI runs the tests with gcc and clang, with every sanitizer. A pull request is
merged when CI is green and it has been reviewed. Small pull requests are
reviewed much faster than big ones: split them when you can.

## Code style

- C99 (`-std=c99`), with POSIX (`_DEFAULT_SOURCE`). No new warnings with
  `-Wall -Wextra`.
- Format with `make format` (it leaves `src/thirdparty/` alone). CI checks it
  with the clang-format version in the Makefile (`CLANG_FORMAT_VERSION`): if
  yours formats differently, install that one with
  `pip install clang-format==<version>` and run
  `make format CLANG_FORMAT=~/.local/bin/clang-format`.
- Functions that can fail return 0 on success and non-zero on error, and
  print the error themselves, starting with the program's name.
- Free what you allocate: the sanitizers fail the tests on any leak.
- Comments say why, not what. Keep them short.

## Tests

Every `test/*.c` is a self-contained program: it exits 0 if it passes and
anything else if it fails. `make test` builds the program and each test with
sanitizers, then `scripts/test.sh` runs the tests in random order from the
project root with a 10s timeout, and fails if any of them does.

The sanitizers make a test fail on things that would otherwise pass silently:

- `make test` (address,undefined): out of bounds accesses, use after free,
  double free, memory leaks, signed overflow, misaligned or NULL pointers...
- `make test SANITIZE=thread`: data races and lock order inversions. It
  can't be combined with the address sanitizer, so it's a separate run.

Writing tests:

- Tests can include anything in `src/` and `src/thirdparty/`, and link with
  pthreads and Lua.
- `$TEST_BIN` is the program, also built with the sanitizers, for tests that
  run it (see `test/cli.c`): a leak in the program fails those tests too.
- Tests don't depend on each other or on the order they run in.

## Documentation

A change users can see updates, in the same pull request:

- a flag: `--help` (in `src/main.c`), the man page (`docs/template.1`), the
  three files in `completions/` and Usage in the README,
- the config: the man page, `config.lua` and Configuration in the README.

Check the man page with `man docs/template.1`.

## Commit messages

One change per commit. The first line says what it does, in under 72
characters (`Add --quiet flag`, `Fix crash on empty config`). If it isn't
obvious, the body says why.

The first lines are the changelog and the release notes
(`scripts/changelog.sh`, `make changelog` to see it), grouped by their first
word:

| Starts with                                  | Goes in  |
|----------------------------------------------|----------|
| Add, New, Implement, Introduce, Support      | Added    |
| Fix, Correct, Repair                         | Fixed    |
| Remove, Delete, Drop                         | Removed  |
| anything else (Change, Update, Make...)      | Changed  |

So write them for users: `Fix crash on empty config`, not `fix bug`.

## Third-party code

`src/thirdparty/` holds git submodules. Dependabot opens a pull request every
week when they have new commits, and CI tests it. Fix bugs in them upstream;
to update one by hand:

```sh
git -C src/thirdparty/flag pull origin main
git add src/thirdparty/flag
```

## Releases

Maintainers release from main with `scripts/release.sh`, which asks for the
version (semantic versioning: X.Y.Z, bigger than the last one), suggesting the
next one from the commits' first words (Remove... makes it major, Add...
minor, the rest a patch; before 1.0.0, removing is minor too), and pushes its
tag. CI then builds and publishes the release. Every push to main updates the
nightly release.

## License

By contributing you agree that your work is licensed under the GPL-3.0 or
later, like the rest of the project.
