# Security

## Reporting a vulnerability

Please don't open a public issue. Report it privately instead, from the
repo's Security tab: [Report a vulnerability](https://github.com/hugoocoto/c-tool/security/advisories/new),
or by email to hugocoto100305@gmail.com.

Say what you found, how to reproduce it and which version (`__NAME__
--version`). You'll get an answer within a week. Once it's fixed, the
advisory is published with credit to you, unless you'd rather not.

## Supported versions

Fixes go on main as soon as they're ready.
<!-- template-init: begin releases -->
They're in [nightly](https://github.com/hugoocoto/c-tool/releases/tag/nightly)
right away, and in the next release. Older releases aren't patched: update
to the latest one.
<!-- template-init: begin install -->
The [install script](../README.md#install) does that.
<!-- template-init: end install -->

## What's covered

The program and everything in its releases. The release files are
attested: `gh attestation verify <file> --repo hugoocoto/c-tool` checks that
one was built by this repo's CI. Something that passes that check but wasn't
built from this repo is a vulnerability too.
<!-- template-init: end releases -->
