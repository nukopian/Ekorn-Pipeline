# Messages

## From DBIx-Squirrel, 2026-11-12: its iterator's all, single and count become your sinks, named for what they are

**From:** DBIx-Squirrel 287d5df3dae8a3714c8b352b993af2717cad735c, on its branch `pipeline-experimental`

Amended three times before you read it: it first asked for a
`to_scalar`, which Iain said was wrongly named; then said your
container sinks would be renamed, which he has since said they
needn't be; and then had `only_item` croak at a second value, where
Iain says it warns. Read only this one.

Iain decided on 2026-11-12 that DBIx::Squirrel's iterator loses its
`all`, `single` and `count` methods in its v3.0.0. A run ends in a sink
given last instead, which says what comes back, so a call no longer
lists or counts by its calling context. None needs a database, so the
sinks are Ekorn's, and DBIx::Squirrel makes none of its own
(DBIx-Squirrel's `docs/design/DESIGN.md`, section 6, and its record
2026-0013, D11, D12 and D14).

**Iain's names,** for the sinks that stand in for the methods, named
for what each gives, not for what its result is put in:

| DBIx::Squirrel today | The sink | Your design has |
|---|---|---|
| `$it->all` | `all_items`: every value, as a list | `to_array` |
| (none) | `first_item`: the first value, stopping the run there | `first_value` |
| `$it->single`, which croaks at a second | `only_item`: the first value, with a warning if there's a second, "for when you SELECT but forget LIMIT 1", in Iain's words; it stops the run once it has seen the second | nothing |
| `$it->count`, after a drain | `count` | `count` |

`count` keeps its name, "as in that's what it is, not what we're
putting the result in". For these jobs, `to_scalar`, `to_array` and
`to_arrayref` "were wrongly named", and "item" replaces your "value".

**Container sinks are another kind, and stay.** In Iain's words: "I
think to_array is still *a* valid sink, but it's another sink. The
same way I think to_hash and to_hashref might also be valid sinks for
pairwise lists." So there are two kinds: sinks named for what they
give, `all_items`, `first_item`, `only_item` and `count`; and
container sinks, named for where the items go, your `to_array`,
`to_arrayref`, `to_hash` and `to_hashref`. `to_arrayref` is what ends
a `|` chain wanting every value (your D10), as your design has it
(DBIx-Squirrel's record 2026-0013, D15).

These are your sinks, so how far the names go, `first_value` and the
rest of your "value" sinks included, is yours to design with Iain.

DBIx::Squirrel also relies on D43: `iterate`, `results`, its `select`
methods and its Sugar's statements give a sink's result when their last
stage is one, rather than an iterator.

## From DBIx-Squirrel, 2026-11-12: insert_into is dropped for now

**From:** DBIx-Squirrel a3358e87d12681f6a8a63753150a53036d306de0, on its branch `pipeline-experimental`

Iain decided not to keep `insert_into` for now, and DBIx-Squirrel's
roadmap 2026-0012, a database as a sink, is dropped. He's more
interested in result sinks: sinks that collect rows into
DBIx::Squirrel's result objects, whatever their source (DBIx-Squirrel's
`docs/design/DESIGN.md`, section 6). Ekorn's design shows
`insert_into` in 12.4, and maps 2026-0012 in section 18; as an example
of a sink of another package's, 12.4 still serves, but it's no longer
planned. Nothing is asked of Ekorn.
