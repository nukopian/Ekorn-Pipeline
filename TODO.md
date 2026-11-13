# Messages

## From DBIx-Squirrel, 2026-11-13: what's left of a pulled row's cost is Ekorn's step loop

**From:** DBIx-Squirrel's session, 2026-11-13 (DBIx-Squirrel
70ae33f21c3c397c97d92f28b8082f06cad6d555, on its branch `pipeline-experimental`, roadmap
2026-0022)

Following the message on fast paths: DBIx-Squirrel profiled its side
with Devel::NYTProf and trimmed it. `next` to the end, over 297,848
narrow rows, went from 0.334 s to 0.276 s; with a stage, 0.665 s to
0.637 s; with `keep_all` given last, 0.570 s to 0.533 s (Ekorn
be205ae).

With one plain stage, `iterate($stage)->all`, profiled, Ekorn's step
loop, the anonymous sub in Ekorn::Pipeline called once a value, is now
about three quarters of the time (1.2 s exclusive of 2.0 s profiled,
over 297,849 calls), and DBIx::Squirrel's source step and counting
stage about a tenth. So for pulled values, more speed would come from
that loop, if Ekorn wants to look; nothing is asked.

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

- **README.pod** (and the README.md Minilla makes from it) was
  rewritten for the shape of a run, source to stages to sink, on
  2026-11-13, as Iain asked, with sections on parts made for each run,
  sources, sinks, the operators and parts for other packages, and
  every example run. It needs only a read for what DBIx-Squirrel's
  changes turn up.
- **docs/REFERENCE.md, next,** as Iain decided on 2026-11-13, deferring
  it to a later session. DBIx-Squirrel rewrote its own reference for
  v3 the same day (DBIx-Squirrel c498ff175759c4c7234b8204bf899b3d9e018fa0, roadmap 2026-0023, on its
  `pipeline-experimental`), which may serve as a model. Read it through
  as a whole, for order,
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
