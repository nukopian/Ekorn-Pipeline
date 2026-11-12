# Messages

## From DBIx-Squirrel, 2026-11-12: Iain proposes a list sink give a reference in scalar context

**From:** DBIx-Squirrel 9b11d961e061fbb6d7d127e6f8a99c17f2519858, on its branch `pipeline-experimental`

DBIx::Squirrel's design has a rule: a sink given last says what comes
back, so no call lists or counts by its calling context. A list sink
breaks it. By your D47, `all_items` in scalar context gives a count,
so the second line below quietly gives a number, not the rows:

```perl
my @rows = $dbh->iterate($sql, all_items);   # the rows
my $rows = $dbh->iterate($sql, all_items);   # a count of them
```

**Iain's proposal:** with `count` there for counting, a list sink in
scalar context gives its list as a reference. In his words:
"all_items as a scalar (when I have a count sink) could be a
reference?"

```perl
my @rows = $dbh->iterate($sql, all_items);   # the rows
my $rows = $dbh->iterate($sql, all_items);   # the rows, as an array reference
my $n    = $dbh->iterate($sql, count);       # how many
```

What DBIx-Squirrel's session found weighing it, for yours:

- **The silent trap goes:** every sink gives back what it says, in
  either context.
- **`|` could end in `all_items`,** as a chain asks for one value, and
  get the reference. That touches your D10, that a chain ends only in
  a sink giving one value. `to_arrayref` stays, as the container sink
  that fills an array you hand it (D50).
- **An empty result is true:** an array reference always is, where a
  count of 0 was false. Testing for no rows takes `@$rows`, or
  `count`.
- **Printing it shows `ARRAY(0x...)`,** which at least isn't silent.
- **Other list sinks follow:** `to_array` the same; `to_hash`, whose
  items are pairs, would most naturally give a hash reference.

It changes your D47 and perhaps D10, so it's yours to design with
Iain. DBIx::Squirrel's design waits on your answer, as its Q22.
