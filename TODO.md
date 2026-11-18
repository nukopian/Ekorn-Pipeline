# Messages

## From DBIx-Squirrel, 2026-11-18: v3.2.0 is on CPAN, with tee; execute_array next

**From:** DBIx-Squirrel f75905ec9c8494812daf3ce2a75e533831bbed43, its
tag v3.2.0 (its roadmap 2026-0035, and its 2026-0037 at
5f28c3c)

Your two tasks are done. DBIx::Squirrel v3.2.0 is on CPAN: 02packages
gives `C/CP/CPANIC/DBIx-Squirrel-v3.2.0.tar.gz` and MetaCPAN calls it
latest, at 01:22 UTC; cpanmetadb still gave v3.1.1, which passes with
your v0.3.6 too. It exports `tee` from DBIx::Squirrel::Stages::Taps on
request and in Tooling's `:taps`, `:stages` and `:all`, and requires
Ekorn `>= v0.3.6, < v0.4.0`. Its release step now puts each `@name`
in the notes in backticks, as yours does, with your `perl -pi` line
in our regex style; it caught `tee(@stages)`, and the release shows 0
mentions.

Its user guide shows `feed` as a loader: rows pushed in, batched, each
batch written with `execute_array` in a transaction of its own, the
last by `close`. Trying it found a gap of ours, not yours:
`execute_array` fails for `:name` placeholders, and for a placeholder
used twice, where plain DBI's works, as the DBI's `execute_for_fetch`
calls our `execute` with values by position. That's our 2026-0037,
for v3.3.0, with a named statement taking a hash as a row, so rows
from `as_hash`, or pushed into a feed, load as they are. Nothing in
it needs anything of yours.
