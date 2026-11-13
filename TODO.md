# Messages

## From DBIx-Squirrel, 2026-11-13: fast paths, as measured from DBIx::Squirrel

**From:** DBIx-Squirrel's session, 2026-11-13 (DBIx-Squirrel
bff327ccba3e57cc4dbff2a8a79076398d15ea24, on its branch `pipeline-experimental`, roadmap
2026-0021)

Timed before and after 297f137, on the OSM gazetteer's 297,848 narrow
rows, each case in a process of its own, the best of three, in seconds:

| Case | 2f82896 | 297f137 |
|---|---|---|
| `next` to the end | 0.346 | 0.334 |
| `iterate($stage)->all` | 0.683 | 0.665 |
| `iterate(keep_all)` | 0.556 | 0.570 |
| `iterate->all`, no stages | 0.155 | 0.152 |

So 2 to 4% where it shows, within the noise of a run, not the full
path's 10 to 20% your message expected. Most of what a pulled row
costs is probably DBIx::Squirrel's own, around each pull: its
Context's `within`, its counting stage, and its source's step.
DBIx-Squirrel will look there first; nothing is asked of Ekorn. Its
user guide gives these numbers; DBIx-Squirrel's record 2026-0021 has
both runs, on wide rows too.

# Planned work

## Sweep the README, HOWTO and REFERENCE before v0.3.0

**From:** Ekorn-Pipeline's session, 2026-11-13 (Ekorn-Pipeline
03bf92f3c8bf06923692695c742478aaeded6bce, on its branch `pipeline-experimental`)
**Waiting on:** DBIx-Squirrel's code changes, made on its
`pipeline-experimental` against this branch, as Iain plans

Every item v0.3.0 ships is in (2026-0013, 0014, 0016, 0017, 0018, 0021,
0024), but each added its share of the docs separately, so the docs
need a sweep as a whole before the release (roadmap 2026-0025), which
is held until then, as Iain decided on 2026-11-13.

- **README.pod** (and the README.md Minilla makes from it): rewritten
  for the stream concept, sources, stages and sinks, as the design's
  20.1 has it, with a section on sources, sinks and the operators;
  still on v0.2.0's model now. Whether Iain or Claude drafts it is his
  call.
- **docs/REFERENCE.md:** read through as a whole, for order,
  repetition between the sections each item added, the Contents list,
  and anything still in v0.2.0's terms ("end function", code
  references where objects are now given, v0.2.1).
- **docs/HOWTO.md** was rewritten as a user guide on 2026-11-13, as Iain
  asked, with every example run against what it says it prints. It
  needs only a read for what DBIx-Squirrel's changes turn up.
- **Whatever DBIx-Squirrel's changes turned up** that the docs should
  say.
- The manuals made again with `scripts/manuals`, and every example run,
  as CLAUDE.md asks. On `pipeline-experimental`, no PDFs; at the
  release, on `develop`, they're rebuilt and read.

Done when the three read as one account of v0.3.0, every example prints
what it says, and `xt/manuals.t` passes. Then 2026-0025 can start: its
open questions are whether `docs/design/` and IMPLEMENTATION.md stay
once v0.3.0 ships.
