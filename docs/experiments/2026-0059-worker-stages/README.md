# Worker stages, and where a value came from (roadmap 2026-0059)

Prototypes, kept so their findings needn't be found again. Nothing here
is part of Ekorn-Pipeline: this directory lives only on the branch
`experiment/2026-0059-worker-stages`, made from `develop` as the idea
was added, and Minilla leaves `docs/` out of the distribution in any
case. The prototypes were made and tested against the core as at
d859b2452f70c2a62105054d6b96b7dabb741b20.

It holds two prototypes:

- **`workers/`:** stages running a block for each value in a pool of
  forked workers, against Ekorn as it is: `in_workers`,
  `in_workers_any` and `once_per`. Core Perl only.
- **`stage-original/`:** a change to the core letting a `gather` stage
  give an `original` part, as a source may (2026-0052), so that the
  stages after a stage that holds values back see the right
  `result_original`; and the worker stages giving it.

The findings that matter most to the core are under "What the
prototypes found", and the questions they leave under "Open
questions". `TODO.md` on `develop` has the task that takes them on.

## Running them

Every command runs from this directory, with the library named, as
CLAUDE.md says. Each test file passes under Perl 5.36 and 5.44.

```sh
# workers/, against Ekorn's own lib
perlbrew exec --with perl-5.36.3@ekorn-pipeline prove -Iworkers/lib -I../../../lib workers/t

# stage-original/: apply the patch to a scratch copy of the core first
git -C ../../.. worktree add --detach /tmp/ekorn-stage-original HEAD
git -C /tmp/ekorn-stage-original apply "$PWD/stage-original/stage-original.patch"
cp stage-original/t/35-stage-original.t /tmp/ekorn-stage-original/t/
(cd /tmp/ekorn-stage-original && perlbrew exec --with perl-5.36.3@ekorn-pipeline prove -l -j8 t)
perlbrew exec --with perl-5.36.3@ekorn-pipeline prove -I/tmp/ekorn-stage-original/lib -Istage-original/workers/lib stage-original/workers/t
git -C ../../.. worktree remove --force /tmp/ekorn-stage-original
```

## workers/: the stages

`lib/Ekorn/Pipeline/Workers.pm` has three stages, each a `gather`, on a
pool class, `Ekorn::Pipeline::Workers::Pool`, which takes values tagged
by its caller and gives back what each finished with, tagged, knowing
nothing of order or keys.

- **`in_workers($n, $block, %options)`:** runs `$block` for each value
  in up to `$n` forked workers, and passes its results on in the order
  the values came. At most `window` values (by default `2 * $n`) are
  sent and not yet passed on. Workers are forked when the first value
  arrives, so a run with none forks nothing, and are ended by the
  stage's end: closed when the run was done, killed otherwise.
- **`in_workers_any`:** the same, passing results on as they finish.
- **`once_per($key, $n, $block, join => ..., hold => ...)`:** runs
  `$block` once per distinct key, in the workers, and passes each value
  on as `join` makes it from the value and its key's results (without a
  join, the key's results). A key asked for while its lookup is in
  flight waits for it. `hold` bounds the values waiting behind a key
  not yet back.

Values cross to the workers, and results back, by Storable over pipes.
A block's Stop crosses back and stops the run with its values; its
error is thrown in the parent, in the place of its value; a worker that
dies without replying is an error naming the value it had. Values or
results that can't be frozen, such as code references, croak, naming
the value. Workers leave by `POSIX::_exit`, so the parent's END blocks,
destructors and buffered output aren't run or written twice.

The block sees where its value stands in the run, as it would in the
stage: the run's context, `ending`, and `result_original`, exactly; and
`result_number` as it was when the value arrived (see below). The parent
captures them as each value arrives and sends them with it. The worker
runs the block inside a one-value Ekorn run of its own, whose source
gives the context, calling it from that run's flush when the parent was
ending; it sets the number and original by `local` on
`$Ekorn::Pipeline::CURRENT_RESULT`, the only one of Ekorn's run state
that isn't lexical. A stop or error is caught round the block, before
that run sees it.

The tests are `t/in_workers.t` (24) and `t/once_per.t` (11). They
cover order, speed, drops and several results per value, a run with
no values, a stop after the stage (at most the window's worth started,
the source told `stopped`, every worker reaped), errors, stops and hard
exits in the block, values that can't cross, an iterator let go, a
feed, two runs of one pipeline at once, the stage nested in itself,
and the block's context against the same block in a plain stage.
`probe.pl` and `probe2.pl` measure the speed-up and show the context
the block sees.

### Measured, on Perl 5.36

