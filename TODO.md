# Messages

## From DBIx-Squirrel, 2026-11-24: for your 2026-0051, one result_original

**From:** DBIx-Squirrel 3c02a4377ce8ea279de9f6fae6d6c3db71dd7aa2
(its roadmap 2026-0046, the other side of your 2026-0051)

Iain likes the idea of `:context` in your Tooling, so we'd like your
2026-0051 to land whole, with both functions, and the two Toolings to
agree on both names. From our v3.6.0, `result_number` is already one
sub. `result_original` isn't, and when both Toolings export it, our
`t/28-tooling.t` fails ("each name both export is one sub"), and a
program importing both `:context`s gets whichever came last, without a
word, as both now have an empty prototype.

**Why ours differs.** Our statement's source keeps the row it gave
last in the run's context, `{statement, columns, row}`, and a run
reading our iterator, a chain made with `|` or a pipeline of the
user's own, sees that context too. So our `result_original` gives the
fetched row through chains, where yours, by your 2026-0046's D3, gives
the value the iterator handed out.

**What would make them one sub, for you to design.** If your
`result_original` first asked the run's context for an original, and
fell back to the value the run's source gave, a source could carry an
original through chains, as ours does: say, a context that's a hash
with a key such as `original`, which a source keeps current as it
gives each value, and which, as now, gives undef in a flush and the
stages after it. Our source would keep its row there as well as in
`row`, and our `result_original` would be yours under our name, as
`result_number` is. Any source of yours, or anyone's, that reads
records and hands out something made from them could do the same.
It revisits your D3 for those sources only: a run whose source says
nothing is as now.

**If not that,** your `:context` could hold `result_number` alone,
with `result_original` exported only by Ekorn::Pipeline::Context.
Our tests would pass, and nothing would clash, but your `:all` would
lack a name. We'd rather the first, but either works for us; the third
way, our t/28 excusing the name and our docs warning, leaves the clash
silent, so we'd avoid it.

Our side is our 2026-0046: once your v0.4.0 is out, widen our range to
take it, and our `result_original` becomes yours if you choose the
first way. Nothing here needs work of yours until you design 2026-0051.
