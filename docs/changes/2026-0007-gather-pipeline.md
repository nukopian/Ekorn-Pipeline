# 2026-0007. A pipeline returned by a gather block

**Status:** shipped, unreleased

**Decisions:** D1 settled: its stages are made for the run in its place. D2 settled: the message for a bad block is unchanged, so it's v0.1.3. None open.

**Origin:** roadmap, added 2026-11-09, from a full check of the docs
against the code, which found that a `gather` block's stage had to be a
code reference though `is_stage` calls a pipeline a stage. Iain asked
for it to be done at once, in v0.1.3, with DBIx-Squirrel's sign-off.

**Started:** 2026-11-09

**Finished:** 2026-11-09

## Background

Since 2026-0004, `new` takes a pipeline where a stage goes, and
`is_stage` is true for one. A `gather` block, which returns a stage and
optionally an end function, was still checked with `is_coderef`, so a
pipeline returned there was refused as "Expected stage #%s, made with
gather, to return one or two code references".

## Decisions

- [x] **D1.** What does a pipeline returned as the stage mean? Settled
  on 2026-11-09, when Iain asked for the item to be done at once, by
  following 2026-0004's D1: its stages are made for the run in its
  place, as if given there, rather than the pipeline being called once
  for each value. A `gather` stage inside it is made afresh, a stop
  inside it ends the whole run, and a stage inside it is named "#2.3".
  The block's end function, if any, goes on a stage of its own after
  the pipeline's stages, which passes values on, so it's called after
  their ends and its values go through the stages after the `gather`.
- [x] **D2.** Does the message for a bad block change? Settled the same
  day, following 2026-0004's D3 and D4: no. "to return one or two code
  references" predates pipelines as stages, but changing a message
  makes v0.2.0. The DIAGNOSTICS entries say what's accepted.

## The plan

**What:** a `gather` block can return a pipeline as its stage, as D1
says. **Steps:** the runner makes a run's stages through a function
that splices a returned pipeline's stages in, recursively; tests in
`t/11-gather-pipeline.t`; Gather's POD and DIAGNOSTICS, the
reference's `gather` section, a pointer in the how-to; `Changes`; and
DBIx-Squirrel's sign-off task to cover it. **Done when:** the tests
pass on every Perl and under `prove`, coverage holds, the examples
print what they say, and the task is updated.

## What happened

- **Outcome:** done as planned. `_iterator` builds each run's stages
  with `_make_run`, which calls each `gather` block and splices in a
  returned pipeline's stages, taken through its `stages` method as
  2026-0004 does. The tests pass on 5.36.3 to 5.44.0 and under
  `prove`; coverage holds (branch 100%, condition 97.6%); the POD's
  and the reference's new examples print what they say.
- **Changes from the plan:** none.
