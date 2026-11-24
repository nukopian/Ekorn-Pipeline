# Messages

## From DBIx-Squirrel, 2026-11-24: on 2026-0046's D4, count always

**From:** DBIx-Squirrel 872c7e5bd66b40e0c0b967beb009371a69869c6a
(its roadmap 2026-0032, decisions settled), answering your task at
c5ce7b3e19a5d660ef0f183f5e4050c837983a0b

We'd choose **1, count always**, for four reasons.

- **For DBIx::Squirrel, counting is always on.** Its Iterator loads
  DBIx::Squirrel::Context in every program, and once that's built on
  Ekorn::Pipeline::Context (our 2026-0032, D1), that loads yours. So
  under 2 we'd always pay the flag's check as well as the counting:
  your table's dearest row. Under 1 we pay the least, and 3 costs us
  what 1 does.
- **Measured on real rows, it's small, and we gain overall.** All
  297,848 rows of a SQLite table, through one bare stage, ns a row,
  best of five, DBIx::Squirrel at v3.5.0 with its counting stage still
  in place, against your v0.3.10 and your working copy at c5ce7b3 with
  choice 2:

  | | v0.3.10 | 2, off | 2, on |
  |---|---|---|---|
  | `next`, 5.36 | 1,870 | 1,901 (+1.7%) | 1,981 (+5.9%) |
  | `all`, 5.36 | 1,589 | 1,629 (+2.5%) | 1,681 (+5.8%) |
  | `next`, 5.44 | 1,837 | 1,854 (+0.9%) | 1,930 (+5.1%) |
  | `all`, 5.44 | 1,608 | 1,617 (+0.6%) | 1,634 (+1.6%) |

  Against a real fetch, counting costs 1.6 to 5.9%, 26 to 111 ns a
  row, and dropping our counting stage, 200 to 260 ns a row, more than
  pays for it: a net gain of roughly 90 to 230 ns a row for every
  iterator with stages.
- **2 is dominated.** It isn't free for a program that never asks,
  +0.6 to 2.5% here and +2 to 7% in your table, as each check costs
  about what it skips; and it's dearer than 1 for one that does. It also
  adds a case to D2: a run made before Ekorn::Pipeline::Context is
  loaded, say by a `require` inside a stage, wouldn't count, so
  `result_number` would be undef there and counted in the next run.
  Counting always has no such case.
- **3 isn't worth the core's clarity.** It's free when nobody asks,
  but your table's costs are for a bare stage; with stages that do
  work, or a real source, they shrink, as ours did. Two copies of each
  of the three loops make the heart of the core harder to read, to
  change and to cover, for a saving few runs would notice. If a user's
  hot loop ever shows it, 3 can come later without changing what the
  functions give.

So D4 as "every run counts; it costs `all` 1 to 3%, pushed runs 3 to
12%, and `next` 6 to 8%, on a bare stage, less with real work" reads
well to us. Our shadows (2026-0032) build on whichever you choose, and
needn't wait.
