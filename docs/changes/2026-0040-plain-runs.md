# 2026-0040. A run's set-up, halved

**Status:** shipped, unreleased

**Decisions:** D1 settled: no change anyone can see but speed. None
open.

**Origin:** a TODO task from DBIx-Squirrel's session, 2026-11-15
(DBIx-Squirrel 725e62332f67d0943199d8c7829b7e838b68cf89, its roadmap
2026-0028), added here in ffe50dc44f27db8a377988a364ff825751aea835

**Started:** 2026-11-15

**Finished:** 2026-11-15

## Background

DBIx-Squirrel's 2026-0028 profiled its handles, and found a
DBIx::Squirrel iterator reading one row costs 43 to 50 µs more than an
`execute` and a fetch, about 27 µs of it Ekorn's run. With no stages,
on v0.3.2, `$p->iterator($code)` let go cost 13 to 15 µs, and
`$p->iterator(source {...})->all` 18 to 20 µs. NYTProf put about a
third of it on making `_iterator`'s closures, as many again on leaving
scopes, and about 11% on `_is_source`. Its record,
`docs/changes/2026-0028-handles-gains.md` in DBIx-Squirrel, has the
measurements in full.

Measured here first: a closure costs about 0.3 µs to make, plus a
little for each variable it captures, and `_iterator` made 13 of them
for every run, whatever the run had in it, most of them for flushes
and stages' ends that most runs don't have.

## Decisions

- [x] **D1.** What may change? **Nothing anyone can see but speed,**
  as 2026-0032's D2 settled for the same kind of change: every test
  passes unchanged, and the messages, the order things run in, and
  what each part is told stay as they are. So it's a change any
  v0.3.x can carry, and DBIx-Squirrel needs to do nothing but take
  it.

## The plan

Time `$p->iterator($code)` let go, and `$p->iterator(source {...})`
let go and read with `all`, with no stages, on 5.36 and 5.44, best of
five, interleaved with a copy of v0.3.2's `lib`. Try the task's
suggestions, keeping each only if it measures as a gain: a run with no
flush, no end of a stage's and no sink taking a shorter way, which is
DBIx::Squirrel's commonest case; fewer closures; `_end_all` skipped
where there's nothing to call. Check pulled runs of many values don't
get slower a value, as 2026-0032 measured them. Done when the set-up
is faster beyond the noise, Ekorn's tests pass on every Perl, and
DBIx-Squirrel's pass against this working copy.

## What happened

- **Outcome:** about half the cost gone, on both Perls. Best of five,
  per run, the lowest of two interleaved runs each:

  | Case | 5.36 before | 5.36 after | 5.44 before | 5.44 after |
  |---|---|---|---|---|
  | `iterator($code)`, let go | 15.1 µs | 7.9 µs | 15.0 µs | 7.2 µs |
  | `iterator(source {...})`, let go | 17.3 µs | 10.4 µs | 17.5 µs | 9.4 µs |
  | `iterator(source {...})->all` | 19.6 µs | 12.0 µs | 20.3 µs | 11.5 µs |
  | `iterator($code)->all` | 17.4 µs | 9.5 µs | 17.6 µs | 9.4 µs |

  Runs differed by about 1 µs. Ekorn's tests pass on 5.36 to 5.44,
  under yath and prove, with coverage at its floors, and
  DBIx-Squirrel's 318 pass against this working copy on 5.36 and
  5.44, its MySQL and PostgreSQL tests skipped, as they need a server.
- **What changed:**
  - `_plain_iterator`, for a run whose parts, once made, have no
    flush, no stage's end and no sink: no stages, plain code, or
    gathers whose blocks give only a step. It's `_iterator`'s loop
    with the flushes' and ends' bookkeeping taken out, and makes four
    closures, not thirteen. Whether a value still waits before the last
    step is read from the bottom of `@todo`, which holds the lowest
    index, as the stack only ever grows by higher ones, so it needs no
    count of the values waiting at each stage.
  - Everywhere: a stage is named in a message by `_run_label`, called
    only when there's something to name, not by a closure made for
    every run; one closure answers both the iterator's `ended` and its
    `spent`, which asked the same question; `_source_run` asks whether
    it has a source inline; and a run with no stages doesn't call
    `_make_run`.
  - `_iterator` now always has a stage, so a branch for none, in
    `all`'s loop, and the push of a value at the end under `all`,
    which `all` takes from the top of the loop, couldn't be reached,
    and went.
- **Many values a run,** 300,000 from a code source, best of five,
  interleaved: plain runs are 3 to 6% faster a value, and a run ending
  in a sink, which keeps the full path, is as it was.
- **Tests:** `t/27-plain-runs.t` runs each pulled case both ways, the
  shorter, checked to be taken, and the full path, forced by a gather
  after the stages with an end, and expects the same values, how the
  run ended, what the source's end was told, and any error; as
  `t/22-fast-paths.t` does for pushed runs. `t/16-run.t` gains a case
  for the full path that its plain runs no longer reach: a value
  waiting at the end, with the source still being read.
- **Not done:** `_end_all` skipping its `try` when the source's end is
  the only one. Its `try` is what reports an end that dies, so the
  shorter way calls it as it was, and skips it only when there's no
  end to call. What's left of the set-up is spread over the calls from
  `iterator` to `Iterator->new`, about 1 µs a line, with no one place
  left worth a change.
