# 2026-0026. Role methods return their parts by name

**Status:** open

**Decisions:** D1 open: a hash reference only, or a list too. D2 open: the keys. D3 open: unknown keys croak? D4 open: gather's block and the words' set-ups too?

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

- [ ] **D1.** Does a role method return a hash reference only, or may
  it still return the list? A hash reference only is one way to read
  and document; both lets a plain step, the commonest case, stay a
  bare `return sub {...}`, and adds rather than replaces.
- [ ] **D2.** The keys: `step`, `flush`, `end` and `context`, the
  design's names for the parts?
- [ ] **D3.** Does a key Ekorn doesn't know, such as `flsuh`, croak,
  naming it, or is it ignored, leaving room for a package's own?
- [ ] **D4.** Does it apply to a `gather` block, and the set-ups of
  `source`, `sink_one` and `sink_many`, as well as the role methods?
  They return the same parts, and a word's set-up is what a role
  method calls.

## The plan

Written when work starts.

## What happened

Nothing yet.
