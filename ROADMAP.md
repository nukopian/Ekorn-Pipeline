# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0008.

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

### 2026-0008. Messages that say what's accepted

**Size:** S (2)

What: make the messages, and anything like them, say what Ekorn
accepts now that a pipeline can be a stage, in v0.2.0. Two are known.
"Expected stage #%d to be a code reference" is raised for something
that's neither a code reference nor a pipeline, so it should say
"...a code reference or a pipeline". "Expected stage #%s, made with
gather, to return one or two code references" is raised when a
`gather` block returns something other than a stage, which may be a
pipeline, and an optional end function. Before changing them, sweep
the messages, DIAGNOSTICS, the reference and the how-to for others
written before pipelines were stages, and fix those in the same
release.

Why: a message is the first thing a user reads when something goes
wrong, and these two point them to the wrong fix. 2026-0004 left them
unchanged (its D3), and 2026-0007 likewise, as a message change makes
v0.2.0. Iain put this first in Next on 2026-11-09, after v0.1.3, to
gather such fixes into that release.

Done when: every message, and every DIAGNOSTICS entry, names what's
accepted; the reference and the how-to no longer explain old wording
away; the tests check the new messages; and DBIx-Squirrel has a task
to test v0.2.0 and move its range to `>= v0.2.0, < v0.3.0`, as
CLAUDE.md's rule for v0.2.0 says, with its own copies of the messages
(its DIAGNOSTICS and reference) changed to match.

## Later

Nothing yet.

## Ideas

An idea is a numbered heading, the date it was added, its size, and a
line or two on what and why. Each is kept, promoted to Later or Next
with its id, or dropped, as Iain decides.

Nothing yet.
