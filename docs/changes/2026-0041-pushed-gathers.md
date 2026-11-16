# 2026-0041. A pushed gather takes the plain loop

**Status:** shipped, unreleased

**Decisions:** D1 settled: pushed runs only. D2 settled: the two tests
of the path a push takes change. D3 settled: a v0.3.x.

**Origin:** roadmap, added 2026-11-16 as an idea, from a message from
DBIx-Squirrel's session of that day (DBIx-Squirrel
dc9a56d47082128888d521ffcc9cb5e3ae92b893)

**Started:** 2026-11-16, on `develop` at
ef05a1565f2ceb4b99498ee36b3bec9541fcf5e7

**Finished:** 2026-11-16

## Background

DBIx-Squirrel measured a bare stage, pushed through a pipeline, at
about 475 ns a value on 5.36, and the same stage made with `gather`
at about 815: so a gather seemed to cost about 340 ns a value, most of
what its `pluck` costs.

Tried on 2026-11-16, in a copy of `lib`: the cost isn't in `gather`
at all. A push runs its steps in a plain loop only when every stage is
a plain step, decided when the pipeline is made; any stage made for a
run, as a gather is, sent the push to an iterator of the run, with the
pulled machinery, even when what the gather made was a step with no
flush or end. Pulled runs already took their shorter way once their
stages were made, so a gather costs them nothing: at v0.3.4, through
`all` or `next`, the bare stage and the same in a gather measured the
same, within the noise.

So a push makes its stages for the run first, and takes the plain loop
if none has a flush or an end. In the copy, a gather's step, `take`,
`drop`, `count_into` and `drop_while` pushed cost what a plain stage
costs, 40 to 45% less a value; every test of behaviour passed, and the
two that pin which path a push takes failed, as expected.

## Decisions

- [x] **D1.** Which runs? **Pushed runs only,** Iain decided on
  2026-11-16, agreeing to the plan: pulled runs take their shorter way
  already, and a run with a flush, an end or a sink keeps the full
  path, whose cost is another change.
- [x] **D2.** The tests that pin the path? **They change,** Iain
  decided on 2026-11-16: `t/22-fast-paths.t` forces the full path with
  a gather with a flush, not one with a step only, and checks that a
  stage made for a run takes the plain loop, and one with a flush, an
  end or a sink doesn't; `t/27-plain-runs.t`'s gather of a step only
  is pulled, as the shorter way it checks is the pulled one.
- [x] **D3.** Which version? **A v0.3.x,** Iain decided on
  2026-11-16: what a stage sees, the messages and the order things run
  in are as they were.

## The plan

**What:** a push makes the stages for its run, as an iterator does,
and takes the plain loop, `_push_steps`, when none has a flush or an
end; otherwise an iterator of the run it made, without making it
again. A set-up that dies is reported as before.

**Why:** a stage made with `gather` costs a pushed value about 340 ns
for no work of its own, and `take`, `drop` and the other canned stages
made with it are among the most used.

**Steps:** split the full iterator from `_iterator`'s set-up, so a
push can use a run it has made; share the set-up's error handling;
change the two tests, and add ones for the new path and a set-up that
dies; measure against v0.3.4 on 5.36 and 5.44, per value, for a short
push, and for an iterator's set-up, which 2026-0040 halved.

**Done when:** a pushed gather with no flush or end costs what a plain
stage costs, a value; nothing else is slower to measure; the tests
pass on every Perl CI covers, under yath and `prove`; coverage keeps
its floors.

## What happened

- **Outcome:** as Done when says. A pushed gather's step costs what a
  plain stage's does, and a short push through one costs less than
  half what it did, as it no longer makes an iterator.
- **Changes from the plan:** the first version moved the whole set-up
  into a sub of its own, `_set_up`, shared by `_iterator` and the
  push. It cost an iterator's set-up about 0.5 µs on 5.36, 4%, and a
  short push through a stage with a flush 0.5 to 1 µs, 2 to 4%, for
  the calls it added. So each keeps its set-up inline, and only the
  error handling, which runs only when a set-up dies, is shared, as
  `_set_up_died`; the full iterator is `_full_iterator`, which
  `_iterator` and the push both call.
- **Measurements,** best of five, ns a value, 200,000 values pushed,
  v0.3.4 against this change, two rounds:

  | | 5.36 before | after | 5.44 before | after |
  |---|---|---|---|---|
  | a bare stage | 368 to 372 | 369 to 373 | 413 to 416 | 412 to 415 |
  | the same made with `gather` | 683 to 689 | 370 to 371 | 735 to 741 | 412 to 419 |
  | `take(N)` | 717 to 724 | 400 to 406 | 771 to 778 | 441 to 445 |
  | `drop(0)` | 703 to 708 | 388 to 391 | 758 to 765 | 425 to 436 |
  | `count_into` | 704 to 705 | 383 to 392 | 759 to 767 | 427 to 434 |
  | `drop_while` | 726 to 732 | 409 to 415 | 776 to 781 | 448 to 454 |
  | `take_if`, then `take(N)` | 989 to 992 | 654 to 663 | 1079 to 1089 | 726 to 731 |

  Pulled runs, and pushes through `batch`, `collect`, `take_last` or
  a sink, measured the same before and after, within the noise. A push
  of one value, ns a push, 100,000 pushes: through `take(5)`, 13,850
  to 14,100 before and 4,970 after on 5.36, and 12,750 to 12,850
  before and 4,750 to 4,830 after on 5.44; through `take_last`, the
  same within the noise. An iterator's set-up: let go unread, the
  same; reading a one-value source with `all` through `take_last`,
  about 0.25 µs more on 5.36, 1%, for the call to `_full_iterator`.
- **What's left:** a run with a flush, an end or a sink still takes
  the full path when pushed, at about twice the cost a value; the
  how-to says so.
