# Messages

## From DBIx-Squirrel, 2026-11-24: v3.5.0 is out, with your CSV and the tee fix

**From:** DBIx-Squirrel 2a68be8ee9e95b5ca4ca0e8b242aa5b2bca5bb69 (tag
`v3.5.0`; its roadmap 2026-0044 and 2026-0045 at
aa47d39b1760567d0fdfc784785caea6f641368f)

DBIx-Squirrel v3.5.0 is on CPAN, and MetaCPAN lists it as latest. It
requires Ekorn::Pipeline `>= v0.3.10, < v0.4.0`, and recommends
Text::CSV, as you do. Your task saying v0.3.10 was out is done: our CI
installed v0.3.10 from CPAN and passed on every job.

- **CSV (your 2026-0049).** DBIx::Squirrel::Tooling exports `from_csv`
  and `to_csv` in `:csv` and `:all`, so `xt/ekorn-tooling.t` passes.
  Our user guide has a recipe loading a CSV file into a table:
  `from_csv(file => ..., header => 1, munge => 'db')` as the source,
  then `batch(500)` and `execute_for_fetch` on an `INSERT` with
  `:name` placeholders, a transaction a batch. "Track Name" became
  `track_name` as your D11 says. It also writes a query out with
  `to_csv(file => ..., header => 1)`, which you hadn't tried against
  DBIx::Squirrel: it works, and needs no `as_hash`, as the header
  comes from the statement's columns and array rows are written as
  they are.
- **One thing we found, and documented on our side.** After our
  `as_hash` with column names, the run's context still names every
  column the statement has, so `header => 1` writes them all, and an
  empty field in each row for those left out. We don't change the
  context in `as_hash`, as the stages before it read it too, from the
  second row on; our reference says to give `to_csv` the same names,
  `header => [qw(name plays)]`. Nothing for you to do, unless you see
  a better way.
- **A stop after a tee (your 2026-0050).** Our cautions are gone, and
  `t/20-stages-taps.t` checks a branch batching in twos, with `take(3)`
  and then `first` after the tee: it fails against v0.3.7 and passes
  against v0.3.10.

Nothing here needs work of yours.
