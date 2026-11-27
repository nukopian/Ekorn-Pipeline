# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0061.

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

### 2026-0060. Where a value came from, through stages that hold values back

Started 2026-11-27. **Size:** L (5). A stage that holds values back
says so, keeps an origin for each value it keeps, and gives what it
made from it marked, so each value keeps its own original, as
`result_original` promises; stages written today don't change. A
v0.5.0, with a task for DBIx-Squirrel. Its
[record](docs/changes/2026-0060-where-a-value-came-from.md) has the
decisions and the plan.

## Next

Nothing yet.

## Later

Nothing yet.

## Ideas

An idea is a numbered heading, the date it was added, its size, and a
line or two on what and why. Each is kept, promoted to Later or Next
with its id, or dropped, as Iain decides.

### 2026-0059. Stages that run each value in worker processes

Added 2026-11-27. **Size:** L (5), and likely to be split once
designed. **Depends on:** 2026-0060.

Stages that run a caller's block for each value in a pool of forked
workers, so that a caller can make a function's slow work concurrent,
beside the call, with nothing of the function's changed:
`in_workers($n, sub { ... })`, giving results in the order the values
came; `in_workers_any`, giving them as they finish; and
`once_per($key, $n, sub { ... })`, running the block once per key and
joining each value with its key's results. Core Perl only, so its own
distribution, built on Ekorn's protocols, as 2026-0043 and 2026-0045
were meant to be. Prototyped, with tests and measurements, on the
branch `experiment/2026-0059-worker-stages`, whose
`docs/experiments/2026-0059-worker-stages/README.md` says what was
found. Stages after them see the wrong `result_original` until the
core can say where a value a stage held back came from: 2026-0060.

### 2026-0061. A stage given the chance to act between its inputs

Added 2026-11-27. **Size:** M (3).

A stage that holds values back gives them only when it's given a value
or flushed, so it can't give what's ready between inputs, such as
results back from workers or a batch by time, and a flush that has
given values can't then die without losing them. One answer would
serve both: a stage that says so is asked for what's ready between
inputs, and again as its input runs out, before its flush. Out of
2026-0060's D18, with DBIx-Squirrel's two conditions: something a
stage declares, so a feed's push of nothing still runs nothing for
other stages, and the error's message kept.
