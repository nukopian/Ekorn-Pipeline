# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0052.

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

### 2026-0052. A source's original, carried through chains

**Size:** S (2).

A source may give an `original` part, beside `step`, `end` and
`context`: a code reference returning the original of the value it
gave last. `result_original` calls it, when the run's source gave one
or an iterator read as a source passed one on, and otherwise gives the
run's own kept original, as now; a flush's values have none, either
way. So DBIx::Squirrel's statement source can carry its row through
chains with Ekorn's `result_original`, which becomes its own, and the
two Toolings can agree on the name (2026-0051). A v0.3.x. Done when
the core reads the part, the tests show it through a source, the
factory, an iterator read as a source, a flush and a feed, the docs
say so, and DBIx-Squirrel has tested against `develop`. Its decisions
are settled: [record](docs/changes/2026-0052-source-original.md).

## Later

### 2026-0051. Ekorn::Pipeline::Context's functions in Tooling, at v0.4.0

**Size:** XS (1). **Depends on:** 2026-0052.

Add `result_number` and `result_original` to Ekorn::Pipeline::Tooling,
in a `:context` tag, DBIx::Squirrel::Tooling's name for its own, and
in `:all`, in the first v0.4.0, with a task for DBIx-Squirrel. Not
before: DBIx-Squirrel v3.5.0's tests fail when both Toolings export
different subs by one name, and its range takes every v0.3.x. From
its v3.6.0, DBIx::Squirrel exports Ekorn's own `result_number`; once
2026-0052 lets its source carry its row through chains, its
`result_original` becomes Ekorn's own too, so the two Toolings agree
on both. Done when Tooling, its test, the reference, the how-to, the README and
Context's POD say so. From 2026-0046's D5
([record](docs/changes/2026-0046-context.md)).

## Ideas

An idea is a numbered heading, the date it was added, its size, and a
line or two on what and why. Each is kept, promoted to Later or Next
with its id, or dropped, as Iain decides.

### 2026-0039. Scan for secrets with betterleaks

Added 2026-11-15. **Size:** S (2).

Scan with betterleaks, gitleaks' successor, in place of gitleaks, once
it's settled: in CI's job over the whole history, and in the scans by
hand before a push and a tag that CLAUDE.md and docs/MAINTAINING.md
give. gitleaks gets no new rules, so its scans will slowly miss the
newer kinds of secret that only betterleaks finds.
