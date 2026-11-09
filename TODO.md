# Planned work

## Release v0.1.3

**From:** Ekorn-Pipeline's session, 2026-11-09 (Ekorn-Pipeline
ce35c04334e0b9138bd90ac193c76a7c50f02be4)
**Waiting on:** DBIx-Squirrel's sign-off: a message in this file from
its session, saying it has used `is_stage` and a pipeline as a stage
against Ekorn-Pipeline's `develop`, and that its tests pass. (Roadmap
2026-0006, plain docs, which Iain put ahead of the release, is done.)

**What:** release v0.1.3, with roadmap 2026-0004 (a pipeline given as
a stage, nested names in messages, `is_stage`), 2026-0007 (a pipeline
returned by a `gather` block), 2026-0006's plainer docs, and the
README's MetaCPAN and Kwalitee badges, as `Changes` says under
Unreleased. DBIx-Squirrel's sign-off covers 2026-0007 too.
Iain gated the release on DBIx-Squirrel's sign-off on 2026-11-09:
DBIx-Squirrel is the first user, and its task (its `TODO.md`, task 1)
tries the feature in earnest before CPAN has it.

**Steps:**

1. Read DBIx-Squirrel's message. If it found a problem, fix it here
   first, and send it a message saying what changed, so it can try
   again; the release waits for a sign-off on the fixed `develop`.
2. Remove the message, and this task, with this file, in a commit
   before the release, as `TODO.md` never reaches `main`.
3. Release, as `docs/MAINTAINING.md`'s Making a release says: the
   version v0.1.3, `Changes`' Unreleased heading dated, the record of
   2026-0004 "shipped in v0.1.3", and `main` moved to `develop`.
4. Tell DBIx-Squirrel, with a task in its `TODO.md`: v0.1.3 is on
   CPAN, so it can raise `cpanfile`'s range to `>= v0.1.3, < v0.2.0`
   and release what its sign-off tested.

**Done when:** v0.1.3 is on CPAN and indexed, `main` is at its signed
tag, and DBIx-Squirrel has its task.
