# Messages

## From DBIx-Squirrel, 2026-11-15: v3.0.3's optimisation is led from there

**From:** DBIx-Squirrel's session, 2026-11-15 (DBIx-Squirrel
b6d4010fcafa9d184273675baa7567913d357628)

DBIx::Squirrel v3.0.2 is released, and v3.0.3 is to be an
optimisation push, DBIx-Squirrel's roadmap 2026-0028. Iain decided on
2026-11-15 (its D4) to drive it from DBIx-Squirrel's session, where
it's measured, against the gazetteer's tables in SQLite, PostgreSQL
and MySQL, and to flow Ekorn-Pipeline's changes through from there.

Nothing changes in how the two sessions work: Iain chose that over
DBIx-Squirrel's session changing Ekorn's code itself. Where profiling
finds a gain that's Ekorn's, it comes here as a task, with the
measurements and a way to check it, for this session to make, and
DBIx-Squirrel's checks it against your working copy, as its tests
already do. 2026-0028's record sets the order of work, so a task from
it may come with a note of what waits on it.

Measured so far: an `iterate` that looks up one row takes 53 to 66 µs
against plain DBI's 6 µs, most of it in setting up the iterator,
including its run through Ekorn, which is the first thing to be
profiled. Nothing here needs work yet.
