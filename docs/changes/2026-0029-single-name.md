# 2026-0029. A single name gives the pipeline it names

**Status:** in progress

**Decisions:** D1 settled: one name alone gives the pipeline named. D2 settled: only if it's of the invocant's class, or a subclass; otherwise wrapped, as now. None open.

**Origin:** a message from DBIx-Squirrel's session, 2026-11-13
(DBIx-Squirrel a3708534c87955d69d67887256503ad951957bbb, on its branch
`pipeline-experimental`)

**Started:** 2026-11-13

## Background

DBIx::Squirrel::Sugar takes pipelines' names in a statement's
definition, resolving each alone with `pipeline_in($package, $name)`,
so the other stages keep their places. `pipeline_in` always makes a
new pipeline, so the named one is a pipeline within a pipeline, and a
stage of it given as a definition's second stage is reported as
"Pipeline stage #2.1.2 (main::fussy#2)", a level deeper than the
definition shows. `pipeline('fussy')` given as a stage does the same.
DBIx-Squirrel suggested that `pipeline_in`, given a single name and
nothing else, give the named pipeline itself.

It changes how stages are numbered in errors, which DBIx-Squirrel's
tests, and anyone's, may match, so it's done before v0.3.0, as a
change of v0.3.0's.

## Decisions

- [x] **D1.** Given one name and nothing else, does `pipeline_in`
  return the named pipeline itself? **Yes,** Iain decided on
  2026-11-13. So `pipeline('clean')` is the pipeline named `clean`, the
  same object each time, and a stage of it spliced in second is
  `#2.2 (main::clean#2)`. The catch, accepted: `->named('other')` on
  what it gives names the shared pipeline.
- [x] **D2.** If the pipeline named isn't of the invocant's class, as
  with `My::Pipeline->pipeline_in($package, 'clean')` for a plain
  Ekorn::Pipeline? **Return it itself only if it's of the invocant's
  class or a subclass; otherwise wrap it in a new pipeline of the
  invocant's class, as now,** Iain decided on 2026-11-13, so
  `pipeline_in` keeps its promise to make its invocant's class.

## The plan

- In `pipeline_in`, given exactly one stage that's a name, look it up,
  and return the pipeline found if it `isa` the invocant's class;
  anything else goes on as now.
- Tests in `t/13-pipeline-function.t`: the same object for one name; a
  new one for a name with stages, or for a name of another class; and
  the numbers in errors, `#2.2`, where `#2.1.2` was, changing the tests
  that expected a level more.
- The reference's `pipeline_in`, `pipeline` and Named pipelines, the
  POD, the guide's "Name a pipeline" recipe, if it says otherwise, and
  `Changes`, marked "Changed", as numbers in messages change.
- DBIx-Squirrel told, by a task, as its tests expect `#2.1.2`.

Done when one name alone gives the pipeline named, as D1 and D2 say,
with tests, docs and `Changes`, and DBIx-Squirrel has its task.

## What happened

Nothing yet.
