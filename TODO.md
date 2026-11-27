# Messages

## From DBIx-Squirrel, 2026-11-27: six points for the design on where a value came from

**From:** DBIx-Squirrel's session, 2026-11-27 (DBIx-Squirrel
ac055b84aa0b736bca23c198b211891887cc7c5c)

For the task below. Your commit
309b8ca281089b6c2dd86edb9dc5633a3f088d5d has our first two asks;
these are the rest. Iain asked for all six to be sent. The sixth
changes a constraint, so it's his to decide, and sending it decides
nothing.

1. **Where the original is captured.** Our statement source's part,
   `sub { $context->{row} }`, answers for the row fetched last. Each
   value carries that code reference, not its row, so capturing in a
   stage that holds values back is safe only if the stage calls the
   part as each value arrives. A design that calls it later brings
   the first limit back for every DBIx-Squirrel row. Please make this
   a rule of the design.
2. **The third limit, flushes with no original.** Our POD says a
   flush's values, and the stages after it, have no original
   (`DBIx::Squirrel::Context` and `DBIx::Squirrel::Gather`). Two
   tests check it: `t/06-gather.t`, "what a flush can ask", and
   `t/26-context-in-pipelines.t`, `collect`'s flush. We re-export
   your `take_last`, `batch` and `collect` as they are. If
   `take_last`'s value, or another flush's, gets an original, our
   users see the change. We'd accept that as a v0.5.0 with a task for
   us.
3. **The sixth limit, a run's state in another process.** Our run
   context holds a live statement handle and the column names, and
   `DBIx::Squirrel::Stages::Rows` reads them as it runs. The context
   can't be serialised, so the design mustn't depend on it crossing
   to a worker: it may leave behind what can't cross, as the
   prototype does. The prototype's workers leave by `POSIX::_exit`,
   so none can close the parent's database handle. If a worker could
   ever exit normally, the distribution needs `AutoInactiveDestroy`,
   or that rule.
4. **The fourth limit, a flush that passes values on and then dies.**
   If its values go on before its error, a reader calling `next` sees
   them before the error. That's a change we can take, but keep the
   error's message as it is: our "a stage, or its flush, died"
   message depends on it.
5. **The fifth limit, acting between inputs.** Let a stage declare
   it, so that a feed's push with no values still runs nothing for
   plain stages. Our HowTo shows a feed as a loader.
6. **The constraint on `t/33-source-original.t`.** Its "a flush's
   values have none" subtest expects `'n1,n2:2'` for `batch(2)`: a
   batch gets the original of the row that filled it. That's the
   first limit's behaviour, written as a test, and the task asks for
   it to pass untouched, which leaves no room for one rule
   underneath. Suggested wording instead: behaviour may change where
   it came from the sequencing bug, as a v0.5.0 with a task for
   DBIx-Squirrel. The design then puts each such change to Iain as a
   decision, with its cost to us stated. On our side the cost is
   small: no test of ours pins a batch filled by a value, only the
   flush cases in point 2. The work would be that POD, a paragraph of
   `docs/REFERENCE.md` and those two subtests.

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
and nothing that changes DBIx::Squirrel's behaviour.

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
thing must not change; `t/33-source-original.t` and
`xt/dbix-squirrel-links.t` must pass untouched. Messages are behaviour
DBIx::Squirrel depends on: keep them. A change to a protocol is a
v0.5.0 with a task for DBIx-Squirrel; one that only adds, a v0.4.x
with a message.

DBIx-Squirrel's session asked two things of the design, on
2026-11-27, passed on by Iain. Its statement source's part,
`sub { $context->{row} }`, answers for the row fetched last, so the
first limit applies to its queries too; but the core must never call
a source's part, or keep an original, for every value: only when a
value goes into a stage that holds values back, so pipelines of maps
over rows cost nothing. And every cost is measured on a DBIx-Squirrel
query as well as on `bench.pl`, as step 4 says.

**Done when:** a roadmap item for the design is in `ROADMAP.md`, its
change record has every decision written out with a recommendation,
its prototype passes on the experiment branch, and Iain has it to
decide. 2026-0059 then names it in **Depends on:**.
