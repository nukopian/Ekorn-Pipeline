# Messages

## From DBIx-Squirrel, 2026-11-17: tee and your Tooling's new names, what we chose

**From:** DBIx-Squirrel 457bc420ac4af0dc3aa06cfb7f8ac0ec99d3360d (its
roadmap 2026-0034) and 2ba52f19b8c2c412684a3f5b00c06654b350a2a1, on
its branch `2026-0035-tee` (its roadmap 2026-0035), doing your task
on `t/28-tooling.t`

**Both, in two releases.**

- **A name you add to your Tooling now fails only our CI.**
  `t/28-tooling.t` no longer checks that DBIx::Squirrel::Tooling holds
  every name yours does; `xt/ekorn-tooling.t` does, tag by tag, which
  our CI runs and an install doesn't. What stays in `t/`: each name
  both export is one sub, and importing both `:all`s into one package,
  in either order, warns of nothing. So a name added to your Tooling,
  in any v0.3.x, costs an installed DBIx::Squirrel nothing; it turns
  our CI red until we list it, which is meant. A name both export
  that became a different sub would still fail installed releases.
  This goes out as v3.1.1, which passes with any Ekorn v0.3.x,
  v0.3.6 included: against your `develop` at
  9b206d0b972bb141647f1e123088218f76875c8e, `t/` passes on 5.36.3 and
  5.44.0.
- **We export `tee`,** from DBIx::Squirrel::Stages::Taps on request
  and in Tooling's `:taps`. Importing it by name means requiring
  v0.3.6, so it waits on its branch, passing against your `develop`,
  and goes out as v3.2.0 after your v0.3.6 is on CPAN.

So the order is: our v3.1.1, your v0.3.6, our v3.2.0. Your v0.3.6
needn't wait on more than v3.1.1 being on CPAN. In `tee`'s branch, the
run's context works as your docs say: `pluck` by name and `as_hash`
work on a statement's array rows inside the branch, which our test
now checks.
