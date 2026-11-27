# 2026-0062. Tests that try to break each promise, here and in DBIx-Squirrel

**Status:** shipped

**Decisions:** D1 settled: originals, dies, nesting and runs again,
compared every way. D2 settled: one generator, kept here, values
opaque. D3 settled: the rule, in the same words, where decisions are
settled. D4 settled: a one-time list of promises already made, each
tried. D5 settled: the rule as a check before each release.

**Origin:** roadmap, added 2026-11-27, after 2026-0060; agreed with
DBIx-Squirrel's session by messages, as its 2026-0066 (DBIx-Squirrel
a2e32047f6f45cc2882346405f94ed4f0209a132)

**Started:** 2026-11-27

**Finished:** 2026-11-27

## Background

2026-0060's fault hid in the gap between a promise and an assumption:
2026-0046's D3 promised each result its value's original, but the code
assumed every stage maps, and every test used maps, so no review tried
the promise against a stage that holds values back. It passed every
review, here and in DBIx-Squirrel.

`xt/agreement.t` runs random pipelines pushed, pulled, read with `all`
and fed, and compares their values. It compares no originals, has no
stage that dies, and nests only through `gather` and `tee`, never a run
inside a stage that holds values back.

DBIx-Squirrel was asked for its view before anything was designed
(DBIx-Squirrel 7bb2feebbe6101f54be346310b6934a196c574c6). A probe of
its v4.3.0 tried six of its promises with stages that hold values
back, stop, die or nest; all held, but none is in its suite. Three
more messages settled one practice for both (Ekorn-Pipeline's in
DBIx-Squirrel 9b1f6b8d9a6f5a45ebd6d07c43a4237548d813ff and
9f510525ee42839b7e88741da392435d715937e6, DBIx-Squirrel's in our
a20e49a36e25c13662d9ba146f8c0580d446dcbe), and Iain settled
DBIx-Squirrel's 2026-0066 as D1 to D5 below, naming this item. Its
work waits on D2's generator, so that comes first here.

## Decisions

- [x] **D1.** What does our agreement test try? Recommended: values
  and originals compared every way, from a source with an `original`
  part; stages that hold values back, split, stop, die and run nested,
  including runs inside stages that hold values back; every way dying
  the same; and, after each stop or die, the same pipeline run again,
  giving what a fresh one gives. DBIx-Squirrel's own test does the
  same over a statement, also checking it isn't `Active` after each.
  Settled on 2026-11-27, as recommended, as the fault lay where the
  test never looked: originals, and stages that aren't maps.
- [x] **D2.** Where do the random pipelines come from? Recommended:
  one generator, `xt/lib/RandomPipelines.pm`, kept here, as the
  stages are ours, and copied to DBIx-Squirrel as it is, its header
  naming the commit it came from; a change either project wants goes
  to the other as a message. It makes stages and their names, with no
  source or driver. Its header names its contract: values opaque, but
  for a `number` function from the caller that the stages computing
  with values ask; extra makers from the caller (DBIx-Squirrel's
  nested statement run, `pluck`, `as_hash`); driven by the caller's
  `srand`, whose seed the driver prints, so a failure can be replayed.
  Settled on 2026-11-27, as recommended, as the stages are ours, and
  one generator keeps both projects trying the same pipelines.
- [x] **D3.** How do new promises get tested? Recommended: this
  sentence, in the same words in both projects, where a record's
  decisions are settled (ours is `docs/changes/README.md`):

  > **A promise is tested against what it doesn't mention.** A
  > decision that promises something of every value or every run
  > names, when it's settled, the test that tries to break it with
  > stages the decision doesn't mention: one that holds values back,
  > splits, stops, dies or runs nested. The item doesn't ship until
  > that test passes.

  Settled on 2026-11-27, as recommended, as a promise is cheapest to
  test when it's made, and the same words keep the two projects
  reviewing alike.
- [x] **D4.** And promises already made? Recommended: a one-time list
  of the settled decisions promising something of every value or every
  run, each with the test that tries it, as part of this item.
  Settled on 2026-11-27, as recommended, as the rule only reaches new
  decisions, and 2026-0060's fault was in an old one.
