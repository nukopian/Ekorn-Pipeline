# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0062.

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

Nothing yet.

## Later

Nothing yet.

## Ideas

An idea is a numbered heading, the date it was added, its size, and a
line or two on what and why. Each is kept, promoted to Later or Next
with its id, or dropped, as Iain decides.

### 2026-0059. Stages that run each value in worker processes

Added 2026-11-27. **Size:** L (5), and likely to be split once
designed.

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
found. With 2026-0060, in v0.5.0, they say where each result came
from, so the stages after them see the right `result_original`.

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

### 2026-0062. Tests that try to break each promise, here and in DBIx-Squirrel

Added 2026-11-27. **Size:** M (3).

2026-0060's fault hid in the gap between a promise and an assumption:
2026-0046's D3 promised each result its value's original, but the code
assumed every stage maps, and every test used maps, so no review tested
the promise against a stage that holds values back. Two things would
catch such a fault sooner: `xt/agreement.t`'s random pipelines taking
in stages that hold values back, split, stop and nest, and comparing
each result's original as well as its value; and, for each settled
decision that promises something of every value or every run, a test
that tries to break it with the stages it doesn't mention.

DBIx-Squirrel's process has the same weakness, and its promises, such
as its rows through its Context, rest on Ekorn's, so it's in the
discussion from the start: a message to it before anything is
designed, asking for its view, and which of its own promises it would
test so. The design is settled by messages both ways. It's concluded
only when both sessions agree one practice, each records it as its own
roadmap item and decisions, and Iain has decided both, so the two
projects review the same way.
