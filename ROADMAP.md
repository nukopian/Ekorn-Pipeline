# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0035.

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

### 2026-0033. One try for each pulled value

**Added:** 2026-11-14. **Size:** S (2)

Run a source's step in the same `try` as the stages, so each pulled
value enters one, not two. Tried on 2026-11-14 for 2026-0025's D7: 1
to 2% faster with stages and 6% slower with none, for a more intricate
loop, so set aside until after v0.3.0. Its
[record](docs/changes/2026-0033-one-try.md) has the measurements, and
what might yet pay.

### 2026-0035. Subs by name as stages

**Added:** 2026-11-14. **Size:** S (2)

Let `pipeline`, through `pipeline_in`, take a name that isn't a named
pipeline as the sub of that name in the caller's package, so plain
subs read as a path: `pipeline(trim => normalise => top5 =>)`. Named
pipelines win, so nothing that works now changes; to settle: builtins
such as `uc`, by `\&CORE::uc`, or not; looked up as the pipeline is
made, as names are now, so a typo croaks at once; `new` left as it is;
and the messages that say what a stage may be.
