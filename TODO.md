# Messages

## From DBIx-Squirrel, 2026-11-16: closures run for each value, without a signature, and what a gather costs

**From:** DBIx-Squirrel dc9a56d47082128888d521ffcc9cb5e3ae92b893 (the
measurements, in its commit message) and
1a9586d (its rule, in its CLAUDE.md's Style and tools)

**What was decided there.** Iain asked whether the closures that
sources, stages and sinks return, which take at most one argument and
run once for each value, should give up their signatures. In
DBIx-Squirrel, they now do: such a closure reads `$_[0]` where it uses
it, not a copy, with a comment saying why, and `pluck` and `as_hash`
were changed. Other subs, and the docs' examples, keep their
signatures. He said this applies to Ekorn-Pipeline as much as to
DBIx-Squirrel; whether Ekorn takes the same rule is for this session
to settle with him.

**What was measured,** on Ekorn at ebc7ff2, best of five, ns a call
or a value:

| | 5.36.3 | 5.44.0 |
|---|---|---|
| `sub ($row) { $row->[0] }`, called alone | 74 to 77 | 73 |
| `sub { $_[0][0] }` | 55 to 57 | 55 |
| `sub { my $row = $_[0]; $row->[0] }` | 76 to 78 | 75 |
| `sub () { 1 }` | 42 to 43 | 51 |
| `sub { 1 }` | 38 | 45 |
| pushed through a pipeline, a bare stage, `sub { $_[0][1] }` | 473 to 477 | 560 to 564 |
| the same with a signature | 492 to 497 | 576 to 584 |
| the bare stage in a `gather { sub { ... } }` | 815 to 817 | 915 to 920 |
| two bare stages | 708 | 805 to 806 |

So a signature costs about 19 ns, and a copy into a `my` variable as
much again, while an empty `sub ()` costs about 6 ns over `sub`. In
Ekorn's step loop (`lib/Ekorn/Pipeline.pm`, around line 365), the
alias `$_[0]` is the loop's own `$value`, which the stage's result
replaces, so nothing upstream can be changed through it. The closures
with signatures that Ekorn ships are in `Stages/Taps.pm`,
`Stages/Flow.pm`, `JSON.pm` and `Pipeline.pm`, and its sources'
`sub ()`s in `Sources.pm` and `Factories.pm`.

**What matters more than the signature.** A stage costs about 235 ns
a value (two bare stages against one), and wrapping one in a `gather`
about 340 ns more, which is most of what `pluck` costs DBIx-Squirrel:
about 420 ns a value, of which its own work is about 80. Each step
does `local $_`, a call in list context, `my @values` and a `shift`,
for each value. Two things that might be looked at: what a `gather`
does for each value, and whether the step loop could do less where a
stage returns exactly one value. Also, 5.44 runs this loop about 18%
slower than 5.36.
