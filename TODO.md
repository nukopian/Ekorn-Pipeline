# Messages

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
