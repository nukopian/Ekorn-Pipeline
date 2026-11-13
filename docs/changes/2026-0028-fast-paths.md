# 2026-0028. Fast paths

**Status:** in progress

**Decisions:** None.

**Origin:** roadmap, added 2026-11-13, from Iain: "Do we have fast
paths everywhere that they make sense? Say, for example, when the
pipeline is empty?"

**Started:** 2026-11-13

## Background

Measured on 2026-11-13, on Perl 5.36, with Benchmark, over 1,000
values unless said:

| Run | Rate |
|---|---|
| `map { $_ }` | 39,500/s |
| push through an empty pipeline | 37,000/s |
| pull through an empty pipeline, with `all` | 1,800/s |
| push through one stage | 790/s |
| push through two stages | 620/s |
| pull through one stage, a source giving every value at once, with `all` | 990/s |
| a push of three values through one stage, as a call | about 25 µs each |
| an iterator set up and read, with an empty source | about 20 µs each |

So there's one fast path, a push through an empty pipeline, and
`all`'s taking values already at the end in one go. The rest pay for
what they may not use:

1. **Each run's set-up, about 20 µs,** builds the machinery for
   flushes, ends and sinks, a dozen closures, a run table and an
   Iterator, even when every stage is a plain step. It dominates small
   and frequent runs: a pipeline called from a stage, once per value,
   or a function called once per row.
2. **A pull through an empty pipeline** goes through the whole loop
   for each value.
3. **A push feeds its values one at a time,** each a call of its
   source and a `try`; a source giving them all at once was about 25%
   faster through one stage, read with `all`.
4. **On each value:** `$wait` is called after each stage even with
   nothing to put on the queue, and, once the source is done, each value
   handed out looks for the next flush with a `grep` over the stages.

## Decisions

None: what the fast paths are is a matter of measurement, and what
they must keep is the behaviour the tests already pin.

## The plan

- Each fast path keeps every behaviour exactly: what a stop does, with
  the values it carries and those it drops; the errors, with their
  positions and names; `ending()` false and no `run_context` for a
  pushed run; the caller's values copied, and `$_` local; the count, or
  a sink's result, in scalar context; and an iterator's methods and
  `ended`. The whole suite passes unchanged, but for tests added.
- **A run of plain steps.** Where every stage is a step with no flush,
  end or sink, so a code reference or a Stage, and so known when the
  pipeline is made, a push runs the values through a plain loop, with
  no iterator. Gathers, sinks and parts of other packages, which are
  made for each run, take the full path.
- **A push hands its values over at once,** and reads the run with
  `all`, where the full path is taken.
- **An empty pipeline pulled** gives the source's values on as they
  come, keeping a source's stop and end.
- **On each value:** no call of `$wait` for nothing, and the next flush
  found without a scan where it can be.
- Measured before and after, with the same benchmarks, and the figures
  kept here. Tests for each fast path's edges, so coverage stays at
  its floors.

Done when each fast path is in, the suite passes unchanged, coverage
stays at its floors, and the benchmarks show the gains, kept here.

## What happened

Nothing yet.
