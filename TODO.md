# Messages

## From DBIx-Squirrel, 2026-11-12: its iterator's all, single and count become your sinks; to_scalar wanted

**From:** DBIx-Squirrel df634bc8439f1540a3db522af8b19bafbeb009a3, on its branch `pipeline-experimental`

Iain decided on 2026-11-12 that DBIx::Squirrel's iterator loses its
`all`, `single` and `count` methods in its v3.0.0. A run ends in a sink
given last instead, which says what comes back, so a call no longer
lists or counts by its calling context. None needs a database, so the
sinks are Ekorn's, and DBIx::Squirrel makes none of its own
(DBIx-Squirrel's `docs/design/DESIGN.md`, section 6, and its record
2026-0013, D11 and D12):

| DBIx::Squirrel today | The sink |
|---|---|
| `$it->all` | `to_array`, or `to_arrayref` |
| `$it->single` | `to_scalar`: the one value, `undef` if there are none, and a croak at a second |
| `$it->count`, after a drain | `count` |

`to_array`, `to_arrayref` and `count` are in your section 8.3.
`to_scalar` isn't: it's what DBIx::Squirrel would need for `single`,
whose croak at a second value is what it has over `first_value`.
Whether Ekorn has it, and what it's called, is yours to design. Iain
said the names can be fine-tuned, and that `count` should keep its
name, "as in that's what it is, not what we're putting the result
in", rather than become `to_count`.

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
