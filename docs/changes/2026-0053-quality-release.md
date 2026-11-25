# 2026-0053. A quality release

**Status:** shipped in v0.3.16 and v0.4.0

**Decisions:** D1 settled: v0.3.16 for the fixes, then v0.4.0 for
`pipe`. D2 settled: `pipe` gives what a run of its stages gives, in
either context. D3 settled: "new in v0.3.0" goes, unreplaced. D4
settled: one blank line above a sub's comment, two above a sub
without one; the code follows the rule. D5 settled: every module has
a `$VERSION`, the main module's, set by `minil prepare`, and a test
keeps them in step. D6 settled: DBIx-Squirrel is told what was found
and settled, with Iain's prompts, and handed `pipe`'s change.

**Origin:** roadmap, added 2026-11-25, from a quality review Iain
asked for, as the next release is a quality release

**Started:** 2026-11-25, in 43a93c6d1982531ffae27416ccc75e81c9b66141

**Finished:** 2026-11-25

## Background

Iain asked for a thorough review, for inefficient and inconsistent
code, errors, untested code, code that should be documented and isn't,
slop and invented claims, and poor documentation. It was made on
2026-11-25, at v0.3.15, by reading every module, and with these
checks:

- **Sound:** the tests pass on 5.36, and Perl::Critic, Perl::Tidy and
  podchecker are clean. Coverage of `lib/` is 100% of statements,
  branches and subs, and 97.7% of conditions. Every message the code
  raises is in its module's DIAGNOSTICS, and every DIAGNOSTICS entry is
  raised. Every function and method the docs name exists. The claims
  about DBIx::Squirrel's versions (v2.0.5, v3.6.1) match its Changes.
  The docs have almost no filler words, and no em dashes.
- **The core agrees with itself:** 18,000 random pipelines of `take`,
  `drop`, `batch`, `collect`, `tee`, `take_last`, a gather returning a
  pipeline, stops carrying values, flatMaps and filters, ending in a
  sink or not, gave the same results pushed, pulled a value at a time,
  read with `all`, and fed a value at a time.

What it found, numbered as the review gave them:

- **F1. A `|` chain dropped its source's original.** An iterator read
  as a source passes on its source's `original` part (2026-0052), but
  a chain's set-up, `_chain` in Operators, returned only the step, the
  end and the context, so a run reading a chain gave the chain's
  values as their originals: `11, 21`, not `row 1, row 2`. It read
  the iterator's `{context}` from inside it, too. Nothing tested it.
  DBIx::Squirrel's Context promises the row in "a pipeline of yours"
  reading a chain, so its users meet it.
- **F2. `from_csv` warned from inside the library** when a row's first
  field was undef, as `blank_is_undef` makes an empty one: the strip
  of a byte order mark, `CSV.pm` line 267, read it.
- **F3. `drain`, and a chain into a sink, pulled a value at a time,**
  rather than with the iterator's `all`, which was 45% faster over
  100,000 values.
- **F4. `$flush_at` checked `%flushed` needlessly:** a stage at or
  after `$next_flush` hasn't been flushed, so the test was never
  false, as the coverage report showed, and cost a hash lookup a call.
- **F5. `Pipeline.pm` repeated itself:** a run's set-up three times
  (`feed`, `_iterator`, `_pushed`); the "Pipeline stage ... failed"
  message three times, and an end's once more; and `_check_stage`
  repeated `_stage_role`'s search for role methods.
- **F6. The code broke CLAUDE.md's rule on blank lines:** 110 subs
  with a comment had two blank lines above it, against the rule's one,
  and 40 had one.
- **F7. Small slips of style:** two blank lines inside a `return`
  list, and after a package's opening brace, in CSV.pm; a section
  comment stranded between subs in Sinks.pm; `}` straight before `1;`
  in Pipeline.pm and JSON.pm; and Feed, a class, without
  `namespace::clean`, so `$feed->croakf` could be called.
- **F8. "New in v0.3.0", 21 times,** though v0.3.0 was only a trial
  (2026-0025), and Changes has no v0.3.0.
- **F9. The parts by name left out `original`:** three places said a
  set-up's keys were `step`, `flush`, `end` and `context`, and
  "Made for a run" listed no original, since v0.3.13.
- **F10. A broken link:** Pipes' POD linked to `Ekorn::Pipeline/pipeline`,
  which has no such section.
- **F11. Ekorn::Pipeline's SEE ALSO** left out CSV and Context, and
  ended without a full stop.
- **F12. The README overclaimed:** Tooling has "everything below but
  the operators", though Sugar and Pipes aren't in it either; and
  "Nothing is held between stages", twice, though `batch`, `collect`,
  `take_last` and `keep_all` hold values.
- **F13. Two of CSV's messages,** `field %d is a reference` and
  `field %d holds a wide character...`, matched no DIAGNOSTICS entry
  word for word, only "Can't write a row as CSV: %s".
