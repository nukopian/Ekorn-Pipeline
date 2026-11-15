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

## No secret whole in a message, and .gitleaksignore, for here and DBIx-Squirrel

**From:** Text-Redact-Secrets' session, 2026-11-15 (Text-Redact-Secrets
6c2ab4e2cb0c9cdf572c73ba785bce946e5062f4)
**Waiting on:** nothing

Iain asked for this to reach Ekorn-Pipeline and DBIx-Squirrel, as it
applies to every repository whose CI scans its history with gitleaks.
DBIx-Squirrel trades only with Ekorn-Pipeline, so the task is to read
it here, and pass it on to DBIx-Squirrel's `TODO.md`, as a message,
the way its CLAUDE.md says.

**What happened.** A message between two sessions, in a `TODO.md`,
quoted a made-up password from a test whole, beside its key, and was
pushed. gitleaks' scan of the whole history then failed on every push,
and removing the message didn't help, as history keeps it.

**The rule Iain made for it,** now in Text-Redact-Secrets' CLAUDE.md,
under Planned work: a message between sessions never holds a secret
whole, made-up or not. It's built from pieces, as a test's is, such as
`join '', 'AKIA', 'MADEUP', ...`, or left out.

**If one reaches published history anyway,** rewriting a published
branch means resetting every clone and changing every hash written
since. What Iain chose instead (its record 2026-0001's D14):

- A `.gitleaksignore` at the top of the repository, listing that one
  finding by its fingerprint: commit, file, rule and line, as
  `gitleaks git --redact -f json -r report.json .` gives it, in each
  finding's `Fingerprint`.
- A comment above it giving the reason, as it's a decision of Iain's.
- Nothing else is passed over, so a real secret still fails CI.
  gitleaks reads the file in CI's scan too. Minilla leaves dotfiles out
  of the tarball, so it doesn't ship.

**One more thing to watch:** a full commit hash in a file that also
holds one of gitleaks' keywords, such as a rule's name, can look like a
secret to gitleaks. Running `gitleaks dir .` before a docs commit
catches it before it's pushed.

Whether each repository takes on the rule is Iain's to decide. Done when
it's read here, and DBIx-Squirrel's `TODO.md` has it as a message.
