# 2026-0002. An iterator after a stage dies

**Status:** open

**Origin:** roadmap, added 2026-11-07, from the sweep before v0.1.0's
trial

## Background

When a stage dies while an iterator is read, the call that asked for
the result dies with "Pipeline stage #N failed". The docs don't say
what happens if the caller catches that and reads on, so nothing is
promised. DBIx::Squirrel's users will read iterators, and may catch
errors in a loop, so it has to be settled before v0.1.

Today the iterator carries on as if the value that died had been
dropped, keeping everything else: the values waiting, the source, and
what `gather` stages hold. With a stage dying on 2, then `collect`, over
1 to 5:

| Call        | Result                              |
|-------------|-------------------------------------|
| 1           | dies: `Pipeline stage #1 failed`    |
| 2           | `all: 10 30 40 50`, without 20      |
| 3 and after | an empty list                       |

With a flatMap, the value that died is lost, and its siblings still
come out: a stage making 1b from 1, with 1b dying, hands out 1, dies,
then hands out 2, 2b, 3, 3b.

A pushed run, `$p->(@values)`, is different: it dies and returns
nothing, as the whole call is one run.

## Decisions

- [ ] **D1.** After a stage dies, what does the iterator do?
  - **A.** Promise today's behaviour: it carries on, the dead value
    dropped. No code change, and a loop can catch and go on; but an end
    such as `collect` then gives a result missing values, with no sign
    of it, and a stage's state may be half-updated.
  - **B.** End the iterator: it returns an empty list on every later
    call, no end function runs, and the source isn't called again.
    Matches a pushed run, where a death ends the run, and gives no
    partial results; a small code change, a test and docs. Skipping bad
    values needs a `try` inside the stage, which the how-to's "Catch
    errors in a stage, but not a stop" already shows.
  - **C.** Leave it unpromised: it does what it does today, and the
    docs say not to read it again. No work now, but callers will rely
    on whatever it does, so changing it later still breaks someone.
  - **D.** Die again, with the same error, on every later call. Hard to
    miss, but a loop that catches and retries never ends.

  Recommended: B. A run either finishes or fails, the same pushed or
  pulled, and an end function never reports on a run that lost values.
  B or D changes how a run behaves, so either goes out as a new trial,
  v0.1.1, as v0.1.0's trial does A. With B, DBIx-Squirrel gets a task
  to check its tests and docs for a loop over rows that catches a
  stage's error and carries on, which would stop getting rows. The
  docs to change are the POD of `iterator`, the reference's iterator
  section and its "When a stage dies", and a line in Changes.
