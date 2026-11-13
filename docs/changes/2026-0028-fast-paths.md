# 2026-0028. Fast paths

**Status:** shipped, unreleased

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

Done on 2026-11-13, but for the empty pipeline pulled. The suite
passed unchanged at each step, on 5.36, 5.38 and 5.44, the user
guide's 95 examples printed the same before and after, and coverage
stayed at its floors.

Measured with the same benchmark, in Perl's Benchmark, on 5.36, over
1,000 values unless said, before and after:

| Run | Before | After | |
|---|---|---|---|
| a call of three values through one stage, 1,000 times | 41/s | 487/s | 11.9 times |
| push through one stage | 774/s | 2,726/s | 3.5 times |
| push through two stages | 805/s | 2,169/s | 2.7 times |
| push through a gather | 773/s | 1,153/s | 1.5 times |
| push through a stage and `take(500)` | 1,157/s | 1,654/s | 1.4 times |
| pull through one stage, with `all` | 800/s | 926/s | 1.2 times |
| pull through one stage, one at a time | 781/s | 895/s | 1.1 times |
| pull through an empty pipeline, with `all` | 1,778/s | 1,708/s | the same |
| push through an empty pipeline | 42,997/s | 40,325/s | the same, as its path didn't change |

The user guide's comparison, a filter and a multiplication over 10,000
values, pushed, went from about thirty times slower than `map` and
`grep` to about twelve; pulled, it's still about thirty. The guide's
"How fast is it?" says so.

- **A run of plain steps.** `new` keeps the steps of a pipeline whose
  stages are all Stages of Ekorn's own class, not a subclass, which
  could give more than a step, and a push through them runs
  `_push_steps`, a plain loop. Stages made for a run, gathers, sinks
  and other packages' parts, and so `take` and the other canned stages
  made with `gather`, take the full path. A stage that dies is named
  by `_label`, which the full path now shares.
- **One `try` for a stretch of values.** The plain loop first had a
  `try` for each value, which a measurement put at about 0.07 µs a
  time; hoisted, it's entered again only after a stop, which took a
  push through one stage from 2.6 to 3.5 times.
- **The full path:** a push hands over its values in one call, and is
  read with `all`; `$wait` isn't called with nothing to put on the
  queue; the next flush is found from a list of the stages that have
  one; and `run_context` isn't made local for each value where it's
  undefined, inside and out, about 5 to 7% on its own. A first
  measurement of that last showed no gain, because the edit hadn't
  been made, a command having stopped before it; made, it showed one.
- **`t/22-fast-paths.t`** runs each case both ways, the plain loop with
  the full path made to die, and the full path forced by a gather that
  passes values on, and expects the same: values, stops, a stop that
  isn't an array, errors with their places and names, exception
  objects, no context or `ending` in a pushed run, the count, and a
  pipeline calling itself.

**Not done: an empty pipeline pulled.** A profile of a pull showed its
cost is in each call of the iterator: leaving the call, with its
`local`s and lexicals, and a `try` around each pull. A fast path would
be a second iterator, keeping the stops, the source's end and context,
`finish`, `ended` and the rest, for a pipeline with no stages, which is
rare in use. Left until a use asks for it.

**What's left:** the full path's set-up, about 20 µs a run, which a
run with a gather or a sink still pays, and its cost on each value,
about twice the plain loop's. A pull is a call for each value, so it
can't take the plain loop.
