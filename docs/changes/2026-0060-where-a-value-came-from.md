# 2026-0060. Where a value came from, through stages that hold values back

**Status:** shipped, unreleased

**Decisions:** D1 settled: a value's original is that of the value it
was made from, through stages that hold values back. D2 settled: such
a stage keeps an origin for each value it keeps, and gives what it
made from it marked, in one return. D3 settled: origins opaque. D4
settled: captured as the stage keeps the value. D5 settled: a marked
flush value has its original. D6 settled: `batch` has none, its values
unmarked in the loop. D7 settled: `take_last`'s value has its own. D8
settled: through an iterator read as a source, as proposed. D9
settled: the cost is acceptable. D10 settled: the names as proposed.
D11 settled: by name only. D12 settled: stages that hold values back
without saying so, as now. D13 settled: an unmarked value from the step
has none. D14 settled: the guard, per run. D15 settled: only what's
given is unmarked. D16 settled: the docs, all in the change. D17
settled: a v0.5.0. D18 settled: limits 4 and 5 left to 2026-0061. D19
settled: limit 6 left to 2026-0059.

**Origin:** a task in `TODO.md` from Ekorn-Pipeline's session,
2026-11-27, out of prototyping 2026-0059 (the branch
`experiment/2026-0059-worker-stages`, at
f3316bb3fc43185b956e27c37d43940f6db27305), with three messages from
DBIx-Squirrel's session the same day (DBIx-Squirrel
ac055b84aa0b736bca23c198b211891887cc7c5c)

**Started:** 2026-11-27

**Finished:** 2026-11-27

## Background

2026-0046's D3 defines `result_original` as "the value the run's own
source gave, or that was pushed, that the result is being made from,
before any stage changed it; the same for each value a stage returns
in place of one; undef in a flush and the stages after it". That's a
promise about each value. The core keeps it by keeping one original
for where the run has got to, `$CURRENT_RESULT` in
`lib/Ekorn/Pipeline.pm`, which is right while each stage is a map:
what comes out of a stage came from what just went in. 2026-0052 added
a source's `original` part, answering lazily for the value the source
gave last, which its D2 noted gives a holding stage such as `batch`
"the original of the value that filled it".

A stage that holds values back gives values the run has moved past,
so the stages after it see the latest value's original, not that of
the value theirs was made from. `take_last` and `batch` are Ekorn's
own; 2026-0059's worker stages, which run each value in a pool of
processes, made it plain: every result after them had the wrong
original, one behind. A source's part answers for the value it gave
last, so an earlier value's original is gone once the source moves
on, unless something asked for it then. DBIx::Squirrel's statement
source gives `sub { $context->{row} }`, so its rows have the same
fault after such a stage.

### The proposal

**The rule:** a value's original is the original of the value it was
made from, the source's or the caller's, before any stage changed it.
A stage that maps gives what it made from the value it was just given,
so the core needs nothing from it, and carries each value's original
through the queue of values waiting in a run, as now. A stage that
holds values back says where each value it gives came from; one it
gives that came from no one value has none. A stage that holds values
back without saying so is taken for a map, as now (D12).

**A stage that holds values back says so,** with `holds => 1` among
its parts, by name. Then:

- As it keeps a value, in the step it was given it in, it calls
  `kept_origin` (from `Ekorn::Pipeline::Context`), which returns the
  value's *origin*: an opaque object holding what `result_original`
  answers for the value then. The stage keeps the origin with the
  value.
- When it gives what it made from a value, from its step, its flush or
  carried by its stop, it gives it marked: `$origin->gives(@values)`.
  A value it gives unmarked has none (D13).