- [x] **D5.** And between items? Recommended: the same sentence as a
  check in step 1 of Making a release in `docs/MAINTAINING.md`: each
  promise made of every value or every run is tried against stages it
  doesn't mention. DBIx-Squirrel puts it in the same step of its own,
  not in the shared practice's wash-ups.
  Settled on 2026-11-27, as recommended, as the fault passed every
  review between items too, and Making a release is our nearest to a
  wash-up.

## The plan

**What:** a generator of random pipelines in `xt/lib`, shared with
DBIx-Squirrel; `xt/agreement.t` driving it to compare values and
originals every way, through stages that die and runs nested in stages
that hold values back, and running each pipeline again; the rule for
promises in `docs/changes/README.md` and in step 1 of Making a
release; and the promises already made, listed here, each with a test
that tries it.

**Why:** 2026-0060's fault was a promise made of every value but
tested only with maps, and nothing in either project's process would
have tried it otherwise.

**Steps:**

1. Write `xt/lib/RandomPipelines.pm` (D2): random stages and their
   names, from the caller's `srand`, values opaque but for the
   caller's `number`, extra makers from the caller. Its makers are
   `xt/agreement.t`'s, made opaque, and new ones: a stage that dies at
   a value, a run nested in a step, and a stage that holds values back
   (with `holds` and `kept_origin`) whose step and flush give through a
   nested run.
2. Rewrite `xt/agreement.t` over it (D1): each case made from a seed
   of its own, so it can be made again fresh and replayed; a source
   with an `original` part; the last stage before any sink recording
   each value with its `result_original`; every way giving the same
   record, or dying with the same error; and each way's pipeline, run
   again after the other ways, giving what a fresh one gives.
3. Break the core in a scratch copy, as 2026-0060's fault did (the
   latest value's original after `take_last`), and see the test fail.
4. Put the rule (D3) in `docs/changes/README.md`, and the check (D5)
   in step 1 of Making a release in `docs/MAINTAINING.md`, with what
   it runs.
5. List the settled decisions, in every record, that promise
   something of every value or every run (D4), here, each with the
   test that tries it against the stages it doesn't mention, writing
   the tests missing.
6. Send DBIx-Squirrel the generator, as a task for its 2026-0066.

**Done when:** the generator is in `xt/lib` and DBIx-Squirrel has it
as a task; `xt/agreement.t` does as D1 says, passes, and fails on the
broken copy; the rule is in `docs/changes/README.md` and step 1 of
Making a release; and each promise on D4's list has a test that tries
it.

## What happened

- **Outcome:** met. The generator is in `xt/lib`, and DBIx-Squirrel
  has it as a task (DBIx-Squirrel
  b570f4dd0f89511dc4813110bf825e5dbe19a2ee). `xt/agreement.t` does as
  D1 says, passes on Perl 5.36 and 5.44 and with other seeds, and
  failed on each of four breaks. The rule is in
  `docs/changes/README.md` and step 1 of Making a release, and each
  promise on D4's list below has what tries it, or says why it's left
  to the hand-written tests.
- **No line in `Changes`,** as the tests and records aren't in the
  distribution and change nothing for users, as 2026-0058 shipped.

- **Steps 1 to 3:** `xt/lib/RandomPipelines.pm` makes the stages, and
  `xt/agreement.t` drives it. Three things the plan didn't foresee:
  - **Agreement can't see 2026-0060's fault,** which every way had
    alike. So the test also checks each result's original against the
    truth: a case's values are all different, so a value holding any
    of them was made from its original only if the original is one.
    A value holding none, such as a nested `collect` of nothing, has
    nothing to tell, and isn't checked.
  - **A death's message names the line that ran the way,** which
    differs by way, so that's taken out before comparing.
  - **`collect` gathers into an array reference** rather than
    counting, and "as a number" is gone, so no stage makes a value
    the caller's `number` wasn't given.
