# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0026.

Items come in four groups:

- **Now:** being worked on, each with a paragraph and a link to its
  [change record](docs/changes/README.md); never more than three, so
  that it stays a queue;
- **Next:** decided, but not started: what, why, and when it's done;
- **Later:** meant to be done, but not yet planned, in a line or two;
- **Ideas:** might be done, or never; kept so they aren't lost, in a
  line or two, newest last.

Now, Next and Later put the most useful first.

Each item has an id, its year and a serial, such as 2026-0001. The year
is when the item was added, and the serial counts from 0001, starting
again each year. An id is given when the item is added, whichever group
it goes in, and is kept as the item moves, so that 2026-0001 means the
same item in a commit message years later. It names the item's change
record, its line in Changes ("(roadmap 2026-0001)") and any branch for
it. The line above gives the last id allocated.

Each item has a size too, a guess at how much work it is, as a T-shirt
size and its story points: XS 1, S 2, M 3 and L 5. Sizes compare items
with each other; they aren't a measure of time. An item bigger than L
is split into items that aren't, each saying what it was split from.
An item that can't be done before another says so ("Depends on:"), and
is never in a group ahead of it.

An item whose questions aren't all settled says so, and its record
lists them. Work on it starts only once each is settled, or moved to
another item or task.

When an item ships, it leaves here for Changes. An item that's
dropped is deleted, and the commit that drops it names its id.

## Now

Nothing yet.

## Next

### 2026-0025. Release v0.3.0

**Size:** S (2)

**Depends on:** 2026-0013, 2026-0014, 2026-0016, 2026-0017, 2026-0018,
2026-0021, 2026-0024, 2026-0026

The design's release: the README rewritten for the stream concept
(the design's 20.1), `Changes`' precis naming the items it ships, the
manuals made again, and whether `docs/design/` and IMPLEMENTATION.md
stay once it's delivered decided. Then `pipeline-experimental` merges
to `develop`, v0.3.0 is released, and DBIx-Squirrel is handed a task
to test against it and move its range. Done when v0.3.0 is on CPAN,
and DBIx-Squirrel has its task.

### 2026-0010. Named pipelines at compile time

**Size:** S (2)

**Depends on:** 2026-0011

A module like DBIx::Squirrel::Sugar for pipelines:
`use Ekorn::Pipeline::Sugar pipeline => {name => [@stages]}` names
pipelines as the program compiles, with 2026-0011's names, and gives
the package a function of each name, which runs values through it,
taking more stages as a pipeline after them. Why: a pipeline used in
several places needn't be kept in a variable or wrapped in a sub.
Done when the module, its tests and its docs are in, with coverage
above the floors. Its questions are settled: see its
[record](docs/changes/2026-0010-named-pipelines.md).

## Later

Nothing yet.

## Ideas

An idea is a numbered heading, the date it was added, its size, and a
line or two on what and why. Each is kept, promoted to Later or Next
with its id, or dropped, as Iain decides.

### 2026-0019. A strict is_stage

**Added:** 2026-11-10. **Size:** S (2). **Depends on:** 2026-0021

An `is_stage` that accepts only Stage objects and pipelines, as a
function or an argument, so a function whose values can be code
references can take stages without 2026-0011's pipeline-last
convention, provided its callers write `stage {...}`. Made the
default, it would change behaviour: a v0.3.0, with a task for
DBIx-Squirrel. Weighed against 2026-0011's D2, which answers the same
need with plain subs: not now, as Iain decided on 2026-11-12
(2026-0022's D38). From DBIx-Squirrel's message, part 4.
The message, whole:
`git show 7cf473408d73add0eda3eae5ca3e0be6afaaf122:TODO.md`.
