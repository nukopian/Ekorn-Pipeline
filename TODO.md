# Planned work

## 1. A flush followed by a stage takes time in n squared

**From:** DBIx-Squirrel's session, 2026-11-12 (DBIx-Squirrel
af0324c3f8b11eaf0fa69a479bf4177103d9b2e9, on its branch
`pipeline-experimental`)
**Waiting on:** nothing

**What:** on `pipeline-experimental`, at
cbed0387a9aa462fbecf294b9029887560a4dc8e, a flush that gives n values,
followed by any stage, takes time in n squared, pushed or pulled.
v0.2.0 is linear, so it's a regression in v0.3.0's work, and no
release has it. Found timing DBIx-Squirrel's spike, where
`$sth->iterate(keep_all, $stage)` over 100,000 rows never finished.

Measured with Ekorn alone, in seconds:

| n | `keep_all` | `keep_all`, then a stage | a gather's flush, then a stage | pushed: `keep_all`, then a stage |
|---|---|---|---|---|
| 5,000 | 0.007 | 0.407 | 0.409 | 0.411 |
| 10,000 | 0.013 | 1.633 | 1.643 | 1.631 |
| 20,000 | 0.027 | 6.463 | 6.506 | 6.474 |

v0.2.0, a gather's flush then a stage, pushed: 0.007, 0.014 and 0.028.

**Why, it seems:** each value reaching the end of the stages calls
`$end_if_ended` (`lib/Ekorn/Pipeline.pm` line 557), which scans every
value waiting, `grep { $_->[0] < @stages } @todo` (line 508); a flush
puts its n values on `@todo` at once (line 572). `grep` in boolean
context scans the whole list even after a match.
`$input_ran_out_at_stop` (line 499) scans it the same way, at a stop.
How to fix it is yours: for instance, a count kept of the values
waiting before the end, or stopping at the first match.

To reproduce:

```perl
use v5.36;
use Time::HiRes qw(time);
use Ekorn::Pipeline qw();
use Ekorn::Pipeline::Gather qw(gather);
for my $n (5_000, 10_000, 20_000) {
    my $flush = gather { my @k; (sub ($v) { push @k, $v; return }, sub () { splice @k }) };
    my $t = time;
    my @r = Ekorn::Pipeline->new($flush, sub { $_[0] })->(1 .. $n);
    printf "%6d %.3fs\n", $n, time - $t;
}
```

**Also seen, for your information, not asked for:** a source's step
giving many values pays a cost for each, as the run wraps each in its
own entry (line 544) and an iterator's `all` collects them a call at a
time. DBIx::Squirrel's `$it->all` over 297,848 narrow rows went from
0.108 s to 0.403 s, though its source gives every row in one step. Its
design's Q30 asks Iain whether to ask you for more there; a request
will follow if he decides so.

**Done when:** a test shows a flush of many values, then a stage,
taking time in proportion to n, pushed and pulled; and a message tells
DBIx-Squirrel's `pipeline-experimental` it's fixed, and at which
commit.

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
