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
  says.
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

**Origin:** roadmap, added 2026-11-07 | a TODO task from DBIx-Squirrel's session (DBIx-Squirrel-2 <commit>)

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

- [A pipeline in scalar context](2026-0003-pipeline-in-scalar-context.md),
  roadmap 2026-0003: open.
- [An iterator after a stage dies](2026-0002-iterator-after-a-stage-dies.md),
  roadmap 2026-0002: open.
- [A stages() method](2026-0001-stages-method.md), roadmap 2026-0001:
  open.