- **F14. The reference said DBIx::Squirrel's rows are carried "through
  chains",** true of iterators, but not of `|` chains, until F1.
- **F15. The README's and the reference's examples are checked only by
  hand,** so drift there would go unseen; the how-to's run in
  `xt/howto.t`.
- **F16. The fuzz above** was a script in the review's scratchpad,
  not a test.
- **Q1. Only the main module had a `$VERSION`,** so a caller couldn't
  ask for a module's version, as `use Ekorn::Pipeline::Tooling v0.3.15
  qw(:context)`.
- **Q2. `pipe` gave the first result in scalar context,** unlike a
  pipeline, which gives how many came out, or a sink's result, a list
  sink's as an array reference. It's one of the first routines
  written, and DBIx::Squirrel's handles inherit it.

## Decisions

- [x] **D1.** Which release? Changing `pipe` (D2) changes what users'
  code gets, so it's a v0.4.0, outside DBIx::Squirrel's range, which
  would hold every fix back from its users until it moved the range.
  **v0.3.16 for the fixes, the docs and the `$VERSION`s, then v0.4.0
  for `pipe`,** Iain decided on 2026-11-25, both under this item.
- [x] **D2.** How should `pipe` behave in scalar context? The options:
  as a pipeline; the first result, but a sink's result where a sink is
  last; or as it is, documented. **As a pipeline,** Iain decided on
  2026-11-25: `$object->pipe(@stages)` is `Ekorn::Pipeline->new(@stages)->($object)`,
  in either context, with no special case. A caller wanting one value
  writes `my($x) = $object->pipe(...)`, or ends with `keep_first`.
- [x] **D3.** "New in v0.3.0": say v0.3.1, or give Changes a v0.3.0?
  **Neither: remove them,** Iain decided on 2026-11-25, as they're
  needlessly repetitive. Later "new in" notes stay.
- [x] **D4.** Blank lines: the code or the rule? **One blank line above
  a sub's comment, two above a sub without one,** Iain decided on
  2026-11-25: the rule as CLAUDE.md has it, and the code follows it.
- [x] **D5.** A `$VERSION` in every module? **Yes, if they're kept in
  step and easy to keep, and none stray,** Iain decided on
  2026-11-25. `minil prepare` already sets `$VERSION` in every module
  that declares one, so each module's file declares one, for its own
  package, and a test checks that each is the main module's, and
  that no other package declares one.
- [x] **D6.** What goes to DBIx-Squirrel? Iain will ask its session
  for the same review, and wants no question settled differently
  there by accident, so **a message with what was found and settled
  here, and Iain's prompts, word for word, and a task for `pipe`'s
  v0.4.0,** as he asked on 2026-11-25.

## The plan

**What:** fix and test every finding, F1 to F16, and Q1 and Q2 as D2
and D5 settle them, each change in `Changes` under its finding.

**Why:** the next release is a quality release.

**Steps:**

1. F1, F2: fix, each with a test that failed before.
2. F3, F4, F5: shorter, faster code, the tests unchanged, measured
   before and after.
3. F6, F7: the blank-line rule applied by a script that changes only
   blank lines; the slips by hand.
4. F8 to F14: the POD, the README, the how-to and the reference, and
   the manuals made again.
5. F15, F16: `xt/` tests that run the README's and the reference's
   examples, as `xt/howto.t` runs the how-to's, and the fuzz with a
   fixed seed.
6. D5: a `$VERSION` in each module, and the test.
7. D6: the message to DBIx-Squirrel.
8. D2, on a branch, `experiment/2026-0053-pipe`, after v0.3.16: `pipe`,
   its tests and docs, and a task to DBIx-Squirrel to take v0.4.0.

**Done when:** v0.3.16 and v0.4.0 are released, each finding fixed and
tested, and DBIx-Squirrel has the message and the task.

## What happened

**v0.3.16's part, 2026-11-25,** on `develop`, each finding fixed in
the commit named, with its entry in `Changes`:

- **F1 and F3,** in f151931616ad4f653a17cdc25b5e89858c0b6812: a
  chain's set-up returns its iterator's own `EKORN_SOURCE`, so a chain
  passes on whatever an iterator does; `@{}` and a chain into a sink
  read with `all`. Over 100,000 values on 5.36, `@{}` went from 16.8
  to 24.0 reads a second, and a chain of one stage into `keep_all` from
  5.1 to 10.1. The new subtests failed first.
- **F2,** in 19d704a47f43e60dde8f73333b7c7f0ab4867abc, its test failing
  first with the warning.
- **F17, found while fixing F2,** in
  15560a5d85a65afc2c08347e8fa30e9125f4b810: 41 patterns in the tests
  of JSON, CSV and a source's original lacked the `x` flag, and
  `scripts/manuals` wrote one with braces. The review's search for
  regexes had looked for `/.../` and missed them.
- **F4 and F5,** in 5bc3ca343cf7dc39f4fb5d343b4edf9ad9eec584.
  Measured alternately against the file before, three times each:
  2,000 pushed runs of two stages and five values went from 48.6 to
  50.1 runs a second, and pulled from 24.2 to 25.0; runs of 50,000
  values, pushed, pulled, read with `all` and fed, were within noise.
  A first version, whose `_stage_role` called `_stage_roles`, cost
  short pushed runs 4.5%, as each run asks it of each part; it has a
  loop of its own. `$all` and `$ended_once`, copied between the two
  iterators, stay copied: each closes over its own iterator's
  variables, and a shared builder would take references to five of
  them, no clearer.
- **F6 and F7,** in 4208d6be36e7034c7d8bd442a6582fad6426769a. Perl::Tidy
  makes two blank lines above a sub without a comment even straight
  after a block opens, and above `sub {` starting a line in a list,
  which is where CSV's "stray" blank lines inside a `return` had come
  from, so the review was wrong to call them slop; the script setting
  the blank lines does as Perl::Tidy does, and CSV names its closure
  first. The fix of F2 had tripped Perl::Critic, which reads the
  statement after a `try`'s `catch` as part of it without a `;`; the
  same commit adds the `;`, as JSON's code does, before anything was
  pushed.
- **D5,** in 87e0d4525140b3c59e6fa63ca93312e79695ece4: `minil prepare
  v0.3.16`, run on a copy, set all 23 modules' versions, and changed
  `META.json` only in its version.
- **F8 to F14,** in bdeb7b909024cc27da920897e7f70afe1d97c62a: 25 notes
  of "new in v0.3.0" removed. F14 needed nothing once F1 was fixed.
- **F15 and F16,** in 6a828143ec1e0efe169f7efa5a8272086452e076.
  2026-0025's wash-up said each of the reference's examples ran after
  the how-to's data; but the reference has a catalogue of its own,
  spelling ABBA and ordering the tracks differently, and run after
  that, every one of the 81 that run prints what it says. The
  agreement test passed a mutation of the push loop's flatMap order
  until its flatMap gave three different values, not two the same; it
  fails it now.
- **Checks, at 6a828143ec1e0efe169f7efa5a8272086452e076:** the tests
  pass on 5.36, 5.40 and 5.44; Perl::Critic and Perl::Tidy are clean;
  coverage is 100% of statements, branches, subs and POD, and 98.1% of
  conditions, up from 97.8%.

**v0.4.0's part, 2026-11-25,** on the branch
`experiment/2026-0053-pipe`, in
f1fd15cb4d65000cd4b45451d25abdc84dac8962, kept off `develop` so that
`main` can reach v0.3.16 without it: `pipe` is
`Ekorn::Pipeline->new(@stages)->($object)`, in either context. Its new
tests failed against the old code. Two of Ekorn's own tests read
`pipe` through Test2's `is`, which takes its first argument in scalar
context, as `is $thing->pipe(...), 42`, and so compared a count once
the change was made; DBIx-Squirrel's `t/03-pipe.t` does the same.
Its entry in `Changes` sits at the top of Unreleased, above
v0.3.16's, with a note to say so.

**DBIx-Squirrel, 2026-11-25:** a message with what was found and
settled, and Iain's prompts, word for word, as he asked (D6), and a
task to take v0.4.0's `pipe`, waiting on its release.

**What's left:**

1. ~~Release v0.3.16 from `develop`.~~ Done, 2026-11-25.
2. ~~Rebase `experiment/2026-0053-pipe` onto it.~~ Done, 2026-11-25;
   merge it into `develop`.
3. ~~Release v0.4.0, telling DBIx-Squirrel, whose task waits on it,
   and ship this item.~~ Done, 2026-11-25.

**After v0.3.16, 2026-11-25:** the branch was rebased onto the
release, its `Changes` entry left alone under Unreleased and its note
removed, so it's now f2b74e33f11486613742f73b20f482ef4d343b98, in
place of f1fd15cb4d65000cd4b45451d25abdc84dac8962 above. Its tests
pass on 5.36 and 5.44, with the Windows fix to `t/34-versions.t` it
now has. DBIx-Squirrel was sent the new hash.

**v0.4.0, 2026-11-25:** the branch's one commit was replayed onto
`develop`, which had moved on by a record commit, and `develop`
fast-forwarded to it, keeping its history straight and signed; the
branch is no longer needed. The item ships with v0.4.0, and leaves the
roadmap in its release commit.

- **Outcome, against Done when:** v0.3.16 and v0.4.0 are released;
  each finding, F1 to F17, is fixed, and tested where a test can hold
  it; DBIx-Squirrel has the message, with Iain's prompts, and the task
  for `pipe`, which v0.4.0's release frees it to do.
