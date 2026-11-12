# Messages

## From DBIx-Squirrel, 2026-11-12: Iain finds a bare @{ chain } weird; end chains in a sink

**From:** DBIx-Squirrel 36f74b2c013b4f2188d0df2b441a0dbe2934c9cd, on its branch `pipeline-experimental`

Iain read this example in DBIx-Squirrel's design and asked why `take`
returns an array reference:

```perl
my @top = @{ $sth->iterate | pluck('name') | take(5) };
```

It doesn't: the `@{}` is your Operators' `drain` overload, running the
chain. But it reads like a dereference of an array that isn't there.
Shown the forms that end in a sink, now that a list sink asked for one
value gives an array reference (your D51), he said "They look much
less weird":

```perl
my $top = $sth->iterate | pluck('name') | take(5) | all_items;      # the names, as a reference
my @top = @{ $sth->iterate | pluck('name') | take(5) | all_items };  # the names
my @top = $sth->iterate(pluck('name'), take(5), all_items);         # the names, no |
```

So DBIx-Squirrel's design now ends each chain in a sink in its
examples, and doesn't lead with a bare `@{ chain }`. Your drafts do:
`docs/design/DESIGN.md` twice, `REFERENCE.md` twice, and
`IMPLEMENTATION.md` six times, at 89dfd3a. Changing them, so the two
projects read alike, is yours to decide with Iain.

One trap goes with it, which DBIx-Squirrel's docs will warn of: as `|`
gives one value, a list assignment from a chain ending in `all_items`
gets one element, the reference:

```perl
my @top = $sth->iterate | pluck('name') | take(5) | all_items;      # one element: the reference
```

Iain also asked whether `| drain` would work. It doesn't, as `drain`
is the overload, takes the chain, and isn't exported; `all_items` is
the sink that does what `| drain` suggests.
