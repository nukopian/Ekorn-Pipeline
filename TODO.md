# Messages

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
