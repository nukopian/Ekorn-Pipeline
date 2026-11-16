# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0046.

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

### 2026-0046. Ekorn::Pipeline::Context: result_number and result_original

**Size:** M (3).

What a stage can ask about the result it's making, its number and
the value its source gave, so DBIx::Squirrel can drop the stage that
costs it 11 to 15% a row only to count. Its decisions are settled:
[record](docs/changes/2026-0046-context.md).

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

### 2026-0041. What a gather costs a value

Added 2026-11-16. **Size:** M (3).

Wrapping a stage in a `gather` costs about 340 ns a value more than
the bare stage, more than the stage itself, as DBIx-Squirrel measured
(its dc9a56d47082128888d521ffcc9cb5e3ae92b893, in a message of
2026-11-16): most of what `pluck` costs it, and of what `take`,
`batch` and the other canned stages made with `gather` cost. Find
where it goes, and make it cheaper, with nothing a stage sees changed.

### 2026-0042. A shorter step for one value

Added 2026-11-16. **Size:** S (2).

Each step costs about 235 ns a value: a `local $_`, a call in list
context, a `my @values` and a `shift`, even where a stage returns
exactly one value, as most do. See whether the step loop can do less
in that case, with nothing a stage sees changed. Perl 5.44 runs the
loop about 18% slower than 5.36, so measure on both.

Tried on 2026-11-16, in copies of the push loop, not in the code:
taking the count from the list assignment, `my $count = (($value,
@more) = $step->($value))`, with `@more` made once a run, in place of
`my @values` and a `shift`, saves about 20 ns a step on 5.36 and 25
on 5.44, 5 to 10% of the loop, with the same results. A `local $_`
once a value, not once a step, saved 0 to 25 ns, only at four steps.
That's about the floor: of a step's 140 ns on 5.36, the loop is
about 25, `local $_` 21 (32 on 5.44), the call 35, and the list
assignment the rest. Iain set it aside the same day, as worth less
than 2026-0041; the full pulled loop reads `$value` after a step
drops it, which would need checking first.

### 2026-0043. Work in flight, in order, inside a run

Added 2026-11-16. **Size:** M (3).

A stage, such as `in_flight($n, sub { ... })`, whose block starts the
work for each value and returns a Future: up to `$n` at a time, their
results passed on in the order the values came, the rest given up by
its flush, and those still in flight cancelled by its end when the run
stops or dies. So a caller can fetch or look up each value
concurrently, beside the call, in any function that takes stages, with
nothing of Ekorn's changed. Waiting needs an event loop that a Future
can run while it waits, such as IO::Async's, or Mojo's through
Future::Mojo. It needs Future, so it belongs in a distribution of its
own, built on Ekorn's protocols, not in Ekorn's dependencies.

### 2026-0044. A run fed a value at a time

Added 2026-11-16. **Size:** M (3).

A run the caller opens, pushes values into one at a time, getting what
comes out of each, and closes, getting what the flushes give, its ends
told how it ended; it says when a stage has stopped it. Today a pushed
run takes all its values at once, and an iterator pulls them, so
nothing takes values as they arrive: from callbacks, sockets or an
event loop. It's synchronous, needs nothing new, and adds behaviour
rather than changing it, so it's a v0.3.x; and it's what async
sources and sinks (2026-0045) would be driven through.

### 2026-0045. Asynchronous runs

Added 2026-11-16. **Size:** L (5), and likely to be split once
designed. **Depends on:** 2026-0043, 2026-0044.

A run that returns a Future of its results, from sources whose step
may return a Future, read only as fast as the run takes values, so a
paginated API, a streamed response or an async cursor is fetched as
needed, and closed by its end however the run ends; with time-based
stages, such as a batch by size or by time. The questions to settle
first: a second run loop would have to keep the first's semantics
exactly (the order ends run in, what Stop and Gather do, how errors
are named); `run_context`, `ending` and `local $_` are dynamic scope,
which doesn't survive an `await`, so they'd need
Syntax::Keyword::Dynamically or another way to be carried; and where
an error is reported once the call has returned. Built on 2026-0043
and 2026-0044, in a distribution of its own, designed first, with a
prototype and cold reviews, as an epic change is.
