# Security

## Reporting a vulnerability

Please don't open a public issue. Report it privately instead, from the
repo's Security tab: [Report a vulnerability](https://github.com/hugoocoto/c-tool/security/advisories/new),
or by email to hugocoto100305@gmail.com.

Say what you found, how to reproduce it and which version (`__NAME__
--version`). You'll get an answer within a week. Once it's fixed and
released, the advisory is published with credit to you, unless you'd rather
not.

## Supported versions

Fixes go into the next release, and into [nightly](https://github.com/hugoocoto/c-tool/releases/tag/nightly)
as soon as they're on main. Older releases aren't patched: update with the
[install script](../README.md#install).

## What's covered

The program, the release files and the install script. The release files
are attested: `gh attestation verify <file> --repo hugoocoto/c-tool` checks
that one was built by this repo's CI. Something that passes that check but
wasn't built from this repo is a vulnerability too.
