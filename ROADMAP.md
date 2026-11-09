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

What: every diagnostic raised because a stage wasn't a code reference
or a pipeline says so, in v0.2.0, and so does everything that quotes
or explains it: DIAGNOSTICS, the reference, the how-to, comments and
tests. As Iain put it, on 2026-11-09: "We are no longer JUST accepting
code-references." Two messages are known, worded to match
DBIx-Squirrel's, which already reads "Expected only code references or
pipelines after the statement for %s":

- "Expected stage #%d to be a code reference" becomes "Expected stage
  #%d to be a code reference or a pipeline". It's raised in
  `lib/Ekorn/Pipeline.pm`'s `new`, twice, and quoted in its
  DIAGNOSTICS, in `Errors.pm`'s `croakf` example, in the how-to's
  example of a mistake in making a pipeline, and in the reference's
  `new` section and Diagnostics.
- "Expected stage #%s, made with gather, to return one or two code
  references" is raised when a `gather` block returns something other
  than a stage (a code reference or a pipeline) and an optional end
  function, so it says that. It's quoted in both modules' DIAGNOSTICS
  and the reference's `gather` section, whose notes explaining the old
  wording go.

"Expected a code reference" stays: it's raised for a `gather` block,
an iterator's source, and the blocks of `take_while`, `drop_while`,
`collect` and `peek`, none of which is a stage. Before the change,
sweep `lib`, `t` and `docs` for any other text written when a stage
could only be a code reference.

Why: a message is the first thing a user reads when something goes
wrong, and these point them to the wrong fix. 2026-0004 and 2026-0007
left them unchanged (2026-0004's D3), as a message change makes
v0.2.0. Iain put this first in Next on 2026-11-09, for that release,
and asked, through DBIx-Squirrel's session, that comments be covered
too.

Done when: every such message, DIAGNOSTICS entry, comment, and
passage in the reference and the how-to names what's accepted; the
tests check the new wording; and DBIx-Squirrel has a task to test
v0.2.0, move its range to `>= v0.2.0, < v0.3.0`, and change its copies
of the two messages to match, as CLAUDE.md's rule for v0.2.0 says.

## Later

Nothing yet.

## Ideas

An idea is a numbered heading, the date it was added, its size, and a
line or two on what and why. Each is kept, promoted to Later or Next
with its id, or dropped, as Iain decides.

Nothing yet.