A value and where it came from travel together in the one return, so
they can't come apart, and a stage that keeps nothing, such as
`batch`, captures nothing. A stage can mark a value only with an
origin it was given. A list of parts keeps its three, and its
messages, so no stage written today changes, and `gather`'s message
("Expected stage #%s, made with gather, to return a code reference or
a pipeline, and optionally a flush and an end"), which DBIx::Squirrel's
POD lists and its `t/06-gather.t` checks, is word for word as it was.

**In the core,** a run with such a stage takes the full loop, which
then carries, with each waiting value, whether its original is known.
After a holding stage's step or flush, or its stop, the loop unmarks
what it gave, top level only (D15): the first value's original goes
into the run's state, as it goes on at once, and the rest wait on the
queue with theirs. `result_original` gives a known original before
anything else, in a flush too. There's no wrapper round the stage.
`kept_origin` croaks in a run with no stage that holds values back,
which a run nested in such a stage's step is (D14). The plain loops,
`_push_steps` and `_plain_iterator`, are unchanged. An iterator read
as a source passes on the original of the value it handed out.

**Ekorn's own stages:** `take_last` keeps the origin of the value it
keeps and gives it marked, so its value has its own original; `batch`
says it holds values back and gives its batches unmarked, so a batch
has none; `collect` needs nothing, as its flush's values have none
already.

### How the design got here

The prototypes, their scripts and the patch are on the branch, at
761ffdd0d7e14bc45794944c866fd25df60caf9a, under
`docs/experiments/2026-0059-worker-stages/`, whose README says what
each found.

1. **A stage's `original` part,** answering as a source's does
   (`stage-original/`): a stage could make up an original, and one
   answer a call left as many as 999 of 1,000 values with none.
2. **A `from` part,** the origin handed to every step and a separate
   `from` call after it returned. The first cold reviews found that it
   caused three of its four bugs (an error escaping a stop, stale state
   from an earlier call, origins out of step with values), and needed
   `from => 'many'`, a second way of saying "made from many", only to
   skip a capture `batch` didn't need.
3. **One return, through a wrapper,** which Iain chose on 2026-11-27
   (D2). The second cold reviews found the wrapper's guard, set and
   cleared round the step, left set by a stop, so the stages after it
   could call `kept_origin`; and `batch` cost about 9% of a
   DBIx-Squirrel row. DBIx-Squirrel asked for the work in the loop
   (D6) and for stages written today to behave as now (D12).
4. **One return, in the loop, with the guard set before every stage
   call:** a stop couldn't leave it set, but `batch` cost more than
   with the wrapper, about 170 ns a row in memory, and every run taking
   the full loop about 40 ns a value. The cost had never been the
   wrapper's call, but the statements a holding run runs for every row:
   the guard's two on every stage call were most of them.
5. **One return, in the loop, with the guard per run:** this.

### What the prototype shows

`where-values-came-from/holds.patch`, against `develop` at
413b7472adc7c9e032564ae5eadd3b8ed3081295, with its tests and scripts.

- **The suite:** every existing test passes, on Perl 5.36 and 5.44,
  but the two that pin the fault itself, `t/32-context.t`'s and
  `t/33-source-original.t`'s batch subtests, each changed to a batch
  with none (D6), and `t/32-context.t`'s list of Context's exports,
  which gains `kept_origin` (D10). `xt/agreement.t`'s 3,000 random
  pipelines agree. `t/35-where-values-came-from.t` adds 16 subtests:
  each value's own original, after a stage and through several at
  once, in a flush, through maps, splits and a later flush; the stage
  and those before it as now; the source's part asked once for each
  value kept, as it's kept, never through maps or by `batch`; a pushed
  and a fed run, giving the value passed in; a stop carrying marked
  values; values made from many; `take_last`, `batch` and `collect`;
  an iterator read as a source; where `kept_origin` croaks, after a
  stop included, and what it gives in a flush; by name only, from a
  class's `EKORN_STAGE`, croaking beside a pipeline, and `gather`'s
  message word for word; a run ended from outside mid-step leaving
  nothing for another; and the feature nested in itself, in its own
  step.
- **Every way of running agrees:** `all`, `next`, pushed and fed, over
  eleven pipelines of holding stages before and after splits, two in a
  row, stops before, after and carried through them, a holding stage
  in a tee's branch, and one last.
- **The worker stages,** keeping an origin for each value, give every
  result marked as it's ready: over 1,000 values through `in_workers`
  and `once_per`, none is without its original or has another's.
  Pushed or fed, each has the value passed in.

### The cost

DBIx-Squirrel's queries, 200,000 rows of SQLite through
`$dbh->iterate`, Perl 5.36, ns a row, each the median of seven, three
runs a core, and the cost as a share of a row, as its message asked:

| The query's stages | Loop | `develop` | The proposal | Cost a row |
|---|---|---|---|---|
| a map | `_plain_iterator` | 1,415 to 1,422 | 1,410 to 1,443 | none |
| a map, `take` | `_plain_iterator` | 1,672 to 1,692 | 1,674 to 1,683 | none |
| a map, `count_items` | `_full_iterator` | 1,421 to 1,431 | 1,445 to 1,464 | 15 to 33 ns, 1 to 2% |
| a map, `batch(100)` | `_full_iterator` | 1,525 to 1,535 | 1,594 to 1,612 | 62 to 87 ns, 4 to 6% |
| a map, `take_last` | `_full_iterator` | 1,475 to 1,500 | 1,875 to 1,884 | about 400 ns, 26% |

The third design, with its wrapper, cost `batch` 130 to 145 ns a row,
about 9%, and the fourth about 170; this one's check after every
stage call costs a full-loop run with no holding stage more than the
third's did, which `count_items` shows.

`batch`'s is the statements a run with a holding stage runs for every
row, about 60 to 90 ns: the check for what each stage gave, and the
resetting of whether a value from the source has a known original. It
keeps no origin, so pays nothing for the capture or for opacity.
`take_last` keeps
every row, so captures an origin for each; DBIx-Squirrel's message
gives Iain's view that it's a debugging tool, not for production and
least of all over SQL, so its cost doesn't weigh on the design.

On Ekorn's own benchmark (`bench.pl`), a run taking the full loop with
no holding stage costs +35 to 90 ns a value on Perl 5.36, 3 to 4%,
and +42 to 126 on Perl 5.44, 4 to 5%: the check after each stage call
for what a holding stage gave, the resetting of a value's known
original, and the run's state's two more slots. The third design, with
its wrapper, cost such a run +3 to 40 ns, but `batch` twice as much.

## Decisions

All settled, as recommended, on 2026-11-27, D2 after the first cold
reviews; each kept with the options weighed and why.

- [x] **D1.** What is a value's original, through a stage that holds
  values back? (a) The original of the value it was made from, as
  2026-0046's D3 promises. (b) As now: the original of the value the
  run got to last. Recommended: (a), Iain's reading of 2026-11-27. Iain
  decided on 2026-11-27, as recommended.
- [x] **D2.** How does such a stage say where its values came from?
  It keeps an origin, `kept_origin`, for each value it keeps, and gives
  what it made from it marked by the origin, `$origin->gives(...)`, in
  the same return. Iain decided on 2026-11-27, as recommended after
  the first cold reviews, over the origin handed to every step with a
  separate `from` call and `from => 'many'`: a value and its origin
  can't come apart, a stage that keeps nothing captures nothing, and
  there's one way of saying each thing.
- [x] **D3.** Is the origin opaque, a blessed object a stage can only
  hand back, or the original itself, with a rule in the docs? Opaque
  costs about 27 ns a value kept (`bless`), and nothing for a stage
  that keeps none, such as `batch`; marking a value needs an object
  either way. An origin kept in one run could mark a value in another,
  which the core doesn't check, harmlessly. Recommended: opaque. Iain
  decided on 2026-11-27, as recommended.
- [x] **D4.** When is a value's original captured? As the stage keeps
  it, in the step it was given it in: `kept_origin` captures what
  `result_original` answers now, so can't be asked for a value later.
  DBIx-Squirrel's rule (its message of 2026-11-27), as its source's
  part answers for the row fetched last. Recommended: yes. Iain decided
  on 2026-11-27, as recommended.
- [x] **D5.** Does a flush's value have an original? 2026-0046's D3
  says none, taking a flush's values to come from many. Under D1, a
  value given marked has its original, in a flush too; one given
  unmarked, or by a flush of a stage that doesn't hold values back,
  has none, as now. `ending` stays true in a flush, but its documented
  reason, that a flush's value has no origin (`docs/REFERENCE.md`'s
  `ending`, which says DBIx::Squirrel "has no row to give while
  `ending` is true"), no longer holds for marked values, and is
  reworded. DBIx::Squirrel documents and tests that a flush's values
  have none (its Context and Gather POD, `t/06-gather.t`, "what a flush
  can ask", and `t/26-context-in-pipelines.t`, `collect`'s flush), and
  would accept the change as a v0.5.0 with a task. Recommended: yes.
  Iain decided on 2026-11-27, as recommended.
- [x] **D6.** What is a batch's original, and how is it found? (a)
  None: `batch` holds values back and gives its batches unmarked,
  made from many, as `collect`'s are; the loop unmarks what a holding
  stage gives, with no wrapper, as DBIx-Squirrel asked (its message of
  2026-11-27, choosing what was then D6(c)): 62 to 87 ns a DBIx-Squirrel
  row, 4 to 6%, where the third design's wrapper cost 9%. (b) As now,
  the original of the value that filled it, by staying
  a map to the core: no cost, and the fault kept for batches. Iain
  allowed `t/33`'s subtest to change on 2026-11-27, as behaviour that
  came from the first limit, as a v0.5.0 with a task for
  DBIx-Squirrel, whose own tests don't pin a batch filled by a value.
  Recommended: (a). Iain decided on 2026-11-27, as recommended.
- [x] **D7.** Does `take_last`'s value have its original? (a) Yes, its
  own, marked. (b) No, as now. Its cost doesn't weigh (as above).
  Recommended: (a). Iain decided on 2026-11-27, as recommended.
- [x] **D8.** What does an iterator read as a source pass on? The
  original of the value it handed out, known or its source's part's
  answer, as now. With no source part, nothing, as now, so a run
  reading it gets the value handed out (2026-0046's D3). A value from
  a flush of a stage that doesn't hold values back still reaches the
  reading run with the inner source's latest original, as on
  `develop`. Recommended: as proposed, and that last left as it is. Iain
  decided on 2026-11-27, as recommended.
- [x] **D9.** Is the cost acceptable? Nothing on the plain loops,
  which DBIx-Squirrel's queries of maps and `take` take; 3 to 5% on a
  full-loop run with no holding stage (1 to 2% on DBIx-Squirrel's query
  with `count_items`), as 2026-0046's D4 accepted
  for counting; and what a holding stage costs itself (D6, D7).
  Recommended: yes. Iain decided on 2026-11-27, as recommended.
- [x] **D10.** The names: the part `holds`, the first part that's a
  flag, not code; `kept_origin`, in `Ekorn::Pipeline::Context` and
  Tooling's `:context`, which goes to DBIx-Squirrel as a message, and
  clashes with none of its names; the method `gives`; the classes
  `Ekorn::Pipeline::Origin` and `Ekorn::Pipeline::Origin::Given`; and
  two messages, "Expected kept_origin in the step of a stage that
  holds values back" and "Expected stage #%s, made with gather, to
  hold values back in its step, not in a pipeline". A review found
  `kept_origin` reads as already kept, though it captures now, and
  `gives` as the origin giving; `marks` or `of` were offered.
  Recommended: as proposed, or Iain's choice. Settled as proposed: Iain
  decided on 2026-11-27, as recommended.
- [x] **D11.** By name only? A source's parts may be a list, its
  `original` fourth; a stage's list keeps its three, so `holds` is
  only by name: a list of four would change `gather`'s message, which
  DBIx::Squirrel checks. A misspelt key, such as `hold`, is ignored,
  as any key Ekorn doesn't read is ("Made for a run"), so the stage is
  taken for a map. Sinks give nothing to stages after them, so a
  sink's `holds` is ignored. Recommended: by name only, and the docs
  say so. Iain decided on 2026-11-27, as recommended.
- [x] **D12.** A stage that holds values back without saying so, as
  every one written today does, DBIx::Squirrel's `batches_of`, in its
  Gather's synopsis, among them: taken for a map, as now, so the
  stages after it see the latest value's original. DBIx-Squirrel asked
  for this (its message of 2026-11-27). No default could find such a
  stage anyway: a gather with a flush is often a map with a total, as
  the reference's `ending` example is. The docs say a stage that holds
  values back says so, and the how-to shows how. Recommended: as
  proposed. Iain decided on 2026-11-27, as recommended.
- [x] **D13.** What is the original of a value a holding stage gives
  unmarked, from its step? (a) None, as from its flush: one way of
  saying "came from no one value", but a stage that passes some values
  straight through must keep an origin and mark each. (b) The value's
  just given, as a map's, and none only in a flush: a value from the
  step made from many would then need a mark of its own, a second way
  of saying it. Recommended: (a), with D2. Iain decided on 2026-11-27,
  as recommended.
- [x] **D14.** Where does `kept_origin` croak? (a) In a run with no
  stage that holds values back, which a run nested in such a stage's
  step is: free, as the run's state says so once a run. It doesn't
  croak in another stage of a run that has one, or in a holding
  stage's flush, where it gives an origin of nothing, as a flush has no
  value. (b) Anywhere but a holding stage's step: two statements on
  every stage call of a run with a holding stage, about 100 ns a row on
  `batch` (the fourth design). (c) As (b), by a wrapper round the step:
  about 60 ns a row more than (a), and a stop must be caught to reset
  it (the third design). Recommended: (a), and the docs say where it
  belongs. Iain decided on 2026-11-27, as recommended.
- [x] **D15.** Only what a holding stage gives, top level, is
  unmarked: a marked value inside a structure it gives, or one marked
  by a stage that doesn't hold values back with an origin kept
  elsewhere, goes on as an `Ekorn::Pipeline::Origin::Given` object.
  Recommended: so, and the docs say so. Iain decided on 2026-11-27, as
  recommended.
- [x] **D16.** The docs: the reference's parts ("Made for a run"),
  `result_original`, `ending` (D5), the example that says a batch
  filled by a value has its original (the "last Parklife", tested by
  `xt/`), a new `kept_origin` and `gives`, and the diagnostics for the
  two new messages; the how-to's recipe for a stage that holds values
  back; `Ekorn::Pipeline::Context`'s, `Gather`'s and the stages' POD;
  and that nothing changes for feeds, tees, sinks and `result_number`.
  Recommended: all, in the change. Iain decided on 2026-11-27, as
  recommended.
- [x] **D17.** Which version? A v0.5.0: what `batch`, `take_last` and a
  marked flush value give changes, with a task for DBIx-Squirrel (its
  range is `< v0.5.0`). Its work, as its messages say: its POD's parts
  gain `holds`, its Context and Gather POD and two subtests change
  (D5), a paragraph of its `docs/REFERENCE.md`, and `kept_origin`
  reaches it as a message; none of its documented examples reads
  `result_original` after `batch`, `collect` or `take_last`.
  Recommended: v0.5.0. Iain decided on 2026-11-27, as recommended.
- [x] **D18.** The task's limits 4 and 5, a flush that passes values on
  and then dies, and a stage acting between its inputs: this design
  doesn't need them, as the worker stages give each result as it's
  ready, with its original. They share an answer, a stage asked for
  what's ready between inputs and as its input runs out, so are idea
  2026-0061, with DBIx-Squirrel's two conditions: the error's message
  kept, and something a stage declares. Recommended: leave them to it.
  Iain decided on 2026-11-27, as recommended.
- [x] **D19.** The task's limit 6, a run's state in another process:
  nothing in this design needs a run's state to cross. The worker
  distribution (2026-0059) replays a run's context in its workers;
  its `_where` asks `result_original` for every value and sets
  `$Ekorn::Pipeline::CURRENT_RESULT` by hand, which it should do only
  for the values it keeps, and by something Ekorn offers; its workers
  leave by `POSIX::_exit`, so can't close a parent's database handle.
  Recommended: leave it to 2026-0059, with those as its rules. Iain
  decided on 2026-11-27, as recommended.

## The plan

**What:** D1 to D19, from the fifth design on the branch
`experiment/2026-0059-worker-stages`, at
761ffdd0d7e14bc45794944c866fd25df60caf9a
(`docs/experiments/2026-0059-worker-stages/where-values-came-from/holds.patch`).
`_make_run` reads `holds` from a gather's or an `EKORN_STAGE`'s parts
by name, and croaks beside a pipeline; a run with such a stage takes
`_full_iterator`, which carries a known original with each waiting
value, unmarks what a holding stage gives after its step, its flush or
its stop, and says in the run's state that it has such a stage, for
`kept_origin`. `result_original` gives a known original first.
`kept_origin`, defined in `lib/Ekorn/Pipeline.pm` beside
`result_original` and exported by `Ekorn::Pipeline::Context` and
Tooling's `:context`, returns an `Ekorn::Pipeline::Origin`, whose
`gives` marks values as `Ekorn::Pipeline::Origin::Given`, both packages
in `lib/Ekorn/Pipeline.pm`, as `t/34-versions.t` allows one `$VERSION`
a file. `take_last` keeps an origin and gives its value marked;
`batch` says `holds` and gives its batches unmarked. The plain loops
don't change.

**Why:** the background: `result_original` keeps its promise through
stages that hold values back, the worker stages of 2026-0059 among
them, with nothing changed for stages written today.

**Steps:**

1. The core, Context and Tooling, `take_last` and `batch`, from the
   prototype, tidied and documented in the code as the rest is.
2. Tests: `t/35-where-values-came-from.t` from the prototype, and
   `t/32-context.t` and `t/33-source-original.t`'s batch subtests and
   Context's exports, as D6 and D10 settled; the feature nested in
   itself among them. Coverage at or above its floors.
3. The docs, as D16: the reference's parts, `result_original`,
   `ending`, the "last Parklife" example, `kept_origin` and `gives`, and
   the diagnostics; a how-to recipe for a stage that holds values back;
   the POD of `Ekorn::Pipeline`, Context, Gather, Flow and Batch. Then
   `scripts/manuals`, and the docs' example tests.
4. `Changes`, under Unreleased, as a v0.5.0 (D17).
5. Every commit's checks: yath on every Perl CI covers, perlcritic
   and perltidy on 5.44, coverage, `xt/`, `xt/dbix-squirrel-links.t`.
   `bench.pl` and `dbix-bench.pl` against v0.4.5, as the record's
   figures were taken.
6. A task for DBIx-Squirrel, to test against `develop` and plan its
   v0.5.0 work (D17), with `kept_origin` for its Tooling as a message.

**Done when:** each step is done, its checks pass, and DBIx-Squirrel
has its task.

## What happened

- **Outcome:** each step done, and Done when met but for the task for
  DBIx-Squirrel, sent with the commit that ships it. The tests pass on
  every Perl CI covers, 5.36 to 5.44, `xt/` with them; perlcritic and
  perltidy are clean on 5.44; coverage is at its floors, branches at
  100%.
- **Changes from the plan:**
  - The run's list of the originals a holding stage gave after the
    first is a lexical of each run, not the prototype's package
    variable: the loop does all the unmarking, so nothing outside it
    reads the list, and a run nested in another can't see it.
  - Choosing the plain loop is one helper, `_is_plain`, and reading
    `holds` another, `_holds_part`, where the prototype repeated each.
  - `t/35-where-values-came-from.t` was rewritten in the house style,
    with a subtest more than the prototype's: a value from the flush of
    a later stage that doesn't hold values back, read through an
    iterator, gets the source's latest original, as before (D8), the
    branch coverage found untested.
  - The reference's "last Parklife" example, which printed nothing so
    was never checked, is two examples that print, `batch`'s and
    `take_last`'s, so `xt/examples.t` checks them. The reference has a
    new section, "Stages that hold values back"; the how-to a recipe,
    "Say where held values came from".
- **Tried and reverted:** to keep perltidy from aligning three lines,
  the pulls reset the known flag in the same assignment as the
  original, `@result[1, 3] = ($value = shift @from_source, 0)`, for
  every run; it cost full-loop runs with no holding stage 56 to 184 ns a
  value, against the prototype's 35 to 90. The reset is back to a
  plain assignment and a block run only in a run with a holding stage.
- **Measurements,** against v0.4.5, Perl 5.36, medians of seven,
  interleaved:

  | `bench.pl` | Cost a value |
  |---|---|
  | a stage with a flush | +30 to 35 ns |
  | asking `result_original` for every value | about +50 ns |
  | values waiting on the queue | +70 to 85 ns |
  | a pushed run with a flush | about +35 ns |

  Within a few nanoseconds of the prototype's fifth design, 3 to 4%.
  On DBIx-Squirrel's queries, 200,000 rows through `$dbh->iterate`:

  | The query's stages | v0.4.5 (ns a row) | v0.5.0 (ns a row) | Cost a row |
  |---|---|---|---|
  | a map | 1,399 to 1,435 | 1,399 to 1,426 | none |
  | a map, `take` | 1,654 to 1,695 | 1,658 to 1,689 | none |
  | a map, `count_items` | 1,416 to 1,439 | 1,436 to 1,452 | 13 to 20 ns, about 1% |
  | a map, `batch(100)` | 1,506 to 1,540 | 1,585 to 1,607 | 67 to 83 ns, 4 to 5% |
  | a map, `take_last` | 1,463 to 1,488 | 1,855 to 1,872 | about 390 ns, 26% |
- **What's left:** DBIx-Squirrel's task, its v0.5.0 work; 2026-0059,
  the worker stages, which can now say where their results came from;
  and 2026-0061.
