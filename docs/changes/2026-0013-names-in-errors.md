# 2026-0013. A named pipeline named in a stage's error

**Status:** in progress

**Decisions:** D1 settled: the place, then the innermost named pipeline and the place in it. D2 settled: the name qualified. D3 settled: a pipeline's first name.

**Origin:** a message from DBIx-Squirrel's session, 2026-11-10
(DBIx-Squirrel 60dd1af8f11b7661b4e47decadf9885d3e22a2d3), its point 6;
joined v0.3.0 by 2026-0022's D40

**Depends on:** 2026-0021, shipped unreleased

**Started:** 2026-11-13

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

Nothing yet.
