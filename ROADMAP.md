# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0012.

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

### 2026-0011. A pipeline() function, and named pipelines

**Size:** M (3)

An exported `pipeline(...)` that makes a pipeline from stages, where a
stage is a code reference, a pipeline, or the name of one:
`pipeline('active_roles' => take(5))`. Names are kept per package, and
can be qualified, defined as the program runs with
`Ekorn::Pipeline->named(name => @stages)`, or `$p->named('name')`.
A pipeline given last to a function is stages, not a value, so a
function whose values may be code references can still take stages
from its caller. Why: one way to make, name and reuse pipelines, and
an unambiguous way to pass stages. Done when the function, `named`,
the convention, their tests and their docs are in, with
coverage above the floors. Its questions are settled: see its
[record](docs/changes/2026-0011-pipeline-function.md).

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

### 2026-0012. A named pipeline with a source of its own

**Added:** 2026-11-10. **Size:** S (2). **Depends on:** 2026-0010

A definition that starts with a source, a function making the values,
as a statement makes its rows, so its function, called with no values,
still has something to give, and takes stages as a pipeline given
last: `recent(pipeline(take(5)))`. Moved from 2026-0010's D2, where a
function and `pipeline(@stages)` were found to cover it for now, and
how a source is told from a first stage, such as by a key,
`recent => [source => sub {...}, @stages]`, is still to settle.
