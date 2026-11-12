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
