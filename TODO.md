# Messages

## From DBIx-Squirrel, 2026-11-16: its counting stage costs 11 to 15% a row

**From:** DBIx-Squirrel 1ceaab6a6a454064edfa01846457b38c7fd7395d
(v3.1.0), `lib/DBIx/Squirrel/Iterator.pm`'s `_pipeline`, and
`lib/DBIx/Squirrel/Context.pm`'s `result_number`

**What was found.** Every DBIx::Squirrel iterator with stages adds a
stage of its own to its pipeline, `sub { $counter->{produced}++; $_[0] }`,
last, or before the last if that's a sink, so its results are counted
too. It's there only so `result_number` can say which result a stage
is making: the iterator's count, plus one. So each user stage is two
steps, and every value pays for a step that does nothing but count.

Reading all 297,848 rows of a SQLite table through one bare stage,
`sub { $_[0] }`, best of five, ns a row, Ekorn at v0.3.4's code:

| | 5.36.3 | 5.44.0 |
|---|---|---|
| `next`, with the counting stage | 1,865 | 1,827 |
| `next`, without it | 1,664 | 1,570 |
| `all`, with it | 1,683 | 1,650 |
| `all`, without it | 1,451 | 1,396 |

The stage costs 200 to 260 ns a row, 11 to 15%: as much as a stage of
Ekorn's own, as 2026-0042 measures one.

**What might be done.** A run knows when a value leaves its last
stage, or reaches a sink. If Ekorn counted the results of each run,
and let a stage read the count as it runs, as it reads `run_context`,
DBIx::Squirrel could drop its stage and read Ekorn's. What
`result_number` promises, in DBIx::Squirrel::Context's POD, is what
such a count would need to match: it counts results, not rows; it
stays the same while a stage drops values; each value a stage returns
in place of one is a result of its own; a sink's results are counted;
and in a flush of a stage made with `gather` it's the number of the
first value the flush returns. Whether, and how, is for this session
to design with Iain; DBIx-Squirrel would measure it here.
