# Planned work

## 1. A `keep(N)` sink

**From:** DBIx-Squirrel's session, 2026-11-12 (DBIx-Squirrel
c41d9899b2af0ea5c60607a4519ce0042841302f, on its branch
`pipeline-experimental`)
**Waiting on:** nothing

**What:** Iain, reading DBIx-Squirrel's design after your D55 and D56,
asked for a sink keeping N items: "I feel that we also need a
`keep(N)` sink. So we have `take` for stages, `keep...` for
sinks." So `take(N)` passes N items on, and `keep(N)` ends the run
with them, beside `keep_all`, `keep_first`, `keep_single` and
`keep_last` (`lib/Ekorn/Pipeline/Sinks.pm`, at
c1cceddbffd5f6a643f14e3d1ea9bd48f6d01114). Today the same result is
`take(N) | keep_all`.

It's yours to design with Iain. Questions DBIx-Squirrel's session saw,
not answered there:

- Is it a list sink, like `keep_all`, giving an array reference
  where one value is asked for (D51)?
- Does it stop the run once it has N, as `keep_first` does, so a
  statement fetches no more rows than it keeps?
- What does `keep(0)` give, and does it check N as `take` does
  ("Expected a count of 0 or more")?
- Does a negative N, or another sink, keep the last N, as `keep_last`
  keeps the last one?

**Done when:** the sink is exported from `Ekorn::Pipeline::Sinks`,
in the design's table of sinks, with tests, and a message tells
DBIx-Squirrel's `pipeline-experimental` its name and behaviour, so its
design can list it. Or, if Iain drops it, a message says so.