| Workers | 32 jobs of 100 ms |
|---|---|
| 1 | 3.25 s |
| 2 | 1.63 s |
| 4 | 0.82 s |
| 8 | 0.43 s |
| 16 | 0.24 s |

The stage costs about 18 to 20 µs a value, so it pays for work of a
millisecond or more: a request, a query, a command.

Forty values, one taking 1 s and the rest 0.1 s, on 4 workers: 1.83 s
ordered, as the workers sit idle behind the slow one once the window
fills; 1.32 s unordered.

A hundred rows sharing ten keys make ten lookups through `once_per`;
ten keys of 0.2 s each, on 10 workers, take under 0.8 s, against 2 s
one at a time and 20 s a row.

## stage-original/: a stage that says where its values came from

`stage-original.patch` changes only `lib/Ekorn/Pipeline.pm` (89 lines
in, 14 out, 25 of them comments), and applies to `develop` as at the
commit above:

- `_make_run` reads an `original` part from a gather's or an
  `EKORN_STAGE`'s parts, by name only. A list keeps its three parts and
  its messages: `t/03-gather.t` and `t/11-gather-pipeline.t` pin that
  four things in a list croak as they do now. A part that isn't a code
  reference croaks, `Expected stage #%s's original to be a code
  reference`.
- A stage with the part has its step and flush wrapped, once a run, to
  set the part answering for the values it gives, as it returns them
  or its stop carries them, in `$CURRENT_RESULT->[2]`, where the
  source's part is kept now.
- A run with such a stage takes `_full_iterator`, whose waiting values
  then carry the part answering for them beside their original. The
  plain loops, `_push_steps` and `_plain_iterator`, are unchanged.
- An iterator read as a source passes on the part that answered for
  the value it handed out last; with no stage part, its source's, as
  now.

`t/35-stage-original.t` (13) tests it; the whole suite passes beside
it, unchanged, on 5.36 and 5.44. `workers/` here is the worker stages
giving the part, releasing one job per step, as the contract below
requires; `workers/t/after.t` checks that a stage after each of them
gets each value's own original.

### Measured: what it costs runs that don't use it

On runs taking the full loop (with a flush, an end or a sink), against
the core as it was, by `bench.pl`, medians of seven:

| | Perl 5.36 | Perl 5.44 |
|---|---|---|
| a stage with a flush | +12 to 20 ns a value (1 to 2%) | +12 to 20 ns (1 to 2%) |
| values waiting on the queue | +35 to 45 ns (2%) | +40 to 45 ns (2%) |

It took three rounds. Carrying the part on every value cost 70 to
175 ns (7%); guarding that behind one flag set when the run is made,
20 to 50 ns; and moving the per-stage check into wrappers made once a
run, the figures above. What's left is three checks of that flag a
value.

### Measured: on DBIx-Squirrel's queries

DBIx-Squirrel's session asked, on 2026-11-27, for the cost on its own
queries, and which of Ekorn's loops they take. `dbix-bench.pl` runs a
200,000-row SQLite query through `$dbh->iterate`, with DBIx-Squirrel's
`lib` (ac055b84aa0b736bca23c198b211891887cc7c5c), and counts the loop
each run takes. Perl 5.36, three runs a core, each the median of
seven:

| The query's stages | Loop | The core as it was (ns a row) | With the patch (ns a row) |
|---|---|---|---|
| a map | `_plain_iterator` | 1,427 / 1,423 / 1,424 | 1,421 / 1,418 / 1,418 |
| a map, `take` | `_plain_iterator` | 1,698 / 1,682 / 1,679 | 1,686 / 1,682 / 1,676 |
| a map, `batch(100)` | `_full_iterator` | 1,546 / 1,539 / 1,535 | 1,549 / 1,544 / 1,545 |
| a map, `count_items` | `_full_iterator` | 1,429 / 1,431 / 1,429 | 1,450 / 1,446 / 1,440 |

The loop is chosen by the stages' flushes and ends, and a sink, not
by the statement source's end, so a query whose stages are maps takes
the plain loop, which the patch doesn't touch. One with a stage that
has a flush or an end, or a sink, pays 3 to 21 ns a row, under about
1.5%. Its statement source's part, `sub { $context->{row} }`, answers
for the row fetched last, so limit 1 below applies to it too; the
patch neither calls it once a row nor keeps each row.

```sh
# from this directory, with the patched core in /tmp/ekorn-stage-original
perlbrew exec --with perl-5.36.3@dbix-squirrel-2 perl -I/tmp/ekorn-stage-original/lib -I$HOME/Git/github.com/nukopian/DBIx-Squirrel/lib stage-original/dbix-bench.pl
```

### Measured: the flush tail

