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

