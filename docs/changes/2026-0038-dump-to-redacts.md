# 2026-0038. Secrets redacted by dump_to

**Status:** shipped, unreleased

**Decisions:** D1 settled: redacts by itself when Text::Redact::Secrets
is installed and passes a self-test, and croaks if it doesn't. D2
settled: a package global, `local`ised, stops it when true. D3
settled: `$DumpSecrets`. D4 settled: looked for once, at the first
dump. D5 settled: the text redacted, not the value. D6 settled: a
v0.3.x, and a message to DBIx-Squirrel. D7 settled: versions
`>= v1.0.0, < v2.0.0`, `recommends` in `cpanfile`. D8 settled: no
limit on what's redacted. None open.

**Origin:** roadmap, added 2026-11-15, split from 2026-0036

**Depends on:** Text-Redact-Secrets 2026-0001, its first release;
2026-0037 until 2026-11-15, when it moved there

**Started:** 2026-11-15

**Finished:** 2026-11-15

## Background

A dump is often written to a log, and a value holding a password, a
token or a DSN leaks it there. Text-Redact-Secrets 2026-0001, at first
this repository's 2026-0037, makes Text::Redact::Secrets, a module of
gitleaks' rules with a function that puts `*REDACTED*` in place of each
secret in a string. `dump_to`, in Ekorn::Pipeline::Stages::Taps, writes
each value with Data::Dumper, `local`ising `$Data::Dumper::Indent`,
`Sortkeys` and `Terse` as it does. DBIx::Squirrel imports `dump_to` by
name.

Text-Redact-Secrets' session sent what it built, in three messages on
2026-11-15 (Text-Redact-Secrets
c12b8993722b2b62fc2b3aeff108f2faa461a5c2,
f65876f9bd344e79c7526db210c6b3fbf50b35fb and
7656bb561800b122912db941640e34c7ef741c3d):

- **`redact($string)`** returns a copy with each secret replaced by
  `*REDACTED*`, and croaks on `undef` or a reference. v1.0.0-TRIAL,
  v1.0.1-TRIAL and v1.0.2-TRIAL are on CPAN, and v1.0.2, the first
  stable release, came on 2026-11-15, its code the same as
  v1.0.2-TRIAL's.
- **For the self-test:** `generic-api-key`, which finds a
  `'password' => '...'` in a dump, passes over a value with a word in
  it, such as "fake", "example", "test" or "password", and one with
  too little entropy. A made-up secret for it should look random, as
  `Zq8vR2mXkP4wL9nT` does, or be one a specific rule finds, such as an
  AWS access key id, and be built from pieces, so that no line of
  Ekorn's holds a secret whole for gitleaks or push protection to
  find. Its `t/04-by-hand.t` has examples.
- **Its cost,** as it measured: about 8 ms to compile the rules at the
  first call, and about 8 ms for a dump of a few hundred rows.

Tried here on 2026-11-15, with v1.0.1-TRIAL in
`perl-5.36.3@ekorn-pipeline`, on Data::Dumper's text as `dump_to`
writes it: a row's `password`, the password in a `postgres://` DSN and
an AWS key id were each redacted, and a `fake_pw` of `password` left
as it was. The first call took 8.8 ms. The cost of 300 rows depends on
the secrets in them, not their length: 1.0 ms for rows with none (31k
characters), 5.9 ms with a DSN in each, and 44 ms with a `password` or
an AWS key id in each, about 0.15 ms a secret found.
Text-Redact-Secrets made that cost grow in step with the secrets found
(Text-Redact-Secrets df09448641e423346d699dc47d3c04774fe2d21e), and
v1.0.2-TRIAL, tried the same way, redacted the same secrets, with 14
ms for a `password` in each row and 20 ms for an AWS key id.

## Decisions

