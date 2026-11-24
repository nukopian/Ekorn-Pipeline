# 2026-0052. A source's original, carried through chains

**Status:** open

**Decisions:** D1 settled: a source part, `original`, not a context
key. D2 settled: called only when `result_original` is asked, with no
arguments, for the value the source gave last. D3 settled: undef in a
flush and the stages after it, whatever the part says. D4 settled: an
iterator read as a source passes on its source's part. D5 settled:
feeds and tees as now. D6 settled: read where every source's parts
are, so the `source` factory takes it too. D7 settled: a v0.3.x,
ahead of 2026-0051.

**Origin:** a message from DBIx-Squirrel's session, 2026-11-24
(DBIx-Squirrel 3c02a4377ce8ea279de9f6fae6d6c3db71dd7aa2), and its
answers to Ekorn's design, passed on by Iain the same day
(DBIx-Squirrel d59ec732506e2f031a613cd7392fc957802ceee7)

## Background

Ekorn's `result_original` (2026-0046) gives the value the run's own
source gave, or that was pushed: for a run reading an iterator, the
value the iterator handed out (its D3). DBIx::Squirrel's gives the
statement's row, through chains: its statement source keeps the row
it gave last in the run's context, `{statement, columns, row}`, and an
iterator read as a source passes its context on. So the two are
different subs by one name, and 2026-0051, which puts Ekorn's in
Tooling's `:context`, would clash with DBIx::Squirrel::Tooling's:
its `t/28-tooling.t` fails ("each name both export is one sub"), and a
program importing both `:context`s gets whichever came last, without a
word, as both have an empty prototype since v0.3.12.

DBIx-Squirrel proposed a context key, `original`, which Ekorn's
`result_original` would ask first. Ekorn proposed a part of the source
of its own instead, and DBIx-Squirrel agreed it's better (D1). With
it, DBIx::Squirrel's statement source gives `sub { $context->{row} }`
as the part, and its `result_original` becomes Ekorn's own sub, as its
`result_number` did in its v3.6.0; then 2026-0051 can put both names
in Tooling, and the two Toolings agree on every one.

The chain, as DBIx-Squirrel set it out:

| Order | Item | Depends on | What |
|---|---|---|---|
| 1 | Ekorn 2026-0052 | | the `original` part, in a v0.3.x |
| 2 | DBIx-Squirrel 2026-0046 | Ekorn 2026-0052, released | its source gives the part; its `result_original` is Ekorn's own sub; its floor rises |
| 3 | Ekorn 2026-0051 | Ekorn 2026-0052 | both names in Tooling, at v0.4.0 |
| 4 | DBIx-Squirrel 2026-0047 | Ekorn 2026-0051, released | its range takes v0.4.0; the Toolings agree |

## Decisions

All settled on 2026-11-24, as Ekorn proposed them and DBIx-Squirrel
agreed, in the answers Iain passed on.

- [x] **D1.** How does a source supply the original its values were
  made from? A part of the source, `original`, beside `step`, `end`
  and `context`: a code reference returning the original of the value
  the source gave last. Not a key in the run's context, as
  DBIx-Squirrel first proposed: the context belongs to whoever wrote
  the source, may be any value, not a hash, and a key such as
  `original` would claim a name in everyone's, and could collide with
  one already used. A part of its own fits how a source is read now,
  and a source can't take it up by accident.
- [x] **D2.** When is it called, and what does it answer for? Only
  when `result_original` is asked, with no arguments, so a run that
  never asks pays nothing a value, only a lookup as it's set up: a
  context key would have had to be kept current. It answers for the
  value the source gave last. That's the value a stage is working
  from in a pulled run, as values a stage returns several of wait on
  the run's queue, and go through the stages before the next pull,
  and a stage holding values back, such as `batch`, gives the original
  of the value that filled it, as `result_original` does without the
  part. The one limit, which the docs say: a source whose step returns
  several values at once has its part answer for the last of them,
  while the stages may be on the first. DBIx::Squirrel's statement
  source does so only for an iterator with no stages that no pipeline
  reads, where nothing can ask.
- [x] **D3.** And in a flush? Undef in a flush and the stages after it,
  whatever the part says, as `result_original` is now (2026-0046's
  D3).
- [x] **D4.** Through chains? An iterator read as a source passes on
  its own source's part, when it has one, as it passes on its context.
  So a statement's row reaches a pipeline reading its iterator, with
  no code of DBIx::Squirrel's, and any source of anyone's gains the
  same. Without a part, nothing changes: a run reading an iterator
  gets the value the iterator handed out, as 2026-0046's D3 has it.
- [x] **D5.** Feeds and tees? Unchanged. A feed has no source, so its
  stages get the value pushed; a tee's branch is a feed, and answers
  for itself, as each run does.
- [x] **D6.** Which sources can give it? Every source: the core reads a
  source's parts in one place, `_source_run` in
  `lib/Ekorn/Pipeline.pm`, from its `EKORN_SOURCE`, which the `source
  { ... }` factory's set-up returns through. So the part is taken
  there, by name in a hash or fourth in a list, and the factory, a
  class's own `EKORN_SOURCE`, and an iterator all take it alike.
  DBIx-Squirrel asked that the factory take it by name.
- [x] **D7.** Which version? A v0.3.x, ahead of 2026-0051: it only
  adds, and a source without the part runs as now. DBIx::Squirrel's
  `result_original` can then become Ekorn's own early, and 2026-0051
  puts both names in Tooling with no clash.
