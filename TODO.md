# Messages

## From DBIx-Squirrel, 2026-11-09: go ahead with v0.2.0

**From:** DBIx-Squirrel 27f6be0b298591018d680048fe67ce01a89a8277, on
its branch `experiment/2026-0006-ekorn-v0.2.0-messages`

DBIx-Squirrel's task 1, from 76af6f4d64e9f82eb39c13487f4c85384a09cdcf,
steps 1, 2 and 4: its copies of the two messages now use the new
wording, in its DIAGNOSTICS, its reference's table and the four test
files, and its tests pass against your `develop` at
c5157c94fa9d65615c1b78bc7673e43dbd8823dd (your `lib` is the same at
ee68330), with your `lib` first on `PERL5LIB`: 1,500 assertions on
5.36.3, 5.38.5, 5.40.5, 5.42.3 and 5.44.0, `xt/howto.t` and
`xt/manuals.t` among them, so each section of your manuals it links
to is still there. Nothing was found. Against v0.1.3, only the four
files fail, on the old wording, as expected.

Its record is 2026-0006, on that branch. The work stays there until
v0.2.0 is on CPAN. So your release task's step 4 should send its task
to that branch's `TODO.md`, not `develop`'s, as DBIx-Squirrel's
CLAUDE.md says while an experimental branch carries the work.

One thing found on the way, for your tests if they have the same
shape: under `/x`, `qr( \QExpected stage #2 ...\E )x` doesn't work, as
Perl reads the `#` as starting a comment before `\E` takes effect.
DBIx-Squirrel's `t/05-pipeline.t` escapes the spaces instead.

# Planned work

## Release v0.2.0

**From:** Ekorn-Pipeline's session, 2026-11-09 (Ekorn-Pipeline
c5157c94fa9d65615c1b78bc7673e43dbd8823dd)
**Waiting on:** DBIx-Squirrel's message, in this file, saying its
tests pass against Ekorn-Pipeline's `develop` with its copies of the
two messages changed (its task 1, step 4, from
76af6f4d64e9f82eb39c13487f4c85384a09cdcf)

**What:** release v0.2.0, with roadmap 2026-0008: the two messages say
a stage can be a code reference or a pipeline, as `Changes` says under
Unreleased. It's v0.2.0, not v0.1.4, as it changes messages. Iain
gated it on DBIx-Squirrel's message on 2026-11-09, as he did v0.1.3:
DBIx-Squirrel matches the old wording in four test files, and must
follow before it moves its range.

**Steps:**

1. Read DBIx-Squirrel's message. If it found a problem, fix it here
   first and tell it, so it can try again.
2. Remove the message, and this task, with this file, in a commit
   before the release, as `TODO.md` never reaches `main`.
3. Release, as `docs/MAINTAINING.md`'s Making a release says: the
   version v0.2.0, `Changes`' Unreleased heading dated and opened with
   a one-line summary for the tag's title, 2026-0008's record "shipped
   in v0.2.0", and `main` moved to `develop`.
4. Tell DBIx-Squirrel, with a task in its `TODO.md`: v0.2.0 is on
   CPAN, so it can raise `cpanfile`'s range to `>= v0.2.0, < v0.3.0`
   and bring its changes to `develop` (its task 1, step 5).

**Done when:** v0.2.0 is on CPAN and indexed, `main` is at its signed
tag, and DBIx-Squirrel has its task.
