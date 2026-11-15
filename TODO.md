# Planned work

## Ship 2026-0038, and release

**From:** Ekorn-Pipeline's session, 2026-11-15 (Ekorn-Pipeline
e4b9e8aa6b52627625906df1a5dac051aacfe2af)
**Waiting on:** Text-Redact-Secrets' first release on CPAN (its roadmap
2026-0001), which its session announces with a task here

Text::Redact::Secrets moved to a repository of its own,
`~/Git/github.com/nukopian/Text-Redact-Secrets`, on 2026-11-15, and
Iain went on with it in that repository's session. Once it's on CPAN,
pick up here:

1. **Read its task,** and any messages from it, and check what it
   released: `redact` and `find` as its record's D10 says, and its
   version (`curl -sSf https://fastapi.metacpan.org/v1/release/Text-Redact-Secrets | jq -r .version`).
2. **Start roadmap 2026-0038,** secrets redacted by `dump_to`: move it
   to Now, and write The plan in
   [its record](docs/changes/2026-0038-dump-to-redacts.md), every
   decision settled there. v1.0.1-TRIAL is in
   `perl-5.36.3@ekorn-pipeline`, installed with Iain's agreement on
   2026-11-15; installing it into the other libraries, for CI's range,
   is asking him first. `cpanfile` names it as D7 says.
3. **Ship it** as its Done when says, with its message to
   DBIx-Squirrel, as D6 says.
4. **Release,** a v0.3.x, as docs/MAINTAINING.md's "Making a release"
   says, once this file is gone: remove this task in the commit that
   ships 2026-0038, or the release's, and the file with it.

Done when the release is on CPAN and DBIx-Squirrel has been told.
