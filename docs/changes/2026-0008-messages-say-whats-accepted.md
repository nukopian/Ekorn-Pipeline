# 2026-0008. Messages that say what's accepted

**Status:** shipped, unreleased

**Decisions:** D1 settled: "...to be a code reference or a pipeline". D2 settled: the gather message names a code reference or a pipeline, and the end function. None open.

**Origin:** roadmap, added 2026-11-09, when Iain found the reference
quoting "Expected stage #2 to be a code reference" for something that's
neither a code reference nor a pipeline; widened the same day by his
words in DBIx-Squirrel's session (DBIx-Squirrel
5a9a38d44b2ba52b4c0ac8a2ad9bc15ba15dde62): "We are no longer JUST
accepting code-references."

**Started:** 2026-11-09, in 2e334e84c4b79cc71a8f257602b62850e2693f5c

**Finished:** 2026-11-09

## Background

2026-0004 let a pipeline be a stage, and 2026-0007 let a `gather`
block return one, but both left their messages as they were
(2026-0004's D3, 2026-0007's D2), as a change to a message makes
v0.2.0 under CLAUDE.md. So the refusal of a bad stage still says
"Expected stage #%d to be a code reference", and a bad `gather` block
"Expected stage #%s, made with gather, to return one or two code
references", and the docs explain the old wording away.

## Decisions

- [x] **D1.** How does the refusal of a bad stage read? Settled on
  2026-11-09: "Expected stage #%d to be a code reference or a
  pipeline", as Iain asked that it say so, and as DBIx-Squirrel's own
  message reads: "Expected only code references or pipelines after the
  statement for %s".
- [x] **D2.** How does the message for a bad `gather` block read?
  Settled the same day, on the same instruction: "Expected stage #%s,
  made with gather, to return a code reference or a pipeline, and
  optionally an end function". It names the stage as D1 does, and says
  what the end function is, which "one or two code references" left
  the reader to work out.

## The plan

**What:** the two messages, as D1 and D2 say, and everything that
quotes or explains them. A sweep of `lib`, `t`, `docs` and the README
at 46d9fcba9baf444f33f3134e708cdc23064e762c found 24 places, as below.
"Expected a code reference" stays: it's raised for blocks and sources
that aren't stages.

**Steps:**

1. `lib/Ekorn/Pipeline.pm`: the two `croakf` calls in `new`, and the
   one in `_make_run`; its DIAGNOSTICS entries for both.
2. `lib/Ekorn/Pipeline/Gather.pm`: its DIAGNOSTICS entry, and the note
   that the message predates pipelines as stages, which goes.
   `lib/Ekorn/Pipeline/Errors.pm`: the `croakf` example.
3. The tests that expect either message: `t/02-pipeline.t`,
   `t/03-gather.t`, `t/04-pipes.t`, `t/10-pipeline-as-stage.t` and
   `t/11-gather-pipeline.t`, and the names of tests that say "not a
   code reference" of a stage.
4. The reference: `new`, the `gather` section and its note, When a
   stage dies, and Diagnostics. The how-to: the example of a mistake
   in making a pipeline, and the sentence on stages that aren't code
   references. The README's Errors section. Then the manuals and
   `README.md`.
5. `Changes`, under Unreleased, for v0.2.0, saying the messages
   changed.
6. A task in DBIx-Squirrel's `TODO.md`, as CLAUDE.md's rule for v0.2.0
   says: test against `develop`, change its copies of the two messages,
   and move its range to `>= v0.2.0, < v0.3.0` once v0.2.0 is on CPAN.

**Done when:** no message, DIAGNOSTICS entry, comment or passage says
a stage must be a code reference; the tests pass with the new wording
on every Perl and under `prove`; coverage holds; the changed examples
print what they say; and DBIx-Squirrel has its task.

## What happened

- **Outcome:** done as planned. Both messages read as D1 and D2 say,
  in the code, both modules' DIAGNOSTICS, the `croakf` example, the
  reference, the how-to, the README and the tests; the notes explaining
  the old wording are gone. A sweep after the change finds "isn't a
  code reference" only where a code reference is what's meant: an
  iterator's source, and what an overridden `stages` method returns.
  The tests pass on 5.36.3 to 5.44.0 and under `prove`; coverage holds;
  the how-to's examples print what they did, but for the new message.
- **Changes from the plan:** the sweep's 24 places missed two, found
  by searching across line breaks: the README's Errors section and the
  reference's When a stage dies. Both now say "neither a code reference
  nor a pipeline". The reference's Diagnostics, and the POD's, still
  said an exception object is "thrown on as it is", left from before
  2026-0006's pass; both say it plainly now.
- **What's left:** DBIx-Squirrel's task, to test against `develop` and
  change its copies of the messages, and v0.2.0 itself.