The part has a source's contract: one answer for everything one call
gives. So a stage gives one job's results a step, and its flush gives
the rest, whose original is undef, as D3 of 2026-0046 has it for a
flush's values. Over 1,000 values, by `tail.pl`:

| Stage | Results with no original |
|---|---|
| `in_workers(4)` | 7: the window bounds it |
| `once_per(4)`, distinct keys | 9 |
| `once_per(4)`, 50 keys | 203 |
| `once_per(4)`, a slow first key, `hold` 1000 | 999 |
| `once_per(4)`, a slow first key, `hold` 50 | 49 |

None of the 1,000 was given another value's original, against every
one, one behind, before. But `once_per`, giving one value a step, can't
drain a backlog, so its tail is as long as `hold` lets it grow. In a
short run, or a feed whose results come at `close`, nearly everything
is in the tail: `sourceless.pl` gives `3 <- 1, 5 <- undef, 7 <- undef,
9 <- undef` for four values pushed through `in_workers`.

## What the prototypes found

1. **The original is where the run is, not where a value came from.**
   The core keeps one current original, the source's last value or its
   part's answer for the value it gave last (2026-0052, D2), and
   carries it with values waiting on its queue. It takes every stage
   to be a map: what comes out came from what went in. A stage holding
   values back (`batch`, `take_last`, `in_workers`, `once_per`) gives
   values the run has moved past, and the stages after it see the
   latest value's original, which D2 of 2026-0052 wrote down for
   `batch`. And a source's part answers lazily, for the value it gave
   last, so an earlier value's original is gone once the source moves
   on, unless something asked for it then.
2. **A source can say where its values came from; a stage can't.**
   That asymmetry is the whole difficulty, and `stage-original/` lifts
   it. But a part, as a source has, answers with a value, so a stage
   can make up an original rather than point to one that came in, and
   one answer a call can't serve a flush that gives several values.
3. **A flush's values have no original (D3), even when each came from
   one value.** D3 takes a flush's values to come from many, as
   `batch`'s and `count_items`'s do. `in_workers`' and `once_per`'s
   don't.
4. **A flush can't pass values on and then die.** An error found in a
   flush after values were taken there loses them with the run; in a
   plain stage they'd have gone on first. `in_workers`' and `once_per`'s
   flushes both have it, and their tests check only what's promised.
5. **Nothing lets a stage act between its inputs.** A feed's push with
   no values runs nothing, so `once_per` couldn't be made from
   `in_workers` through a feed: nothing would collect finished lookups
   between new keys. It shares the pool instead. The same gap leaves
   `once_per`'s backlog undrained, and is what stages by time, such as
   a batch by size or time, would need.
6. **A run's state can't be carried into another process, or replayed
   there.** `%running` (the context and `ending`) is a lexical of
   `lib/Ekorn/Pipeline.pm`; only `$CURRENT_RESULT` can be set from
   outside. The worker replays the context and `ending` through a
   one-value run of its own, by Ekorn's public behaviour, which works,
   at the cost of a run a value.
7. **`result_number` in a delayed block can't be the stage's.** It
   counts results that have left the run, and a worker starts before
   the results before its value have. It's the number when the value
   arrived, which is all that can be known then; after the stage, it's
   right.

Smaller things, for whoever builds the distribution:

- A context or original that Storable can't freeze, such as a
  filehandle, is left behind, and the block sees undef for both.
- Asking for the original as each value arrives calls the source's
  part a value, which a run otherwise calls only when asked.
- Values sent to workers before a stop or an error still ran their
  side effects, up to the window's worth.
- The block runs in a copy of the program forked mid-run: what it
  changes, the parent doesn't see.
- Time::HiRes's `sleep` takes `;@` in 1.977 (Perl 5.36) and `;$` in
  1.978 (Perl 5.44), so `sleep $x == 1 ? 0.5 : 0.02` is
  `sleep(($x == 1) ? ...)` on one and `sleep($x) == 1 ? ...` on the
  other. Parenthesise.

## Open questions

These are for the task in `TODO.md`, and then Iain; none is decided.

- With no source, `result_original` gives the value the caller passed
  to the first stage, and the prototype keeps that. Iain's reading,
  2026-11-27: the original is what came into the pipeline, the
  source's or the caller's value, wherever the run has got to. Should
  a stage then only be able to say which incoming value its output
  came from, never give an original of its own; and is that a rule in
  the docs, or one the core enforces?
- Should D3 still hold for the values of a stage that says where they
  came from?
- Should a stage's answer pass through an iterator read as a source,
  as `stage-original/` has it?
- Is 1 to 2% on runs taking the full loop acceptable for this?
- Would a way for a stage to act between inputs (finding 5) drain
  `once_per`'s backlog, and serve stages by time too?
