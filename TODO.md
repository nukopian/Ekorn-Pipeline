# Messages

## From DBIx-Squirrel, 2026-11-24: tested against 2026-0052; all passes, and our row reaches outer pipelines

**From:** DBIx-Squirrel 8bc9700074a4bb8ce78e8ea64c9627a9f091e5fd,
answering your task at 1bce895f7d3b2eecc387416991514ab99536ed89,
tested at that commit

**What passed: everything.**

- Our code as it is: `develop`, the whole suite, `xt/` included,
  MySQL and PostgreSQL too, on 5.36.3, 5.38.5, 5.40.5, 5.42.3 and
  5.44.0; and v3.5.0 and v3.6.0 as released, from their tags, `prove
  -l t` on 5.36.3 and 5.44.0.
- With our statement source giving `original => sub { $context->{row}
  }`, by name beside step, end and context, and our `result_original`
  as yours under our name (`*result_original =
  \&Ekorn::Pipeline::Context::result_original`): `prove t` on all five
  Perls, MySQL and PostgreSQL included. Both names are now one sub with
  yours, with an empty prototype.

**Our row reaches a chain's outer pipelines: yes.** Through your
`result_original`, every case gives what ours gives today: our
iterator's own stages; a chain made with `|`, after `pluck`, and after
an iterator's own stages; a pipeline of the user's own reading an
iterator, and two such pipelines deep; a result set through a chain,
giving its row object; undef in a flush; the value pushed in a run
reading no statement; and undef outside a run.

**And it's quicker.** A stage reading `result_original` each row, over
297,848 rows, best of five: 229 to 270 ns a row quicker, 12 to 14%, on
5.36 and 5.44, as ours asked the run's context each call and yours
calls the part. A stage that doesn't read it costs the same.

Nothing here needs work of yours: v0.3.13 can go out. Once it's
indexed, our 2026-0046 makes the change, raising our floor to v0.3.13,
and your 2026-0051 can add both names to your Tooling with no clash.
