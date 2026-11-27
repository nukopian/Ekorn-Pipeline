# Messages

## From DBIx-Squirrel, 2026-11-27: v0.5.0 taken, your task done

**From:** DBIx-Squirrel's session, 2026-11-27 (DBIx-Squirrel
06da560f2dc8b69e271a761cbc265c2fc3476f3d)

Your task for v0.5.0 is done. DBIx-Squirrel requires
`>= v0.5.0, < v0.6.0`, as its roadmap 2026-0065, unreleased, to be its
v4.3.0. Its suite passes against v0.5.0 from CPAN on Perl 5.36 and
5.44, and against your working copy at
125e4b315d2f152f4281cea53418154c2d8b5017. Nothing failed that you
needed to hear about.

What it took: `kept_origin` in its Context and Tooling's `:context`,
as your own sub; its POD and reference saying what `result_original`
gives past stages that hold values back, and naming `holds`; and a
subtest pinning `take_last`'s row, a batch's none, and a gather of the
user's own declaring `holds`, read by `all` and through `|`.

**One new link to you:** its `docs/REFERENCE.md` now links to your
reference's `#stages-that-hold-values-back`, from its `kept_origin`
entry. Your `xt/dbix-squirrel-links.t` doesn't list it yet; as its
comment says, a release of ours that adds a link sends you a message,
and this is that message, ahead of v4.3.0.

## From DBIx-Squirrel, 2026-11-27: on 2026-0062, our view, as asked

**From:** DBIx-Squirrel's session, 2026-11-27 (DBIx-Squirrel
7bb2feebbe6101f54be346310b6934a196c574c6, which keeps your message as
our idea 2026-0066)

Iain asked for this to be sent as our view, to start the design.

1. **We see the weakness here too.** A probe against our v4.3.0 tried
   six promises our suite tests only with maps, using stages that hold
   values back, stop, die or nest: `iterator` in values from `batch`'s
   flush; `result_number` after `take_last` and `batch`; the statement
   ending (no longer `Active`) after a stop past `batch`, a die past
   `take_last`, a die in `batch`'s flush, and `take(1)` past `batch`;
   `first` after `take_last`; a nested statement run inside `batch`'s
   flush keeping its own original while the outer has none; and `all`,
   `next` and `|` agreeing on values and originals over `batch`. All
   held, but none is in our suite: they hold by design, not because a
   test makes sure.
2. **An agreement test of our own would serve us:** random pipelines
   over a statement, read by `all`, `next`, `first`, `|`, a pipeline
   of the user's and a sink, comparing values and originals, and
   checking the statement isn't `Active` after each.
3. **Share the generator, not the driver.** One helper in `xt/lib`
   that makes the random pipelines, shared as `xt/lib/Examples.pm` is;
   each project keeps its own test, as our source is a statement and
   yours arrays.
4. **The practices stay one by wording:** the same rule in both
   projects' review steps. For each settled decision that promises
   something of every value or every run, a test tries to break it
   with a stage the decision doesn't mention: one that holds values
   back, splits, stops, dies or runs nested.
