# 2026-0050. A stop after a tee closes its branch

**Status:** shipped, unreleased

**Decisions:** D1 settled: the tee closes its branch in its end when
the main run stopped, its flushes run, its ends told `done`. D2 settled:
a fix in a v0.3.x, with a message to DBIx-Squirrel.

**Origin:** a message from DBIx-Squirrel's session, 2026-11-24
(DBIx-Squirrel 7f79ef6dff98679f959b89c9c288c7fa82ae0ed2), taken from
this repository's `TODO.md` (6f95a2d249eaa3a1f58b6018d3e8a9b965ee165f)

**Started:** 2026-11-24

**Finished:** 2026-11-24

## Background

DBIx-Squirrel appraised `feed` and `tee` against v0.3.9's code, on
SQLite and PostgreSQL 18, and found one thing for Iain to decide: a
stop after a tee drops what the tee's branch holds. Reproduced here
the same day:

```perl
Ekorn::Pipeline->new(tee(batch(2), $writer), take(3))->(1 .. 10);
```

passes 1, 2 and 3 on, and the branch writes `[1 2]` but not the 3 its
`batch` still holds, which it writes when nothing stops the run. An
iterator's `first` does the same. Nothing errors.

It's what 2026-0048's D5 settled on 2026-11-17: the branch's ends are
told how it ended from where it stands, `stopped` if the main run
stopped before the branch's input ran out, and a stopped run's flushes
don't run. That rule is right for the main run: a stop says no more of
its output is wanted, and a flush's values would go nowhere. A branch's
output doesn't go down the main run, though; it goes to the branch's
own stages, such as a writer, and the stop that ended the main run
ended the branch's input as much as its running out would have.

DBIx-Squirrel's user guide and reference now say to put a stage that
stops the run before a tee whose branch holds values. That advice
stays good after this change.

The core already says what happens if a branch's flush dies once it
runs in the tee's end: an end that dies tells every end after it
`died`, and its error is thrown once they've run (`_end_all` in
`lib/Ekorn/Pipeline.pm`). Nothing new is needed for that.

## Decisions

- [x] **D1.** When the main run stops, does the tee close its branch,
  so the branch's flushes run, or tell it `stopped`, as 2026-0048's D5
  has it? Close it, as DBIx-Squirrel suggested, its (a), and Iain
  decided on 2026-11-24: in its end, told `stopped`, the tee closes
  its branch if it's still open, so the branch's flushes run and its
  ends are told `done`. A main run that died still doesn't flush the
  branch: its ends are told `died`, as now. Keeping D5 and saying so
  in `tee`'s docs, DBIx-Squirrel's (b), was weighed: a writer in a
  branch shouldn't lose rows to a `take` further down.
- [x] **D2.** Which version? It reverses 2026-0048's D5 and changes
  what a stop does to a tee's branch, which
  [neighbours.md](../claude/neighbours.md) makes a v0.4.0, with a task
  for DBIx-Squirrel to test it and move its range, as DBIx-Squirrel
  exports `tee` to its users through its own Taps. Or it's a fix in a
  v0.3.x, with a message: the values dropped are lost quietly, and no
  stage is likely to depend on losing them. Recommendation: a v0.3.x
  fix, with a message to DBIx-Squirrel, as its guide's advice holds
  either way; but the rule's words say v0.4.0, so it's Iain's call.
  A fix in a v0.3.x, as recommended, Iain decided on 2026-11-24: what
  changes is values lost without a word, which no stage would rely on,
  so it's a fix to 2026-0048's D5, not a change users' stages depend
  on. DBIx-Squirrel's range needn't move; the message tells it what
  changed, so its guide and tests can say that a branch's flushes now
  run after a stop.

## The plan

**What:** in `tee`'s end, a branch still open is closed, unless the
main run died, when it's finished as now. A tee whose branch has a
flush but no end gets an end too, as it's the end that closes it.

**Why:** D1: a writer in a branch shouldn't lose rows to a `take`
further down.

**Steps:**

1. Change the end `tee` returns in `lib/Ekorn/Pipeline/Stages/Taps.pm`.
2. In `t/29-tee.t`, the branch's ends are told `done` after a stop or
   a finish, and new tests: DBIx-Squirrel's example, an iterator's
   `first`, a main run that dies, a tee in a branch the stop ends, and
   a branch's flush that dies in the tee's end.
3. `tee`'s POD, the reference and the how-to's hand-built tee say so;
   the manuals remade; `Changes`.
4. A message to DBIx-Squirrel, as D2 says, once it's pushed.

**Done when:** DBIx-Squirrel's example writes `[1 2]` and `[3]`, the
tests pass on 5.36 to 5.44, and coverage holds its floors.

## What happened

Done as planned, on 2026-11-24, in one commit with the plan.

- DBIx-Squirrel's example now passes 1, 2 and 3 on, and the branch
  writes `[1 2]` then `[3]`. An iterator's `first` writes `[1]`.
- A branch's flush that dies in the tee's end fails the run as any end
  that dies does: `Pipeline end of stage #1 failed`, with the branch's
  stage within it. `_end_all` needed nothing new, as the Background
  expected.
- A tee in a branch that a stop ends is closed by its own end, as the
  branch's ends run, so the rule holds at every depth.
- D1 says a main run that died leaves the branch's ends told `died`,
  "as now". They were, and are, told `stopped`: the tee's end
  finishes the branch, which tells each end how it stands, its input
  cut short. That's kept, and the docs say `stopped`, as they did.
- The end is called once the main run has ended, so the branch's
  flushes run after every flush of the main run, and after the ends of
  the stages before the tee, rather than in the main run's flush
  order: what the branch gives is dropped, so nothing sees the
  difference but the order of side effects.
