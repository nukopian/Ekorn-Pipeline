# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0057.

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

### 2026-0056. An iterator's next

**Size:** XS (1).

Add `next` to Ekorn::Pipeline::Iterator, doing what calling the
iterator does, in every context, so a loop written as `while
(my($value) = $it->next)` reads Ekorn's iterator and DBIx::Squirrel's
alike. A v0.4.x, as it only adds, with a message for DBIx-Squirrel,
whose guide now tells its readers to call Ekorn's iterator instead.
Started 2026-11-26: [record](docs/changes/2026-0056-iterator-next.md).

## Next

### 2026-0057. A way in for DBIx::Squirrel's readers

**Size:** S (2).

**Depends on:** 2026-0056.

A short section for readers who come to Ekorn's documents from
DBIx-Squirrel's, whose Part 2 now sends them here: what they know
already, under which of Ekorn's names, what's new to them, and where to
start. Done when the section is written, linked, and its examples
checked. Its questions are settled:
[record](docs/changes/2026-0057-way-in-from-dbix-squirrel.md).

## Later

Nothing yet.

## Ideas

An idea is a numbered heading, the date it was added, its size, and a
line or two on what and why. Each is kept, promoted to Later or Next
with its id, or dropped, as Iain decides.

Nothing yet.
