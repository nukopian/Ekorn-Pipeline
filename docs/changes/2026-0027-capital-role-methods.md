# 2026-0027. The role methods in capitals

**Status:** open

**Decisions:** D1 settled: all capitals, `EKORN_SOURCE` and the rest. D2 open: what happens to the names in `docs/design/` and in shipped items' records.

**Origin:** roadmap, added 2026-11-13, from Iain: "Do you think the
protocol hooks should be UPPERCASE in Perl?"

**Started:** not yet

## Background

A part says what it can be by its role methods: `ekorn_source`,
`ekorn_stage`, `ekorn_sink_one` and `ekorn_sink_many`. A run calls
them as it starts, and the docs tell users they needn't. In Perl, a
sub called by the runtime rather than its caller is named in capitals:
perlsub calls it "a loosely-held convention meaning it will be called
indirectly by the run-time system itself", as `DESTROY`, `AUTOLOAD`
and `tie`'s `FETCH` and `STORE` are. CPAN extends that to a hook one
package offers another's framework: JSON's `TO_JSON`, Storable's
`STORABLE_freeze` and `STORABLE_thaw`, CBOR::XS's `FREEZE` and
`THAW`, and Moose's `BUILD` and `DEMOLISH`.

perlsub also says names in all capitals are "reserved to the Perl
core", but loosely, and CPAN's use of them is long settled. The
`EKORN_` prefix keeps them clear of anything core could add, as
`ekorn_` keeps them clear of an object's own methods now.

The names are Ekorn's contract with other packages, so renaming them
after v0.3.0 would be a v0.4.0. No release has them: they came with
2026-0014, unreleased. So the rename is done before v0.3.0, with no
aliases for the old names, while DBIx-Squirrel, which is writing its
parts against `pipeline-experimental`, has the least to redo.

## Decisions

- [x] **D1.** All capitals, `EKORN_SOURCE`, `EKORN_STAGE`,
  `EKORN_SINK_ONE` and `EKORN_SINK_MANY`, or Storable's mixed style,
  `EKORN_source`? **All capitals,** Iain decided on 2026-11-13, as
  `TO_JSON` is: one style for the whole name reads as one word.
- [ ] **D2.** What happens to the old names in `docs/design/` and in
  the records of shipped items? The records are history, and a
  record's plan isn't edited after work starts, so they keep the names
  they used. `docs/design/` is the design as decided, whose future
  2026-0025 settles; it could be renamed throughout, to stay a true
  account, or keep its names with a note at its top. Recommendation:
  records unchanged; `docs/design/` renamed throughout, as it's still
  read as the design until 2026-0025 decides whether it stays.

## The plan

Written when work starts.

## What happened

Nothing yet.
