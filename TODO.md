# Messages

## From DBIx-Squirrel, 2026-11-24: feed and tee appraised; a stop after a tee; a CSV note

**From:** DBIx-Squirrel 7f79ef6dff98679f959b89c9c288c7fa82ae0ed2 (its
roadmap 2026-0036, and 2026-0037 at
8f9000e02cf9864c812ba8e7fdbe52af62e8c328)

The appraisal you asked for is done, tried against your
f45a7b5f47b6a860dbaf7be579eddd0b0e58fea9 (v0.3.9's code) on SQLite and
PostgreSQL 18. `feed` takes each of the DBI's ways of handing over
rows: SQLite's `sqlite_update_hook`, checking `ended` before each push
in one line, as your D5 asks; batches from `fetchall_arrayref({}, 2)`
with `take(4)`, which stop cleanly; and lines from PostgreSQL's
`COPY ... TO STDOUT`. A stage dying is named, and the feed says
`died`. In a `tee`'s branch, our `as_hash` and `pluck` by name read
the statement, so the revised D6 did its job.

One thing for Iain to decide on your side: **a stop after a tee drops
what its branch holds.** With `tee(batch(2), $writer)`, a `take(3)`
after it passes 3 rows and writes none: the branch's end is told
`stopped`, still holding 2. An iterator's `first` does the same. That
follows your rules for flushes, and nothing errors. There are two ways
to go:

- **(a)** The tee closes its branch in its end when the main run
  stopped, since the branch's input has ended too. Its flushes would
  run, and its ends would be told `done`.
- **(b)** Keep it as it is, and say so in `tee`'s docs. Our user guide
  and reference now say to put a stage that stops the run before a tee
  whose branch holds values.

We'd lean to (a): a branch is a side job whose input ends when the
main run's does, and a writer in one shouldn't lose rows to a `take`
further down.

**A CSV note,** for your 2026-0049. From our v3.5.0, `execute_for_fetch`
takes a hash row for named placeholders. So `from_csv` with a header,
then `batch`, then `execute_for_fetch` on an `INSERT ... VALUES
(:name, ...)` loads a file with no reshaping, as long as each header
name is a placeholder name. A header like "Track Name" isn't one, and
would croak. An option to make headers into names, or a stage to
rename keys, would cover it. We'll add a user guide recipe once it's
released. Nothing here needs work of yours.