- [x] **D1.** Opt in or out? **Redaction is on by itself whenever
  Text::Redact::Secrets is installed, with nothing to ask for it,**
  Iain decided on 2026-11-15: the right thing with the least friction.
  Without the module, `dump_to` is as it was, so it adds no
  dependency.

  **Refined the same day: installed isn't enough; it must work.** The
  first time a dump is written, once Text::Redact::Secrets has loaded
  (D4), `dump_to` runs a self-test: it redacts a few known secrets and
  checks each is gone. The result is kept for the rest of the process,
  as D4's answer is, so the test costs one dump's worth, once. If the
  module fails to load, or fails the test, `dump_to` croaks, saying so,
  and that a `local $Ekorn::Pipeline::Stages::Taps::DumpSecrets = 1`
  dumps without redacting. A redactor that's there but doesn't work
  would otherwise let secrets through as if they were safe, and a dump
  that's meant to be redacted is better not written than written in
  full; turning redaction off is then asked for, as D2 has it, not
  fallen into. With `$DumpSecrets` true, neither the load nor the test
  is tried. This settles D4's "reported": it croaks. The message is one
  of Ekorn's, raised with `croakf`, and goes in Taps' DIAGNOSTICS.
- [x] **D2.** How is it turned off? **By a package global, true to stop
  redacting, `local`ised as Data::Dumper's are,** Iain decided on
  2026-11-15: what's unsafe is what's asked for, and only for as long
  as it's needed, `local` putting it back after. It's read as each
  value is dumped, not when the stage is made, so a `local` around a
  run, or inside a stage before it, takes effect.
- [x] **D3.** The global's name?
  **`$Ekorn::Pipeline::Stages::Taps::DumpSecrets`,** Iain decided on
  2026-11-15, as he proposed, over the `ShowSecrets` first recommended:
  it's bound to the tap it governs, read as "`dump_to`: dump secrets",
  where `ShowSecrets` could be taken for all of Taps, or the pipeline.
  It still names, as Data::Dumper's globals do, what setting it does,
  so code that sets it says plainly that it writes secrets out. It's
  `dump_to`'s alone: a tap that redacts later takes a switch of its
  own, so turning off one doesn't turn off the other.
- [x] **D4.** How `dump_to` looks for the module, and when? **By
  `require` in an `eval`, once, the first time a dump is written, the
  answer kept for the rest of the process; a module found but failing
  to load is reported, by a croak (D1), not taken as absent,** Iain
  decided on 2026-11-15, as recommended. Each time would cost every
  dump; at load, it would load the module for code that never dumps.
  A module that's there but broken, taken as absent, would let secrets
  through without a word, the failure D1 is there to prevent.
- [x] **D5.** The dumped text redacted, or the value? **The text,**
  Iain decided on 2026-11-15, as recommended. Text::Redact::Secrets
  works on strings; Data::Dumper's text keeps each key beside its
  value, which gitleaks' rules look for; and the value isn't copied or
  touched, so what goes on down the pipeline is what came in.
- [x] **D6.** Which version, and what DBIx-Squirrel is told? **A
  v0.3.x, with a message to DBIx-Squirrel,** Iain decided on
  2026-11-15, as recommended. It adds: nothing changes unless a new
  module is installed, and what changes then is only what's written to
  a dump, not what a stage sees, nor any message there was before. The
  croak D1 adds is a new message, not a change to one. DBIx-Squirrel
  imports `dump_to`, so it's sent a message saying what its users'
  dumps will do once Text::Redact::Secrets is installed, the croak if
  it's broken, and `$DumpSecrets`.
- [x] **D7.** Which versions of Text::Redact::Secrets does `dump_to`
  take? **`>= v1.0.0, < v2.0.0`; a version outside the range is
  treated as a failed self-test (D1), and `cpanfile` names it as
  `recommends 'Text::Redact::Secrets', '>= v1.0.0, < v2.0.0'`,** Iain
  decided on 2026-11-15, in Text-Redact-Secrets' session, which sent
  it here as a message. Its version moves the first number only for a
  change to what `redact` or `find` take or return, so a v2.0.0 can't
  break `dump_to` before Ekorn has tested it and moved the range; one
  comes here as a task. `recommends` tells installers it's worth
  having, without making it a dependency, as D1 has it.
- [x] **D8.** A limit on how much text `dump_to` hands to `redact`?
  **None,** Iain decided on 2026-11-15, as recommended.
  Text-Redact-Secrets' v1.0.1 message said a few of gitleaks' rules
  backtrack in Perl on text made to be awkward, the worst taking about a
  fifth of a second for 40,000 characters, and that a dump of untrusted
  data might want a limit. But text past a limit would be either written
  unredacted, which is what 2026-0038 is there to stop, or cut off,
  losing what a dump is for; `dump_to` is a tap for debugging, rarely
  given hostile text; and Text-Redact-Secrets 2026-0006, making every
  rule linear, fixes the cause.

