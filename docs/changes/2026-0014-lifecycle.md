# 2026-0014. The lifecycle: sources, stages, sinks and their ends

**Status:** in progress

**Decisions:** None of its own: the design's (2026-0022, D1 to D70)
settle it.

**Origin:** roadmap, added 2026-11-10, from DBIx-Squirrel's message
(DBIx-Squirrel 7cf473408d73add0eda3eae5ca3e0be6afaaf122), rewritten
from the design approved on 2026-11-13 (2026-0022)

**Started:** 2026-11-13

## Background

The design (`docs/design/`, 2026-0022) settles the lifecycle, and its
prototype, on `pipeline-experimental`, builds it, with the proofs of
its section 19 in `t/15-proofs.t`. What's left is to finish it: the
new modules' POD is a placeholder, coverage is below the floors, and
the published reference and how-to don't yet describe it.

## Decisions

None of its own. A question found in the work is added here.

## The plan

As the roadmap gave it on 2026-11-13:

> The core of the design approved on 2026-11-13 (2026-0022), finished
> from its prototype on `pipeline-experimental`: a run made of a
> source, stages and sinks, each made for the run by its role method
> (`ekorn_source`, `ekorn_stage`, `ekorn_sink_one`, `ekorn_sink_many`),
> with a flush and an end told how the run ended, `done`, `stopped` or
> `died`; Ekorn's types as Elements; and the Iterator, with `ended`,
> `finish`, `all`, `first` and `single`. Done when its code has its
> POD, its tests hold the design's proofs (section 19) and keep
> coverage above the floors, and the reference and how-to take in its
> share of the drafts, with `Changes`.

Steps: the POD of Ekorn::Pipeline's run, Element, Source, Stage,
Sink and Iterator, from the draft reference; tests for what coverage
shows missed; the reference's and how-to's sections on runs, ends and
iterators, from the drafts; `Changes`, its line ending "(roadmap
2026-0014)".

## What happened

Nothing yet.
