# Planned work

## Design: where a value came from, through stages that hold values back

**From:** Ekorn-Pipeline's session, 2026-11-27 (the branch
`experiment/2026-0059-worker-stages`, at
f3316bb3fc43185b956e27c37d43940f6db27305)
**Waiting on:** nothing

Prototyping roadmap 2026-0059, stages that run each value in worker
processes, kept running into the same few limits of the core, each
worked round in the prototype rather than fixed. This task is to
design the fix to those limits, as one design, before 2026-0059 or
anything like it is built on them. It's a design for Iain to decide,
not code: the outcome is a roadmap item with a change record whose
questions are numbered decisions, as `docs/changes/README.md` says,
designed first as an epic change is: one design, a prototype on the
experiment branch, and cold reviews. Iain wants a fix to what's
underneath, not a patch for 2026-0059: nothing that splits the core
in two, or adds a second way to say the same thing beside the first,
and no change to DBIx::Squirrel's behaviour but those the
constraints below allow.

**Read first:** `docs/experiments/2026-0059-worker-stages/README.md` on
the branch (`git show
f3316bb3fc43185b956e27c37d43940f6db27305:docs/experiments/2026-0059-worker-stages/README.md`):
its "What the prototypes found" and "Open questions" are the brief.
Then the records of 2026-0046 (Context, and D3: a flush's values have
no original), 2026-0052 (a source's `original` part, and D2: it answers
for the value the source gave last) and 2026-0044 (feeds; D6: no
context of their own).

**The limits, as found:**

1. **The original belongs to where the run is, not to the value.**
   `$CURRENT_RESULT` in `lib/Ekorn/Pipeline.pm` keeps one current
   original, and every stage is taken to be a map. A stage that holds
   values back (`batch`, `take_last`, a worker stage) gives values the
   run has passed, and the stages after it see the latest value's
   original. A source's part answers lazily, so an earlier value's is
   gone once the source moves on.
2. **A source can say where its values came from; a stage can't.**
   The branch's `stage-original/` lets a gather give an `original`
   part, as a source does, and it works: no stage after a worker
   stage got another value's original. But a part answers with a
   value, so a stage could make up an original rather than point to
   one that came in; and one answer a call can't serve a flush that
   gives several values, which leaves a tail with none. Iain's reading
   (2026-11-27): the original is what came into the pipeline, the
   source's or the caller's value; a stage should at most say which.
3. **D3 makes a flush's values originless,** taking them to come from
   many. A held-back value from a flush came from one.
4. **A flush can't pass values on and then die:** values taken in a
   flush before an error are lost with the run.
5. **Nothing lets a stage act between its inputs:** a feed's push with
   no values runs nothing. Draining a backlog, polling workers, and
   stages by time all need it.
6. **A run's state can't be carried to another process or replayed:**
   `%running` (context, `ending`) is a lexical; the prototype replays
   it through a one-value run per value.

`result_number` in a delayed block is the number at arrival, and can't
be otherwise; that's for the docs, not this design.

**What to do:**

1. Find the model underneath: what "where a value came from" should
   mean, so that one rule covers sources, the caller's values, stages
   that map, and stages that hold values back, flushes included.
   Start from Iain's reading in limit 2.
2. Decide which of limits 3 to 6 that model settles, which need
   something of their own, and which to leave. Say for each why.
3. Write the roadmap item and its change record: background (from the
   branch's README), the decisions as D1, D2..., each with options and
   a recommendation, and a plan. Put every question to Iain there, not
   in the chat. The branch's open questions are a start.
4. Prototype the recommended design on the experiment branch, against
   a copy of the core, as `stage-original/` was: the existing suite
   unchanged, new tests (the feature nested in itself among them), and
   `bench.pl` against the core as it was. Measure a DBIx-Squirrel
   query too, with the branch's `stage-original/dbix-bench.pl` (added
   in b1bc5cfab1317886ae0947e91e1003462e549f7e; its README has the
   figures for the prototype and the command): its queries with only
   maps take `_plain_iterator`, and those with a flush, an end or a
   sink `_full_iterator`. A cost on the plain loops (`_push_steps`,
   `_plain_iterator`) needs a strong reason.
5. Ask for cold reviews of the design, then bring it to Iain.

**Constraints:** DBIx::Squirrel's `result_original` and `result_number`
are Ekorn's own subs, and its statement source gives an `original`
part, so their behaviour in every pipeline that doesn't use the new
thing must not change, except as the next paragraph allows.
`xt/dbix-squirrel-links.t` must pass untouched. Messages are behaviour
DBIx::Squirrel depends on: keep them. A change to a protocol is a
v0.5.0 with a task for DBIx-Squirrel; one that only adds, a v0.4.x
with a message.

Behaviour may change where it came from the first limit, as a v0.5.0
with a task for DBIx-Squirrel, as Iain decided on 2026-11-27, at
DBIx-Squirrel's suggestion: the design puts each such change to him
as a decision, with its cost to DBIx-Squirrel stated.
`t/33-source-original.t`'s "a flush's values have none" subtest is
one: it expects `'n1,n2:2'` for `batch(2)`, a batch given the original
of the row that filled it, which is the first limit written as a test.
The rest of `t/33` must pass untouched.

DBIx-Squirrel asked these of the design, on 2026-11-27 (its message
from DBIx-Squirrel ac055b84aa0b736bca23c198b211891887cc7c5c, read in
the commit that put them here):

- **Capture only where values are held back, and as they arrive.**
  The core must never call a source's part, or keep an original, for
  every value: only when a value goes into a stage that holds values
  back, so pipelines of maps over rows cost nothing. And that stage
  must ask as each value arrives, never later: DBIx::Squirrel's
  statement source's part, `sub { $context->{row} }`, answers for the
  row fetched last, and each value carries that code reference, not
  its row. A rule of the design.
- **Measure on a DBIx-Squirrel query** as well as on `bench.pl`, as
  step 4 says.
- **The third limit:** if `take_last`'s value, or another flush's, gets
  an original, DBIx::Squirrel's users see it. It documents that a
  flush's values have none (`DBIx::Squirrel::Context` and
  `DBIx::Squirrel::Gather`), tests it (`t/06-gather.t`, "what a flush
  can ask", and `t/26-context-in-pipelines.t`, `collect`'s flush), and
  re-exports `take_last`, `batch` and `collect` as they are. It would
  accept the change as a v0.5.0 with a task. Its work would be that
  POD, a paragraph of its `docs/REFERENCE.md` and those two subtests;
  no test of its own pins a batch filled by a value.
- **The fourth limit:** if a flush's values go on before its error, a
  reader calling `next` sees them first, which it can take; but keep
  the error's message as it is, which its "a stage, or its flush,
  died" message depends on.
- **The fifth limit:** acting between inputs is something a stage
  declares, so a feed's push with no values still runs nothing for
  plain stages. Its how-to shows a feed as a loader.
- **The sixth limit:** its run context holds a live statement handle
  and the column names, which `DBIx::Squirrel::Stages::Rows` reads as
  it runs, and can't be serialised. The design mustn't depend on the
  context crossing to a worker; it may leave behind what can't cross,
  as the prototype does. A worker must leave by `POSIX::_exit`, as the
  prototype's do, so it can't close the parent's database handle, or
  the distribution needs `AutoInactiveDestroy`.

**Done when:** a roadmap item for the design is in `ROADMAP.md`, its
change record has every decision written out with a recommendation,
its prototype passes on the experiment branch, and Iain has it to
decide. 2026-0059 then names it in **Depends on:**.
