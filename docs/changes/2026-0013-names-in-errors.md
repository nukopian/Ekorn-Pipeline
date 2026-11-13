# 2026-0013. A named pipeline named in a stage's error

**Status:** shipped, unreleased

**Decisions:** D1 settled: the place, then the innermost named pipeline and the place in it. D2 settled: the name qualified. D3 settled: a pipeline's first name.

**Origin:** a message from DBIx-Squirrel's session, 2026-11-10
(DBIx-Squirrel 60dd1af8f11b7661b4e47decadf9885d3e22a2d3), its point 6;
joined v0.3.0 by 2026-0022's D40

**Depends on:** 2026-0021, shipped unreleased

**Started:** 2026-11-13

**Finished:** 2026-11-13

## Background

A stage that dies is named by its place, `#2.3`, the third stage of a
pipeline given as the second. Inside a named pipeline, the place says
nothing of which pipeline, and `pipeline('clean')` makes a pipeline
with `clean` as its first stage, so its second is `#1.2`. DBIx-Squirrel
asked that the pipeline be named too. 2026-0011's D3 left `name` free
for a getter that could give it. It changes a message, so it joins
v0.3.0 (2026-0022's D40).

## Decisions

- [x] **D1.** How is the stage named? Its place, as now, then, in
  brackets, the innermost named pipeline it's in and its place there:
  `Pipeline stage #1.2 (main::clean#2) failed at ...`. Iain decided on
  2026-11-13, as recommended: code matching the place still finds it,
  and the name says which pipeline. Weighed and set aside: the name in
  place of the place, `clean#2`; and 2026-0011's D3 wording, `#2 of
  clean`.
- [x] **D2.** Is the name qualified? Yes, `main::clean`, as "No
  pipeline named main::clean" is, so two packages' `clean`s differ.
  Iain decided on 2026-11-13, as recommended.
- [x] **D3.** A pipeline named twice gives which name? The first, which
  `name` returns, qualified, or `undef` for a pipeline with none. Iain
  decided on 2026-11-13, as recommended.

## The plan

As the roadmap gave it, with the decisions above:

> When a stage in a named pipeline dies, the message gives the
> pipeline's name with its place, such as `clean#2.3`, through a
> `name` getter left free by 2026-0011's D3. It changes a message, so
> it joins v0.3.0 (2026-0022's D40), with DBIx-Squirrel's tests and
> copies of the message told.

Steps: a `name` getter; each stage keeps the pipelines it came from,
with its place in each, the pipeline run among them, so a message
finds the innermost named one as the stage dies; the stage's and the
end's messages name it; tests; the POD, reference and how-to; Changes;
DBIx-Squirrel told.

## What happened

**Shipped, 2026-11-13,** on `pipeline-experimental`, for v0.3.0
(2026-0025), as planned.

- **How:** each stage keeps, beside its place, the pipelines it came
  from, each with its place within it, a gather's pipeline among them;
  and a run knows the pipeline it's of, held weakly by the closure a
  pipeline is called as, so the pipeline is still freed when let go.
  As a stage or an end dies, the innermost of these with a name names
  it. The name is read then, so a pipeline named after it was given as
  a stage is named too.
- **Found on the way:** the roadmap's example, `clean#2.3`, would have
  read the place as within `clean`; under D1 the place stays the run's,
  and the place within `clean` follows it.
- **Tests:** `t/13` tests the getter, a named pipeline spliced, nested,
  returned by a gather, and run itself, an end, a name given later, and
  that a pipeline is freed when let go. Ekorn::Pipeline is covered in
  full.
- **Docs:** the POD's `name` and DIAGNOSTICS; the reference's `name`,
  When a stage dies, and its Diagnostics; and the how-to's Find the
  stage that failed, with an example, which was run.
- **DBIx-Squirrel:** its copies of the message are all of unnamed
  pipelines, which don't change, and it names none, so it's told by a
  message, not a task.
