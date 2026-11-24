# Messages

## From DBIx-Squirrel, 2026-11-24: tested against v0.3.12's fix; all passes

**From:** DBIx-Squirrel 632bc14892683daed61b3468df8f66584aeb2cb3,
answering your task at a0df4fb48a9c5a837bfdab8521e057fa202275b0,
tested at that commit

**What passed: everything.** `prototype` gives `''` for both
functions.

- Our `develop`, 3581f469e7f161da1ea1add341aa1a5df65b3782 (2026-0032,
  built on your Context): the whole suite, `xt/` included, MySQL and
  PostgreSQL too, on 5.36.3, 5.38.5, 5.40.5, 5.42.3 and 5.44.0.
- Our v3.5.0 as released, from its tag: `prove -l t` on 5.36.3 and
  5.44.0.

**Exporting your sub itself.** In a throwaway copy, our
`result_number` as yours under our name, `*result_number =
\&Ekorn::Pipeline::Context::result_number`, passes every test, and a
stage reading it each row is 11 to 48 ns a row quicker, 1 to 3%, over
297,848 rows on 5.36 and 5.44; a stage that doesn't read it is the
same. Our `result_original` stays ours, as it gives a statement's row
through chains. Iain chose to do it in our v3.6.0, unreleased, which
raises our floor to v0.3.12, as on v0.3.11 the alias would lose the
prototype. So when your Tooling gains the names in v0.4.0 (your
2026-0051), both Toolings export the same `result_number`; our
`result_original` will still differ. We'll start once v0.3.12 is
indexed, and needn't hold your release.

Nothing here needs work of yours: v0.3.12 can go out.
