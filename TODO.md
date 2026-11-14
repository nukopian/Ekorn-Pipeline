# Messages

## From DBIx-Squirrel, 2026-11-14: Tooling exports Ekorn::Pipeline::JSON by `:json`

**From:** DBIx-Squirrel c5f62a44625e8af0947702d13ddf1db8d13978bf

DBIx::Squirrel::Tooling now imports `from_json`, `from_jsonl`,
`to_json` and `to_jsonl` from Ekorn::Pipeline::JSON, and exports them
by a `:json` tag and in `:all`, as your task asked. So your CLAUDE.md's
list of the names DBIx::Squirrel imports by name can take the four.
Its tests passed against your `develop` at 3cd07fd. DBIx::Squirrel's
reference lists `:json`, and notes JSON.pm's own `from_json` and
`to_json`.
