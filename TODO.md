# Planned work

## 2. Make a step's many values cheap, and an iterator's `all` take them in bulk

**From:** DBIx-Squirrel's session, 2026-11-12 (DBIx-Squirrel
98d11adbe1fa1be98f56520aee8873f8539f3053, on its branch
`pipeline-experimental`)
**Waiting on:** nothing

**What:** Iain settled DBIx-Squirrel's Q30 (its 2026-0013 D28) from
its spike: of what its buffering might need of you, one thing does.
A source's step may give "the next value or values", but each value
it gives costs as much as one given alone: the run wraps each in an
entry of its own on `@todo` (`lib/Ekorn/Pipeline.pm` line 544, `push
@todo, map { [0, $_] } reverse @values`), and an iterator's `all`
collects them a call at a time (`lib/Ekorn/Pipeline/Iterator.pm`,
`all`). So DBIx::Squirrel's `$it->all`, whose source gives every row
left in one step, gained little from it.

Timed on Iain's OSM gazetteer, 297,848 narrow rows, in seconds, each
case in its own process (DBIx-Squirrel's record 2026-0013 has all of
it, and the script):

| | DBIx::Squirrel v2, its own pipeline | on Ekorn, at cbed038 |
|---|---|---|
| `selectall_arrayref`, for scale | 0.096 | 0.095 |
| `$it->all`, the source giving every row in one step | 0.108 | 0.403 |
| `next`, to the end | 0.351 | 0.542 |
| `Ekorn::Pipeline->new(keep_all)->iterator($it)->all` | | 0.807 |

**Asked for:** where nothing stands between the source and the end,
as in a run with no stages, a step's many values go to the caller
without a wrapping and a call each, and an iterator's `all` takes them
in bulk; and, as far as it can, the same where a list sink such as
`keep_all` is all that follows. How is yours to design with Iain. It
serves `$it->all`, a sink given last and `|` alike, and any source
that reads in blocks, which is why DBIx::Squirrel asks rather than
route its rows around you.

**Not asked for, but seen:** each pull through an iterator costs
enough to make DBIx::Squirrel's `next` 54% slower on narrow rows than
its own pipeline was. A profile may find something; Devel::NYTProf is
in DBIx-Squirrel's 5.36 perlbrew library.

**Done when:** a run with no stages, given a step of n values, hands
them to `all` without per-value work, shown by a test or a timing;
and a message tells DBIx-Squirrel's `pipeline-experimental` what was
done, and at which commit, so it can time its `$it->all` again.
