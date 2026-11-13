# Change records

How each planned change to Ekorn-Pipeline went: its decisions, the
plan as it was written, then what happened. [Changes](../../Changes)
says what changed for users; a record keeps the thinking behind it,
for anyone looking back, including whoever plans the next change.

A record is opened for a [roadmap](../../ROADMAP.md) item when it
first has a question to settle, or when work on it starts, and for a
task in `TODO.md` with steps. A planned change that's dropped keeps its
record, saying why, as dead ends are the history most worth having.
Small fixes don't need one.

## How a record is kept

- **It's named for its id, then the change,** such as
  `2026-0001-stages-method.md`. A roadmap item's id is the item's; a
  `TODO.md` task's record takes the next id from the roadmap's opening,
  in the same sequence, though the task never appears there. So records
  sort in the order their ids were given, and their names line up.
- **Its questions are settled first.** Each is numbered in Decisions,
  unchecked while open. Once settled, in the chat with Iain, it's
  checked, with the answer, the date and why. Work starts only once
  each is checked, or moved to another item or task, which the record
  says. A **Decisions:** line under the status sums them up, each
  settled or open in a few words, so the record's state shows at a
  glance; it changes in the commit that settles one.
- **The plan is written when work starts, and isn't edited after.**
  What changed goes under What happened, so the record shows how the
  plan held up.
- **What happened is added as the work goes,** and finished when the
  change ships or is dropped, in the same commit. When it ships, the
  status says "shipped, unreleased", and the release names its version.
- **It's public,** on GitHub and `main`, though not in the CPAN
  tarball, so nothing personal goes in it. There's no PDF of it.

## The template

```markdown
# 2026-0001. Title

**Status:** open | in progress | shipped, unreleased | shipped in v0.1.1 | dropped

**Decisions:** D1 settled: the answer, in a few words. D2 open: the question, in a few words. | None.

**Origin:** roadmap, added 2026-11-07 | a TODO task from DBIx-Squirrel's session (DBIx-Squirrel <commit>) | a message from DBIx-Squirrel's session, 2026-11-08 (DBIx-Squirrel <commit>)

**Depends on:** 2026-0003, if anything

**Started:** 2026-11-08, in <commit>

**Finished:** 2026-11-09

## Background

What's known before the plan: the problem, what was tried, and what it
showed.

## Decisions

- [x] **D1.** The question? The answer, on 2026-11-07, and why.
- [ ] **D2.** A question still open? The options, and the
  recommendation.

## The plan

The plan as it was when work started, word for word: What, Why,
Steps, Done when.

## What happened

- **Outcome:** against Done when.
- **Changes from the plan,** and why.
- **Measurements,** and how they were taken.
- **Tried and reverted,** with the numbers.
- **What's left,** linked to its roadmap item or `TODO.md` task.
```

## Records

Newest id first.

- [One design, end to end, before more is built](2026-0022-one-design.md),
  roadmap 2026-0022: approved, and split into items.
- [Ekorn::Pipeline::Factories](2026-0021-factories.md), roadmap 2026-0021:
  in progress.
- [pipeline() through a subclass makes the subclass](2026-0020-subclass-pipeline.md),
  a TODO task from DBIx-Squirrel: shipped, unreleased.
- [The lifecycle: sources, stages, sinks and their ends](2026-0014-lifecycle.md),
  roadmap 2026-0014: shipped, unreleased.
- [A pipeline() function, and named pipelines](2026-0011-pipeline-function.md),
  roadmap 2026-0011: shipped, unreleased.
- [Named pipelines at compile time](2026-0010-named-pipelines.md),
  roadmap 2026-0010: open.
- [A CPAN badge that keeps up with releases](2026-0009-cpan-badge.md),
  roadmap 2026-0009: shipped, unreleased.
- [Messages that say what's accepted](2026-0008-messages-say-whats-accepted.md),
  roadmap 2026-0008: shipped in v0.2.0.
- [A pipeline returned by a gather block](2026-0007-gather-pipeline.md),
  roadmap 2026-0007: shipped in v0.1.3.
- [Plain docs](2026-0006-plain-docs.md), roadmap 2026-0006: shipped in v0.1.3.
- [The reference and the how-to on MetaCPAN](2026-0005-manuals-on-metacpan.md),
  a TODO task from DBIx-Squirrel: shipped in v0.1.2.
- [A pipeline given as a stage](2026-0004-pipeline-as-a-stage.md),
  roadmap 2026-0004: shipped in v0.1.3.
- [A pipeline in scalar context](2026-0003-pipeline-in-scalar-context.md),
  roadmap 2026-0003: shipped in v0.1.1.
- [An iterator after a stage dies](2026-0002-iterator-after-a-stage-dies.md),
  roadmap 2026-0002: shipped in v0.1.1.
- [A stages() method](2026-0001-stages-method.md), roadmap 2026-0001:
  shipped in v0.1.1.
