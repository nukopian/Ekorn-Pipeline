# 2026-0032. Faster pulled runs

**Status:** shipped, unreleased

**Decisions:** D1 settled: before v0.3.0. D2 settled: no change anyone can see but speed. None open.

**Origin:** two messages from DBIx-Squirrel's session, 2026-11-13
(DBIx-Squirrel bff327ccba3e57cc4dbff2a8a79076398d15ea24 and
70ae33f21c3c397c97d92f28b8082f06cad6d555, on its branch
`pipeline-experimental`)

**Started:** 2026-11-14

**Finished:** 2026-11-14

## Background

2026-0028's fast paths made pushed runs through plain subs much
faster, but DBIx-Squirrel pulls its rows, and measured 2 to 4% from
them, within the noise. It then trimmed its own side, and profiled
`iterate($stage)->all` with Devel::NYTProf: Ekorn's step loop, the
sub its iterator calls once a value, was about three quarters of the
time. Nothing was asked; Iain chose to look before releasing v0.3.0.

Measured here, on 300,000 narrow rows from a code source, a pulled run
with one plain stage cost about 1.2 µs a value, against 0.5 µs pushed.
NYTProf put the most of it on leaving `$next` each value, and the rest
spread over the loop: a `try` around the source's step and another
around the stages, the values copied from the step through a
temporary array, and the stages' bookkeeping. Calling the iterator
through Perl's overloading of `&{}` added 0.18 µs a value, which the
POD's "Pulling many values" already shows how to avoid.

## Decisions

- [x] **D1.** Now, or after v0.3.0? **Before,** Iain decided on
  2026-11-14, as a loose end to clear up before the release.
- [x] **D2.** What may change? **Nothing anyone can see but speed:**
  every test passes unchanged, and the messages, the order things run
  in, and what each part is told, stay as they are. So it's a change
  any v0.3.x could carry.

## The plan

Measure the pulled cases, best of five and interleaved with the code
as it was, as the machine was busy; profile; try the cheapest changes
first, keeping each only if the tests pass and it's faster; stop
before restructuring the loop's error handling.

## What happened

- **Outcome,** best of five, interleaved, in seconds for 300,000
  values:

  | Case | Before | After | Gain |
  |---|---|---|---|
  | `all`, one stage | 0.343 | 0.306 | 11% |
  | `all`, three stages | 0.478 | 0.442 | 8% |
  | a list sink last | 0.286 | 0.275 | 4% |
  | `next`, one stage | 0.344 | 0.338 | 2% |
  | `next`, no stages | 0.169 | 0.165 | 2% |
  | pushed, one stage (unchanged) | 0.150 | 0.149 | none |

- **What changed:**
  - A source's step returns straight onto the queue of values from
    the source, not through a temporary array, and an unused variable
    declared for every value went.
  - `all` runs the loop once, collecting every value as it goes, where
    it called `$next` once a value: no sub call and return between
    values. The loop collects into an array that `all` sets, shared
    with it, not passed: an optional argument on `$next` cost 0.05 µs
    a call, as much as the first change saved `next`. It's cleared
    however the call ends.
- **Tried and kept back:** `all`'s two shortcuts, taking a step's
  values at once where there are no stages, and the values already at
  the end, were lost at first, as `xt/scaling.t` showed: a step's
  values each went through the loop, four times slower, 0.49 of the
  time of a step each against 0.13. They're back, inside the loop.
- **Found:** Perl 5.36's `try` doesn't allow `finally` without a
  `catch`, so `all` clears its array in a `catch` that throws the
  error again, and after.
- **What's left:** each value pulled enters two `try` blocks, one
  around the source's step and one around the stages, at about
  0.07 µs each; one block for both would save about 6% more on `next`,
  but means restructuring how the loop tells a source's error from a
  stage's, so it waits for an item of its own, not a release.
