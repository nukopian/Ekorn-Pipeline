# 2026-0027. The role methods in capitals

**Status:** shipped, unreleased

**Decisions:** D1 settled: all capitals, `EKORN_SOURCE` and the rest. D2 settled: records keep their names; `docs/design/` is renamed, but for its history of the names. None open.

**Origin:** roadmap, added 2026-11-13, from Iain: "Do you think the
protocol hooks should be UPPERCASE in Perl?"

**Started:** 2026-11-13

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
- [x] **D2.** What happens to the old names in `docs/design/` and in
  the records of shipped items? The records are history, and a
  record's plan isn't edited after work starts, so they keep the names
  they used. `docs/design/` is the design as decided, whose future
  2026-0025 settles; it could be renamed throughout, to stay a true
  account, or keep its names with a note at its top. **Records
  unchanged; `docs/design/` renamed throughout,** Iain agreed on
  2026-11-13, as it's still read as the design until 2026-0025 decides
  whether it stays.

## The plan

- Rename `ekorn_source`, `ekorn_stage`, `ekorn_sink_one` and
  `ekorn_sink_many` as `EKORN_SOURCE`, `EKORN_STAGE`, `EKORN_SINK_ONE`
  and `EKORN_SINK_MANY`, as whole words, wherever they're the current
  names: `lib/`, `t/`, the reference, the how-to, `Changes`' Unreleased
  entries and `docs/design/`. The manuals are made again from the
  Markdown.
- Leave the records in `docs/changes/` as they are (D2), and the
  design's history of the names, its 17.24 and 17.34, which say what
  was decided then; each gains a line saying this item has since put
  them in capitals. The earlier names those sections give,
  `ekorn_sink`, `ekorn_sink_scalar` and `ekorn_part`, stay.
- No aliases for the old names: no release had them.
- Check: tests, perlcritic, perltidy, coverage, and the examples that
  define a role method run.

Done when, as the roadmap has it: the run, `is_stage`, `is_sink`, the
operators and Ekorn's own parts use the new names, the old ones are
nowhere outside the records of shipped items, and the tests, POD and
docs follow, with coverage above the floors.

## What happened

Done as planned, on 2026-11-13: 249 names in 16 files, by a script
matching the four as whole words. The suite passes, coverage stays at
every floor, perlcritic and perltidy are clean, and the two examples
defining `EKORN_SOURCE`, in the reference and the how-to, were run
with a stand-in statement.

- One message changes with them, "Expected stage #%d to offer one of
  EKORN_STAGE, EKORN_SINK_ONE and EKORN_SINK_MANY, not %s". It's new
  in v0.3.0, so no released message changes.
- Outside `docs/changes/`, the old names are left only in the design's
  17.24 and 17.34, as D2 settled.
- The design's PDFs in `docs/design/` weren't made again, as none are
  on `pipeline-experimental`; they still show the old names until
  they are, if 2026-0025 keeps them.
