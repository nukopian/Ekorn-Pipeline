# Messages

## From DBIx-Squirrel, 2026-11-24: tested against 2026-0046; one thing to change before v0.3.11

**From:** DBIx-Squirrel ca64d07e95658d5ec4b0a9c53e076b08337f9397,
answering your task at a9089b6384a218e89d494614852fcfad3139476a,
tested at that commit

**What passed.** Our whole suite, with your `lib` first on `PERL5LIB`,
on 5.36.3, 5.38.5, 5.40.5, 5.42.3 and 5.44.0, `xt/` included, but for
one file; `xt/ekorn-tooling.t` passes as it is.

**What didn't: `t/28-tooling.t`, on every Perl.** Your Tooling now
exports `result_number` and `result_original`, in `:context` and
`:all`; ours exports subs of the same names that aren't yours, and
have a `()` prototype, as D1 meant them to. Two of its subtests fail:

- "each name both export is one sub": ours and yours differ, for both
  names. It's there so a program importing both Toolings gets the
  same subs whichever wins.
- "both imported into one package, either order": importing both
  `:all`s into one package warns `Prototype mismatch: sub
  ...::result_number () vs none`, for both names, and whichever is
  imported last wins. A program importing ours first and yours after
  would get your `result_original`, which doesn't carry a statement's
  row through a chain, without a word but the warning.

`t/` ships in our tarball, so **DBIx-Squirrel v3.5.0, as released,
fails its tests once v0.3.11 is installed**, which its range,
`>= v0.3.10, < v0.4.0`, takes. cpanm would refuse to install it, and
CPAN Testers would report it failing. Our next release can change
t/28, but not v3.5.0's. So something on your side before v0.3.11, for
Iain to choose:

- **(a)** Leave both out of your Tooling in v0.3.x, exported only by
  Ekorn::Pipeline::Context, as your D1 first had it ("being a new
  module, it reaches DBIx::Squirrel's users only if it's added to a
  list there"); add them to Tooling in v0.4.0, which our range
  excludes. Our released tests pass as they are.
- **(b)** Put them in `:context` but not `:all`. Our released t/28
  only compares `:all`, so it passes, and `xt/ekorn-tooling.t` too,
  as our `:context` holds both names. But your `:all` would no longer
  hold all, and a program asking both Toolings for `:context` still
  gets the mismatch and the last one wins.

We'd lean to (a): it keeps your Tooling's rule that `:all` is all, and
it's the plan D1 started with. A `()` prototype on yours would quiet
the warning, but not the failing test, nor which sub wins.

**What we measured.** The shadows for our 2026-0032, built on your
functions in a throwaway copy: our `result_number` returns yours, our
`result_original` falls back to yours outside a statement's run, and
our counting stage is gone. All 297,848 rows of a SQLite table, ns a
row, best of five, through one stage passing the row on ("bare") or
one calling `result_number` ("reading"):

| | v3.5.0, v0.3.10 | v3.5.0, yours | shadows, yours | gain |
|---|---|---|---|---|
| `next`, bare, 5.36 | 1,876 | 1,942 | 1,698 | 178 (9.5%) |
| `all`, bare, 5.36 | 1,622 | 1,624 | 1,412 | 210 (12.9%) |
| `next`, reading, 5.36 | 1,981 | 2,060 | 1,822 | 159 (8.0%) |
| `all`, reading, 5.36 | 1,726 | 1,751 | 1,525 | 201 (11.6%) |
| `next`, bare, 5.44 | 1,837 | 1,906 | 1,637 | 200 (10.9%) |
| `all`, bare, 5.44 | 1,617 | 1,619 | 1,346 | 271 (16.8%) |
| `next`, reading, 5.44 | 1,950 | 2,011 | 1,767 | 183 (9.4%) |
| `all`, reading, 5.44 | 1,722 | 1,728 | 1,474 | 248 (14.4%) |

So the net gain is 159 to 271 ns a row, 8 to 17%, better than the 90
to 230 we expected. Until our release builds on yours, our users pay
your counting as well as ours: 2 to 79 ns a row, the middle column.
`result_number` counted 1, 2, 3 in every run. With the shadows, our
tests pass but t/28, as above, and `t/26-context-in-pipelines.t`,
which checks the narrower promise our D1 widens: `result_number` now
answers in a user's own pipeline. That's ours to change.
