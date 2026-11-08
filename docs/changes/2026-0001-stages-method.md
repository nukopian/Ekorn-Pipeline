# 2026-0001. A stages() method

**Status:** shipped in v0.1.1

**Decisions:** D1 settled: a stages() method, not composing in place. D2 settled: it ships in v0.1.1, with 2026-0002, as a trial first. None open.

**Origin:** roadmap, added 2026-11-07, from the question whether `new`
should take a pipeline where a stage goes, raised by a review of the
docs before v0.1.0

## Background

`Ekorn::Pipeline->new` refuses a pipeline given as a stage: a pipeline
is an object that can be called as a code reference, not a code
reference, so it's "Expected stage #1 to be a code reference". The
reference and the how-to show a wrapper instead:

```perl
my $clean  = Ekorn::Pipeline->new(sub { s( \A \s+ | \s+ \z )()xgr }, sub { length ? $_ : () });
my @titles = Ekorn::Pipeline->new(sub { $clean->($_) })->(@raw);
```

The wrapper runs the inner pipeline once for each value, each call a
run of its own, so with `take(2)` inside, given 1 to 5, it gives all 5
values, not 2. Three ways of taking a pipeline as a stage were
weighed:

- **A.** not at all, as now;
- **B.** run it once for each value, as the wrapper does, which makes
  the obvious reading wrong;
- **C.** compose it in place, its stages running in the outer
  pipeline's run, as if listed there.

### Composing in place, tried

On 2026-11-07 C was prototyped in a scratch copy of `lib/`, not
committed. It needed about fifteen lines in `new`, and four one-line
changes so that `_iterator` names each stage by where it is:

```perl
sub new ($class, @given) {
    my(@stages, @names);
    for my $n (1 .. @given) {
        my $stage = $given[$n - 1];
        if ($stage isa 'Ekorn::Pipeline') {
            push @stages, @{ $stage->{stages} };
            push @names,  map {"$n.$_"} @{ $stage->{names} };
            next;
        }
        croakf 'Expected stage #%d to be a code reference', $n
            unless is_coderef($stage);
        push @stages, $stage;
        push @names,  $n;
    }
    ...
```

The runner needed no change. The two things composing seemed to need
of it already happen: a `gather` block is called at the start of each
run, whichever pipeline it came from, and a stop is a stop of the run
it's thrown in. A test file of 73 checks found:

- **The headline:** `take(2)` inside, given 1 to 5, gave 2 in all; the
  wrapper gave all 5.
- **A stop inside stops the source:** with `take(3)` inside, an
  iterator called its source three times, of a hundred values.
- **State is per run:** a second run started `take` afresh. The same
  pipeline given twice, `new($c, $c)` with `$c` a `collect`, kept two
  states, giving `[[1, 2, 3]]`.
- **Ends run in order:** `batch(2)` inside, then an outer stage, gave
  "1 2", "3 4", "5". An outer `collect` feeding an inner one gave
  `[[4]]` for four values.
- **A stop's value goes on:** `Stop($_ * 10)` inside, at 3, then `+1`
  outside, gave 2, 3, 31.
- **`ending()`** was true in the inner stages when the outer
  pipeline's end fed them.
- **Errors named the stage by where it is:** "Pipeline stage #2.3
  failed at" the caller's line, and "#1.2.3" three deep. A bad
  `gather` inside was "Expected stage #2.2, made with gather, ...". A
  flat pipeline's messages were as now, though the two DIAGNOSTICS
  entries would have read `#%s` rather than `#%d`.
- **A bad stage inside** was caught when the inner pipeline was made,
  as its "#2".
- **An empty pipeline** as a stage added nothing.
- **`pipe` and `tap`** took one too, as they pass their stages to `new`.
- **Composing was the same as listing the stages:** for 36 pairs of
  canned and hand-written stages, `new(new(@a), new(@b))` gave the same
  as `new(@a, @b)`.
- **The tests in `t/`** all passed on the prototype: 9 files, 322
  assertions.
- **Speed:** with `cmpthese` over 10,000 values, composed ran at 94.2
  runs a second and the same stages listed by hand at 93.9; the wrapper
  ran at 20.6, about 4.5 times slower, as it makes a run for each
  value.

### What that means for DBIx::Squirrel

DBIx::Squirrel takes a call's stages off the end of its arguments by
looking for code references: `split_stages` in its Util, and
`_ends_in_stages` and the check of a statement's definition in its
Sugar. A pipeline given there would be taken for a bind value, or
refused, so composing would have meant changing all three, or Ekorn
exporting an `is_stage` test for them to use.

Since composing gives what listing the stages gives, a method returning
them gives the same meaning with no change to `new`, the runner, the
messages or DBIx::Squirrel. Every stage is a code reference, a `gather`
stage a blessed one, so `split_stages` takes them as they are. That was
checked with today's code: `take(2)` spliced into another pipeline gave
2 in all.

## Decisions

- [x] **D1.** Should a pipeline be usable where a stage goes, and how?
  With a `stages()` method, returning a pipeline's stages as a flat
  list, decided on 2026-11-07. A pipeline given to `new` as a stage is
  still refused. Iain: it's an opt-in that DBIx::Squirrel can use with
  almost no effort, and it keeps the change around DBIx::Squirrel
  small, and its release from slipping further. Composing in place
  stays an idea for a later version, roadmap 2026-0004. Against
  composing, `stages()` gives up only the shorter call, `$p` rather
  than `$p->stages`, and naming a nested stage in a message; an error
  names its place in the flat list.
- [x] **D2.** In v0.1.1, decided on 2026-11-08: it goes out in v0.1.1's
  trial, with 2026-0002 and 2026-0003. The question was: does it go in
  v0.1.0, with a second trial, v0.1.1, or in
  a later v0.1.x? It's an addition, so either suits DBIx::Squirrel's
  range, `>= v0.1.0, < v0.2.0`. If 2026-0002 makes a second trial
  anyway, it costs little to add it there.

## The plan

As decided in D1 and D2, on 2026-11-07 and 2026-11-08: add `stages`
to Ekorn::Pipeline, returning a copy of the pipeline's stages, in
order, as a list, or in scalar context how many. Test that it returns
them in order and as a copy; that spliced into another pipeline, a
`take` ends the whole run, fetching no more; that a `gather` stage
starts afresh each run, and keeps its own state when given twice; and
that the pipeline still runs on its own. Document it in the POD, the
reference (a section of its own, and beside `new` and Pipelines inside
stages), the how-to, whose wrapper example becomes "Use a pipeline's
stages in another", the README and `Changes`. It goes out in v0.1.1's
trial.

**Done when:** `stages` is in Ekorn::Pipeline, tested, and documented
as above, its examples printing what their comments say.

## What happened

- **Outcome:** done, as planned. The method is one line. Its subtest
  in `t/02-pipeline.t` has 10 checks. The examples in the reference,
  the how-to and the README were run, and print what
  their comments say.
- **Changes from the plan:** the how-to's recipe keeps calling a
  pipeline from a stage as the other way, saying how it differs, so a
  reader can choose; and the README gained a short example, as `stages`
  is what a function's caller would use.