- **Broken on purpose,** in scratch copies of `lib`: with
  `result_original`'s known branch taken out, 2026-0060's fault, the
  test failed on the first five cases it met, "one behind" and
  `batch(1)` among them, with "not made from its original"; with
  `take_last`'s held value shared by every run, it failed on a fed run
  after the other ways giving the stale value again. On `lib` it
  passes on Perl 5.36 and 5.44, and with seeds 1 to 5 at 5,000 cases,
  in about three seconds at its 3,000.
- **Step 4:** the rule is in `docs/changes/README.md`'s How a record
  is kept, in D3's words, and the check in step 1 of Making a release,
  opening with D5's sentence, with a loop running `xt/agreement.t`
  with seeds 1 to 3.
- **Step 5, the promises already made (D4).** Each settled decision
  promising something of every value or every run, and what tries it
  now with stages it doesn't mention. "Agreement" is `xt/agreement.t`,
  whose random pipelines hold values back, split, stop, die, nest, run
  a pipeline as a stage, and have ends.

  | Promise | Tried by |
  |---|---|
  | 2026-0002's D1: an iterator that has ended gives nothing more | Agreement: each pulled run is called again after it ends; `t/02` |
  | 2026-0003's D1, 2026-0022's D17: a pipeline pushed in scalar context gives how many results | Agreement, without a sink: counted against the list; `t/02`, `t/15` and `t/22` with a sink |
  | 2026-0004's D1 and D3, 2026-0007's D1: a pipeline given as a stage runs as its stages would | Agreement: "as a stage", every way; `t/10` |
  | 2026-0022's D11, D16, D20, D34, D45 and D48: ends run in order, each told how the run ended, and `ended` says the same | Agreement: an end of the driver's logs what it's told, and `ended` is compared, every way; `t/15` and `t/28` for what each should be |
  | 2026-0022's D27: an end dying while the run dies warns, keeping the first error | `t/15` only: the random ends don't die |
  | 2026-0032's D2, 2026-0040's D1, 2026-0041's D3: the shorter way a plain run takes gives what the full path does | Agreement: each way again on the full path, by a stage with an end; `t/22` and `t/27` for the order parts are called in |
  | 2026-0044's D2 to D5: a feed gives what a pulled run does, and takes no push once its run has ended | Agreement: fed every way, and pushed again once ended; `t/28` for `finish` and a feed let go |
  | 2026-0044's D6: a feed's stages see the pusher's context | `t/28`: not a promise of each value |
  | 2026-0046's D2: `result_number` counts each run's results from 1 | Agreement: each result's number, every way, nested runs counting their own; `t/32` |
  | 2026-0046's D3, 2026-0052's D2 to D4, 2026-0060's D1 and D5 to D8: each result has the original of the value it was made from, through sources' original parts, iterators, holding stages and flushes | Agreement: compared every way, and checked against the truth: a number is its own original, and a value holding numbers holds its original; `t/32`, `t/33` and `t/35` |
  | 2026-0048's D4 to D6, 2026-0050's D1: a stop in a tee's branch ends only the branch; a death in it kills the run; its flushes and ends run with the tee's | Agreement: tees of random stages, every way; `t/29` |

  Left to the hand-written tests, as random pipelines can't tell what
  an end should be told, only that every way tells it the same: what
  each verdict should be (`t/15`), an end that dies (`t/15`), the
  order every part is called in (`t/22`, `t/27`), and `finish`
  (`t/28`). 2026-0050's D1 says a dead main run tells a branch's ends
  `died`; its own What happened corrects that to `stopped`, which
  `t/29` pins.
- **Agreement grew for D4:** each result's number in the log; a
  number's original must be itself, so a value given unmarked by
  `take_last` fails; how each iterator and feed says it ended,
  compared; an iterator called and a feed pushed after the end; a
  pipeline as a stage, a maker in the generator; an end, the
  driver's own maker, showing the hook DBIx-Squirrel's will use; each
  way on the full path; and the count in scalar context. Broken in
  scratch copies, as a `take_last` giving its value unmarked and as a
  plain iterator saying `done` for a stopped run, it failed on both,
  as on the two breaks before. It takes about six seconds at 3,000
  cases, twice what it did, as each case runs twelve ways.
