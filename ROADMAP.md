# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0004.

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

### 2026-0002. An iterator after a stage dies

**Size:** S (2)

When a stage dies while an iterator is read, the call dies with
"Pipeline stage #N failed". A caller who catches that and reads on
today finds the iterator carrying on, with the value that died dropped
and everything else kept, so an end such as `collect` reports on a run
that lost values. Nothing is promised either way, and DBIx::Squirrel's
users will read iterators in loops that catch errors, so it has to be
settled before v0.1. A change goes out as a new trial.

Its question is open: see its
[record](docs/changes/2026-0002-iterator-after-a-stage-dies.md).

**Done when:** what an iterator does after a stage dies is decided,
documented in the POD, the reference and the how-to, and tested.

### 2026-0003. A pipeline in scalar context

**Size:** XS (1)

Called in scalar context, a pipeline returns how many results came
out, as Perl gives an array's length. The how-to and the reference say
so, but the POD doesn't promise it, and `pipe` gives the first result
instead. It has to be settled before v0.1, as changing it after is a
v0.2.0.

Its question is open: see its
[record](docs/changes/2026-0003-pipeline-in-scalar-context.md).

**Done when:** what scalar context gives is decided, promised in the
POD, and tested.

### 2026-0001. A stages() method

**Size:** S (2)

A method returning a pipeline's stages as a flat list, so that they can
be spliced into another pipeline, or given to any function that takes
stages, DBIx::Squirrel's among them, with no change to them:

```perl
my $first_active = Ekorn::Pipeline->new(as_hash, sub { $_->{active} ? $_ : () }, take(10));
my @rows = $sth->iterate($id, $first_active->stages, pluck('name'))->all;
```

Stages that keep state are made afresh for each run, so sharing them
shares no state, and the outer pipeline gives what listing the stages
by hand would. It fills the gap left by refusing a pipeline as a stage,
with no change to `new`, the runner or any message. Whether it goes in
v0.1.0 is still open: see its
[record](docs/changes/2026-0001-stages-method.md).

**Done when:** `stages` is in Ekorn::Pipeline, tested, and documented in
the POD, the reference and the how-to, whose wrapper example uses it.

## Later

Nothing yet.

## Ideas

An idea is a numbered heading, the date it was added, its size, and a
line or two on what and why. Each is kept, promoted to Later or Next
with its id, or dropped, as Iain decides.

### 2026-0004. A pipeline given as a stage

**Added:** 2026-11-07. **Size:** M (3)

`new` would take a pipeline where a stage goes, composing its stages in
place, so `Ekorn::Pipeline->new($clean, take(10))` works without
`->stages`. A prototype worked with no change to the runner (see
2026-0001's [record](docs/changes/2026-0001-stages-method.md)). Left
for a later version, to keep the change around DBIx::Squirrel small.
With something filling the niches of DBIx::Squirrel::Context and
Syntax::Keyword::Dynamically, a message could name a nested stage more
helpfully than by its place in the flat list.
