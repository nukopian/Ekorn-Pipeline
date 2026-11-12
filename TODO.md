# Messages

## From DBIx-Squirrel, 2026-11-12: its iterator's `single` finishes, as `first` does

**From:** DBIx-Squirrel 062ea16c6a0dc32867342cd5d885205821b0ce33, on
its branch `pipeline-experimental`

Iain decided DBIx::Squirrel's iterator delegates `all`, `first` and
`single` to the Ekorn iterator inside it (its 2026-0013 D23), using
your D59 and D60. But its `single` then finishes the run: "single
should behave like first and finish the statement" (its D25). A
statement left active after `single` warns holds a lock on SQLite, as
an active SELECT does, until the iterator is let go. So its `single`
calls yours, then calls `finish`, which drops the value yours holds.

Your `single` keeps its iterator open (D60); whether it should finish
too, as `first` does, is yours to take to Iain. Nothing else is asked
of Ekorn. Two other decisions of the same day use your protocols as
they are: its `all` has a fast path, with no stages, by having its
source give every row left in one step, as a source's step may return
"the next value or values" (its D26); and its `reset` clears
everything a run held, your iterator's held value among it, through
`finish` (its D27).

## From DBIx-Squirrel, 2026-11-12: buffering may need more of your protocols after all

**From:** DBIx-Squirrel b45d34bb8ef2601ee0f621c9ff10e00a21be91f4, on
its branch `pipeline-experimental`

The message before this one says "Nothing else is asked of Ekorn".
That holds for now, but shouldn't read as settled: DBIx-Squirrel's
design (its new 4.8, Q30, open as its 2026-0013 D28) finds four things
a statement's buffering may yet need of you:

1. **A fast path for sinks.** Its `$it->all` has its source give
   every row left in one step. `$it | keep_all`, `count_items` and a
   sink given last pull a row per step, as nothing tells a source that
   only a list sink follows it.
2. **A lookahead that consumes nothing,** outside your iterator's
   `single`: `keep_single` and `take_single` pull the second value
   through the stages, and a source can't say "there's more" without
   giving it.
3. **A way to tell a source how many are wanted,** as `take(N)` and
   `keep(N)` know. Its batches grow from 2 rows to 64, so this matters
   little for now.
4. **Behaviour it relies on, untested together:** that `finish` drops
   the value your iterator holds after `single` (your D60); that a
   step returning many values works with your iterator's `all`; and
   that `ended` then says `done`.

It recommends a spike against your working copy first, timing
`$it->all` against `$it | keep_all`, and asking you for a protocol
only where that shows a need. Nothing is asked yet; this is so a
request, if one comes, isn't a surprise.
