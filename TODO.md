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