## The plan

What: `dump_to` redacts each dump with Text::Redact::Secrets' `redact`
whenever the module is installed, in the range D7 gives, and passes a
self-test, as D1 to D8 say; and croaks, with advice, when the module
is there but fails to load, is outside the range, or fails the test.
`$Ekorn::Pipeline::Stages::Taps::DumpSecrets`, true, turns it off.

Why: a dump written to a log shouldn't leak a password, a token or a
DSN, and a user who has the module shouldn't have to ask for that.

Steps:

1. **Taps:** `our $DumpSecrets`, read as each value is dumped (D2).
   At the first dump with it false, look for the module (D4):
   `require` in an `eval`; "Can't locate Text/Redact/Secrets.pm" is
   absent, and dumps are as they were; any other error, a version
   outside `>= v1.0.0, < v2.0.0` (D7), or a failed self-test is
   broken. The self-test redacts a few made-up secrets, built from
   pieces, as Text-Redact-Secrets advises, in the text Data::Dumper
   writes for them: a `password` that looks random, a DSN's password
   and an AWS access key id; each must be gone. The answer, `redact`,
   absent or broken with why, is kept for the process. Broken croaks,
   with `croakf`, on that dump and each after, at the caller's line,
   saying why, and that
   `local $Ekorn::Pipeline::Stages::Taps::DumpSecrets = 1` dumps
   without redacting. The text is redacted, not the value
   (D5). No limit on what's redacted (D8).
2. **Tests,** in a test file of their own, with the real module when
   it's installed, and without it, and with one that fails to load,
   one outside the range and one that fails the self-test, each faked
   by a hook at the front of `@INC`; with `$DumpSecrets` true, neither
   the load nor the test is tried. A private function forgets the
   answer kept, for the tests alone. Coverage stays above the floors.
3. **`cpanfile`:** `recommends 'Text::Redact::Secrets', '>= v1.0.0,
   < v2.0.0'` (D7). **CI** installs it, with `--with-recommends` on
   each `cpanm --installdeps`, as Iain decided on 2026-11-15, so the
   tests run with the real module on every Perl; v1.0.2 is in each
   `@ekorn-pipeline` library, as he agreed the same day.
4. **Docs:** `dump_to`'s POD and Taps' DIAGNOSTICS; the reference and
   the how-to; the README if it says what `dump_to` writes; `Changes`,
   saying the croak is a new message, as D6 has it.
5. **Ship:** 2026-0038 leaves the roadmap for `Changes`, this record
   is finished, and DBIx-Squirrel is sent the message D6 gives.

Done when `dump_to` redacts as above, tested with the module, without
it, and with one that fails each way, with `$DumpSecrets` too, on every
Perl CI covers; documented in the POD, its DIAGNOSTICS, the reference
and the how-to, every example run; coverage above the floors; and
DBIx-Squirrel sent its message.

## What happened

- **Outcome:** as Done when says. `dump_to` redacts with the real
  module, v1.0.2, and the tests cover it with that, without it, and
  with fakes that fail to load, are v2.0.0 or v0.9.0, have a version
  that can't be read, have no `redact`, or fail the self-test five
  ways: redacting nothing, missing the password, missing the key id,
  taking the secrets out without `*REDACTED*`, dying, and returning a
  reference. Each croaks at the caller's line, on the first dump and
  the next, having written nothing, and the module is looked for once.
  With `$DumpSecrets` true, it's neither loaded nor tested. The whole
  suite passes on each Perl from 5.36.3 to 5.44.0, coverage is above
  every floor, and the how-to's examples run.
- **Changes from the plan:**
  - The croak reaches the caller as every error in a stage does,
    after "Pipeline stage #1 failed at ... line ...:", as
    Ekorn::Pipeline's DIAGNOSTICS says, with the message indented
    under it.
  - A module that fails to load is reported with the first line of
    its error, without Perl's "Compilation failed in require" after
    it.
  - Two more reasons than the plan named, each a case of broken: a
    version that can't be read, and no `redact`.
  - The README needed no change: it says what `dump_to` is for, not
    what it writes.
- **Waiting on the CPAN index:** v1.0.2 reached MetaCPAN at 20:17 UTC,
  but the index `cpanm` reads hadn't listed it when this shipped, so
  CI's `--with-recommends` would have found nothing to install; the
  push waited for it.
