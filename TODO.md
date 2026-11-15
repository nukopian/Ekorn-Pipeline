# Messages

## From Text-Redact-Secrets, 2026-11-15: the versions dump_to can take

**From:** Text-Redact-Secrets' session, 2026-11-15 (Text-Redact-Secrets
c12b8993722b2b62fc2b3aeff108f2faa461a5c2)

Iain settled how Text::Redact::Secrets' version shows a change to
`redact` or `find`, which `dump_to` relies on:

- **Releases start at v1.0.0.** A change to what `redact` or `find`
  take or return moves the first number, to v2.0.0; new rules from
  gitleaks, or anything added that breaks nothing, move the middle; a
  fix moves the last. Ekorn's v0.x rule didn't fit, as the module's
  D9 already gives the middle number to new rules.
- **Ekorn takes `>= v1.0.0, < v2.0.0`,** Iain decided: `dump_to`
  treats a version outside that range as it would a failed self-test,
  so a v2.0.0 can't break it before Ekorn has tested it and moved the
  range. A v2.0.0 comes here as a task. That also answers step 2 of
  "Ship 2026-0038, and release" below: `cpanfile` names it as
  `recommends 'Text::Redact::Secrets', '>= v1.0.0, < v2.0.0'`, unless
  Iain says otherwise when 2026-0038's plan is written.

Text-Redact-Secrets' CLAUDE.md, "The version says what Ekorn can
take", has the rule.

## From Text-Redact-Secrets, 2026-11-15: v1.0.0-TRIAL is on CPAN

**From:** Text-Redact-Secrets' session, 2026-11-15 (Text-Redact-Secrets
f65876f9bd344e79c7526db210c6b3fbf50b35fb)

Text::Redact::Secrets v1.0.0-TRIAL is on CPAN, as a developer release:
`cpanm --dev Text::Redact::Secrets` installs it, if 2026-0038 wants to
test `dump_to` against it before v1.0.0, which follows once CPAN
Testers' reports are clean, with a task here. What it is, as built:

- **`redact($string)`** returns a copy with each secret replaced by
  `*REDACTED*`, overlapping secrets once; **`find($string)`** returns
  each as `{ rule => $id, secret => $secret, offset => $offset }`, in
  the order they appear. Both are `@EXPORT_OK`, and both croak,
  from the caller's line, on `undef` or a reference: "Expected a
  string to redact", or "to search".
- **The rules are gitleaks' v8.30.1, and one of its own,**
  `url-userinfo-password`, for a password in a URL such as
  `postgres://user:password@host/db`, which gitleaks has no rule for
  and won't add: its maintainer says it adds no more rules (its
  record's D12).
- **For `dump_to`'s self-test:** `generic-api-key`, which finds a
  `'password' => '...'` in a dump, passes over a value with a word in
  it, such as "fake", "example", "test" or "password", and one with
  too little entropy. A made-up secret for the self-test should look
  random, as `Zq8vR2mXkP4wL9nT` does, or be one a specific rule finds,
  such as an AWS access key id; its `t/04-by-hand.t` has examples,
  each built from pieces, so that no line of a test holds a secret
  whole for gitleaks or push protection to find.
- **Its cost:** the first call compiles the rules, in about 8 ms; a
  Data::Dumper dump of 300 rows then takes about 10 ms.


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
   decision settled there. Installing Text::Redact::Secrets into the
   perlbrew libraries, to test with it, is asking Iain first, unless
   it's in `perl-5.36.3@dbix-squirrel-2`. Whether `cpanfile` names it,
   as `recommends` or not at all, is Iain's to decide, as D1 says
   nothing about it.
3. **Ship it** as its Done when says, with its message to
   DBIx-Squirrel, as D6 says.
4. **Release,** a v0.3.x, as docs/MAINTAINING.md's "Making a release"
   says, once this file is gone: remove this task in the commit that
   ships 2026-0038, or the release's, and the file with it.

Done when the release is on CPAN and DBIx-Squirrel has been told.
