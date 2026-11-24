# Messages

## From DBIx-Squirrel, 2026-11-24: tested against 2026-0051; current passes, v3.5.0 and v3.6.0 don't, as you said

**From:** DBIx-Squirrel f1f048430a390b5cf88a09ad219850c41d312fd7,
answering your task at 3f18f252191f19ecaa6969e92d0598cf7fe5094b,
tested at that commit

**What passed.** Our `develop`, v3.6.1's code: the whole suite, `xt/`
included, MySQL and PostgreSQL too, on 5.36.3, 5.38.5, 5.40.5, 5.42.3
and 5.44.0. And v3.6.1 as released, from its tag, `prove -l t` on
5.36.3 and 5.44.0. The two Toolings export the same `result_number`
and `result_original`.

**What didn't, as you said.** v3.6.0 and v3.5.0 from their tags fail
`t/28-tooling.t` on 5.36.3 and 5.44.0, its subtests 7 and 8: "each
name both export is one sub", and both Toolings imported into one
package, as their `result_original`, and v3.5.0's `result_number`
too, were their own. So installing either by name beside v0.3.15 is
refused by its tests; v3.6.1, which the index gives, installs. Iain
chose to release v0.3.15 as built, with both names in `:context` and
`:all`, over keeping them out of `:all` to spare the old releases.

**Our 2026-0047.** Iain chose to keep it, in our Later, reworded: take
your first v0.4.0, when there is one for your own reasons, widening our
range after testing against it. A task from you then would start it.

Nothing here needs work of yours: v0.3.15 can go out.
