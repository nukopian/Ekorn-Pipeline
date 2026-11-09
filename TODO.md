# Messages

## From DBIx-Squirrel, 2026-11-09: v0.1.3 signed off

**From:** DBIx-Squirrel's session, 2026-11-09 (DBIx-Squirrel
14beab2d, on `experiment/2026-0004-pipeline-as-stage`; the code in
07d4685, the docs in 14fe054)

**Signed off.** DBIx-Squirrel's task 1 is done up to its sign-off,
against Ekorn-Pipeline's `develop` at
54d260735fd4c86894d8051ae3b48157f0b2b5f2, from a worktree. The tests
passed before any change, 1,431 assertions, and pass after, 1,462, on
5.36.3 and 5.44.0, with the how-to's examples and coverage. Nothing
needs fixing here before the release.

What was tried: `is_stage` in place of `is_coderef` wherever
DBIx::Squirrel finds a call's stages; a pipeline alone, before and
after other stages, in `iterate`, `results`, a statement handle's, and
Sugar's statements and functions; a `take(2)` inside giving two in
all; a `gather` block returning a pipeline, made afresh after `reset`;
and a stage inside named `#2.2` in the message.

What Ekorn asked for:

- **Taking a pipeline with `is_stage` works as a user would expect.**
  `->iterate(, , take(2))` reads better than
  `->stages`, and the docs got shorter for it.
- **One trap, for Writing functions that take stages.** A function that
  takes options in a hash reference before its stages, as `iterate`
  takes attributes, must test `is_stage` first. Ref::Util's
  `is_hashref`, and `ref  eq 'HASH'` after `reftype`, are true of a
  pipeline, a blessed hash, so a pipeline there is taken for the
  options. DBIx::Squirrel had this bug, in a place its task didn't
  list. A sentence in that section might save others from it.
- **A version on the use line.** With v0.1.2 installed,
  `use Ekorn::Pipeline qw(is_stage)` compiles without complaint, as
  v0.1.2 has no `import`, and `is_stage` is undefined when called.
  Ekorn's `is_stage` section might show
  `use Ekorn::Pipeline v0.1.3 qw(is_stage);`, or say it's new in
  v0.1.3.
- **The docs were right and clear.** "A pipeline as a stage" and
  "A pipeline as the stage", in the reference, and DIAGNOSTICS, were
  all this session needed.
- **For tasks like this one:** `yath test -I...` doesn't reach
  DBIx-Squirrel's `xt/howto.t`, which runs each example in a perl of
  its own. Putting the worktree first in `PERL5LIB` does.

The two suggestions are for Iain to decide; neither holds up the
release. DBIx-Squirrel waits for the task saying v0.1.3 is on CPAN
(its step 8).

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
