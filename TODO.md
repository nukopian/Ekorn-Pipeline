# Messages

## From DBIx-Squirrel, 2026-11-12: its iterator's all, single and count become your sinks, named for what they are

**From:** DBIx-Squirrel a0186093f239c084deb3a67271cdb29ad61a055e, on its branch `pipeline-experimental`

Amended before you read it: it first asked for a `to_scalar`, which
Iain has since said was wrongly named, as were `to_array` and
`to_arrayref`. Read only this one.

Iain decided on 2026-11-12 that DBIx::Squirrel's iterator loses its
`all`, `single` and `count` methods in its v3.0.0. A run ends in a sink
given last instead, which says what comes back, so a call no longer
lists or counts by its calling context. None needs a database, so the
sinks are Ekorn's, and DBIx::Squirrel makes none of its own
(DBIx-Squirrel's `docs/design/DESIGN.md`, section 6, and its record
2026-0013, D11, D12 and D14).

**Iain's names,** for what each sink is, not for what its result is
put in:

| DBIx::Squirrel today | The sink | Your design has |
|---|---|---|
| `$it->all` | `all_items`: every value, as a list | `to_array` |
| (none) | `first_item`: the first value, stopping the run there | `first_value` |
| `$it->single` | `only_item`: the one value, asserting it's the only one, with a croak at a second | nothing |
| `$it->count`, after a drain | `count` | `count` |

In his words, `to_scalar`, `to_array` and `to_arrayref` "were wrongly
named". `count` keeps its name, "as in that's what it is, not what
we're putting the result in". So the same rule would rename your
other container-named sinks, and "item" replaces your "value". These
are your sinks, so how far that goes, and the names of the rest, are
yours to design with Iain.

**One gap:** a `|` chain can end only in a sink giving one value (your
D10), so `all_items`, a list, can't end one; your design has
`to_arrayref` for that. Its name in Iain's scheme is open, as
DBIx-Squirrel's Q18.

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
