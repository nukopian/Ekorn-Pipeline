# 2026-0026. Role methods return their parts by name

**Status:** open

**Decisions:** D1 settled: a hash reference as an alternative to the list. D2 settled: `step`, `flush`, `end` and `context`. D3 settled: unknown keys ignored, but the hash must hold what its role needs, or it croaks. D4 settled: everywhere parts are returned, for consistency. None open.

**Origin:** roadmap, added 2026-11-13, from Iain, reading the sink
protocols: "the three items we return need to be in a set order"

**Started:** not yet

## Background

Each role method returns its parts as a list, in a set order, and so
does each set-up made with a word:

| Role method | Returns, in order |
|---|---|
| `ekorn_source` | step, end, context |
| `ekorn_stage`, and a `gather` block | step, flush, end |
| `ekorn_sink_one`, `ekorn_sink_many` | step, flush, end |

A reader has to know the order, an optional part before one that's
given takes an `undef` (a source's end, for a context; a gather's
flush, for an end), and a list in the wrong order can pass the checks
and misbehave. A hash reference, `{step => ..., flush => ..., end =>
...}`, names each part.

The role methods are Ekorn's contract with other packages, so a change
to them after v0.3.0 is a v0.4.0. Iain decided on 2026-11-13 that it's
done before v0.3.0 is released, which is held while DBIx-Squirrel
makes its changes against `pipeline-experimental`, so its parts change
once.

## Decisions

- [x] **D1.** Does a role method return a hash reference only, or may
  it still return the list? A hash reference only is one way to read
  and document; both lets a plain step, the commonest case, stay a
  bare `return sub {...}`, and adds rather than replaces. **Both:** a
  hash reference is an alternative to the list, Iain decided on
  2026-11-13. So the change only adds, and parts already written keep
  working.
- [x] **D2.** The keys: `step`, `flush`, `end` and `context`, the
  design's names for the parts? **Yes,** Iain decided on 2026-11-13.
- [x] **D3.** Does a key Ekorn doesn't know, such as `flsuh`, croak,
  naming it, or is it ignored, leaving room for a package's own?
  **Ignored, but the hash must hold something meaningful for its role,
  or it croaks,** Iain decided on 2026-11-13: "Ignore it, or check
  there's something meaningful to handle it and croak if not." So a key
  Ekorn doesn't read is left alone, and a hash without what its role
  needs, a step, and a sink's flush, croaks with the role's message, as
  a list without them does. `{step => ..., flsuh => ...}` for a sink
  croaks, as it has no flush; for a stage, the misspelt flush is
  ignored, and the stage has none.
- [x] **D4.** Does it apply to a `gather` block, and the set-ups of
  `source`, `sink_one` and `sink_many`, as well as the role methods?
  They return the same parts, and a word's set-up is what a role
  method calls. **Yes, everywhere parts are returned,** Iain decided on
  2026-11-13: "Be consistent in the ecosystem."

## The plan

Written when work starts.

## What happened

Nothing yet.
