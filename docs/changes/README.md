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

- [Ekorn::Pipeline::JSON](2026-0034-json.md), roadmap 2026-0034:
  shipped in v0.3.1.
- [One try for each pulled value](2026-0033-one-try.md), roadmap
  2026-0033: open, an idea.
- [Faster pulled runs](2026-0032-faster-pulled-runs.md), roadmap
  2026-0032: shipped in v0.3.1.
- [Ekorn::Pipeline::Tooling, one module to import from](2026-0031-tooling.md),
  roadmap 2026-0031: shipped in v0.3.1.
- [take_if and drop_if](2026-0030-take-if.md), roadmap 2026-0030: shipped in
  v0.3.1.
- [A single name gives the pipeline it names](2026-0029-single-name.md),
  roadmap 2026-0029: shipped in v0.3.1.
- [Fast paths](2026-0028-fast-paths.md), roadmap 2026-0028: shipped in
  v0.3.1.
- [The role methods in capitals](2026-0027-capital-role-methods.md),
  roadmap 2026-0027: shipped in v0.3.1.
- [Release v0.3.0](2026-0025-release-v0-3-0.md), roadmap 2026-0025:
  shipped in v0.3.1.
- [Role methods return their parts by name](2026-0026-named-parts.md),
  roadmap 2026-0026: shipped in v0.3.1.
- [Operators: `|`, `|=` and `@{}`](2026-0018-operators.md),
  roadmap 2026-0018: shipped in v0.3.1.
- [Sinks that come with Perl](2026-0017-sinks.md),
  roadmap 2026-0017: shipped in v0.3.1.
- [Sources that come with Perl](2026-0016-sources.md),
  roadmap 2026-0016: shipped in v0.3.1.
- [A named pipeline named in a stage's error](2026-0013-names-in-errors.md),
  roadmap 2026-0013: shipped in v0.3.1.
- [Canned stages as objects, and a take stage for each keep sink](2026-0024-canned-stages.md),
  roadmap 2026-0024: shipped in v0.3.1.
- [One design, end to end, before more is built](2026-0022-one-design.md),
  roadmap 2026-0022: approved, and split into items.
- [Ekorn::Pipeline::Factories](2026-0021-factories.md), roadmap 2026-0021:
  shipped in v0.3.1.
- [pipeline() through a subclass makes the subclass](2026-0020-subclass-pipeline.md),
  a TODO task from DBIx-Squirrel: dropped: undone by 2026-0021, before any release.
- [The lifecycle: sources, stages, sinks and their ends](2026-0014-lifecycle.md),
  roadmap 2026-0014: shipped in v0.3.1.
- [A pipeline() function, and named pipelines](2026-0011-pipeline-function.md),
  roadmap 2026-0011: shipped in v0.3.1.
- [Named pipelines at compile time](2026-0010-named-pipelines.md),
  roadmap 2026-0010: shipped in v0.3.1.
- [A CPAN badge that keeps up with releases](2026-0009-cpan-badge.md),
  roadmap 2026-0009: shipped in v0.3.1.
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
