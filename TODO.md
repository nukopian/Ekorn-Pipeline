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
