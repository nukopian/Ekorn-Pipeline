# Ekorn::Pipeline: what's implemented

**Status:** a living document, on `pipeline-experimental` only, for
roadmap 2026-0022. It describes the code as it is at the commit it
was last updated in, not as it's meant to be: [DESIGN.md](DESIGN.md)
says what's meant. Whether it outlives the branch is still to decide.

**For:** anyone building on Ekorn, DBIx-Squirrel's session above all,
and anyone checking the design against the code.

**What it's for:**

1. **To show what's delivered, in the round:** the architecture, how a
   run flows, and what each component does, at a level that explains
   what's going on, with examples that run.
2. **To show how a package uses Ekorn as it is,** delivering sources,
   sinks and stages of its own through Ekorn's protocols, without
   subclassing or wrapping anything of Ekorn's (section 7).
3. **To verify the design against the code** (section 10). Every part
   of the design is listed there, with whether it's implemented, and
   every behaviour of the code the design doesn't describe is listed
   too. Drift either way shows up as a row that doesn't match.

## Contents

1. [How to keep this document](#1-how-to-keep-this-document)
2. [The examples' data](#2-the-examples-data)
3. [In a nutshell](#3-in-a-nutshell)
4. [Architecture](#4-architecture)
5. [A run, step by step](#5-a-run-step-by-step)
6. [The components](#6-the-components)
7. [Building on Ekorn as it is](#7-building-on-ekorn-as-it-is)
8. [Errors](#8-errors)
9. [What the tests prove](#9-what-the-tests-prove)
10. [Design and implementation, side by side](#10-design-and-implementation-side-by-side)
11. [Known gaps](#11-known-gaps)

## 1. How to keep this document

- **A commit that changes the code on this branch updates this
  document in the same commit:** the section describing the part
  changed, and its rows in section 10.
- **A commit that changes the design updates section 10,** marking
  what the code doesn't yet do.
- **Every Perl example runs.** Each block runs on its own after the
  data in section 2, with the `package` blocks before it in its
  section, and prints what its comments say. Check them before
  committing a change to them, as the how-to's are checked.
- **It says what the code does, plainly, even where that's wrong.**
  A behaviour that's a bug, or that the design doesn't want, is
  described as it is, and listed in section 10.2 until it's fixed.

## 2. The examples' data

Every example below runs after this block. It loads what the examples
use, puts the operators in force, and makes the tracks the how-to
uses, a file of three lines, and two parts that say how their run
ended: `noisy`, a source, and `noisy_count`, a sink.

```perl
use v5.36;
use Ekorn::Pipeline;
use Ekorn::Pipeline::Factories qw(stage source sink sink_scalar gather);
use Ekorn::Pipeline::Operators;
use Ekorn::Pipeline::Sources qw(from_arrayref from_file);
use Ekorn::Pipeline::Sinks   qw(count first_item to_array to_arrayref to_file);
use Ekorn::Pipeline::Stages::Flow;    # take and drop
use File::Temp qw(tempdir);

my @tracks = (
    {artist => 'Abba',  title => 'Dancing Queen',           plays => 9100},
    {artist => 'Abba',  title => 'Knowing Me, Knowing You', plays => 4200},
    {artist => 'Blur',  title => 'Girls & Boys',            plays => 6100},
    {artist => 'Blur',  title => 'Parklife',                plays => 5800},
    {artist => 'Blur',  title => 'Country House',           plays => 3900},
    {artist => 'Cream', title => 'Sunshine of Your Love',   plays => 7700},
);

# A file of three lines.
my $dir     = tempdir(CLEANUP => 1);
my $setlist = "$dir/setlist.txt";
open my $out, '>', $setlist or die "Can't write $setlist: $!\n";
print {$out} "Parklife\nSong 2\nTender\n";
close $out or die "Can't write $setlist: $!\n";

# A source of the values given, saying how its run ended.
sub noisy (@values) {
    return source {
        my @rest = @values;
        return (sub () { @rest ? shift @rest : () }, sub ($how) { say "source: $how" });
    };
}

# A sink counting its values, saying how its run ended.
sub noisy_count ($label) {
    return sink_scalar {
        my $n = 0;
        return (sub ($value) { $n++ }, sub () {$n}, sub ($how) { say "$label: $how" });
    };
}
```

## 3. In a nutshell

**The stream concept, applied to functions.** A function that hands
out values is a **source**. A **pipeline** is a list of **stages**,
each turning a value into none, one or several. A **sink** holds back
every value and gives a result. The pipeline is where they meet, either
way round: a function takes its caller's stages, or the caller pulls a
function's values through a pipeline of their own.

Values come in two ways. **Pushed**, the pipeline is called with them.
**Pulled**, it's given a source, and returns an **iterator**, which
pulls only as it needs to.

```perl
my $blur = Ekorn::Pipeline->new(sub { $_->{artist} eq 'Blur' ? $_ : () }, sub { $_->{title} });

say join ', ', $blur->(@tracks);    # Girls & Boys, Parklife, Country House

my $next = $blur->iterator(from_arrayref(\@tracks));
say $next->();                      # Girls & Boys
```

A sink last gives the run's result. In scalar context, a pushed run
gives a scalar sink's result:

```perl
my $hits = Ekorn::Pipeline->new(sub { $_->{plays} > 6000 ? $_ : () }, count)->(@tracks);
say $hits;    # 3
```

What opens something is **made for a run**, afresh each time, and is
**told how the run ended**, `done`, `stopped` or `died`, however it
ended, so it can close, commit or roll back:

```perl
my($n) = Ekorn::Pipeline->new(take(2), count)->iterator(noisy(1 .. 5))->();
say $n;
# source: stopped
# 2
```

`take(2)` stopped the run while the source still had values, so the
source was told `stopped`. With the operators in force, `|` draws the
same thing left to right:

```perl
say from_arrayref(\@tracks) | stage { $_->{artist} eq 'Blur' ? $_ : () } | count;    # 3
```

## 4. Architecture

### 4.1 The modules

```
                         your code, and packages built on Ekorn
                                         |
       +---------------------------------+------------------------------+
       |                                 |                              |
  Operators (| @{})              Sources, Sinks                 Stages::Flow, ::Batch,
  in force where it's            ready-made parts               ::Taps: ready-made
  used: chains of sources        (from_file, to_file,           stages (take, batch,
  and of stages                   count, first_item...)         peek...)
       |                                 |                              |
       +--------------+------------------+                              |
                      |                                                 |
               Factories: the words                                     |
               stage, source, sink, gather                              |
                      |                                                 |
       +--------------+-------------+-------------+                     |
       |              |             |             |                     |
     Stage         Source         Sink         Gather <-----------------+
   ekorn_stage:     ekorn_source:   ekorn_sink_scalar or    ekorn_stage:
   its code      a set-up     ekorn_sink:        a set-up
                              a set-up
       |              |             |             |
       +--------------+------+------+-------------+
                             |
                     Ekorn::Pipeline: the core
          new, iterator, the run loop, flushes and ends,
             ending(), run_context(), is_stage, names
                             |
          Element   Iterator   Stop   Errors   Pipes
```

Each layer uses only those below it. The core knows parts by their
role methods, not their classes, so a package's own parts take any
role Ekorn's can (section 4.2).

| Module | Layer | What it holds |
|---|---|---|
| `Ekorn::Pipeline` | core | the pipeline class; `new`, `iterator`, `stages`, `named`, `pipeline`; the run loop, flushes and ends; `ending()`, `run_context()`, `is_stage`, `is_sink` |
| `Ekorn::Pipeline::Element` | core | the base of every type: a hash, called as a code reference |
| `Ekorn::Pipeline::Iterator` | core | what `iterator` returns: called for each value; a source to another run; ends its run when finished or let go; says how its run ended, with `ended` |
| `Ekorn::Pipeline::Stop` | core | `Stop(...)`, and `throw` |
| `Ekorn::Pipeline::Gather` | core | `gather {...}`: a stage made for a run, with a flush and, optionally, an end |
| `Ekorn::Pipeline::Errors` | core | `croakf`, and `@INTERNAL`, the packages Carp looks past |
| `Ekorn::Pipeline::Pipes` | core | `pipe` and `tap`, for a class's objects to run themselves through stages |
| `Ekorn::Pipeline::Stage` | 1 | a stage as an object, wrapping a code reference |
| `Ekorn::Pipeline::Source` | 1 | a source made for each run, from a set-up |
| `Ekorn::Pipeline::Sink`, `::Sink::Scalar`, `::Sink::List` | 1 | a sink made for each run, from a set-up, giving one value or a list |
| `Ekorn::Pipeline::Factories` | 1 | the words: `stage`, `source`, `sink`, `sink_scalar`, `gather` |
| `Ekorn::Pipeline::Sources` | 2 | `from_arrayref`, `from_file` |
| `Ekorn::Pipeline::Sinks` | 2 | `all_items`, `first_item`, `only_item`, `count`; `to_array`, `to_arrayref`, `to_file` |
| `Ekorn::Pipeline::Operators` | 3 | `\|` and `@{}`, in force lexically; `chain` and `drain`, for a package's own source class |
| `Ekorn::Pipeline::Stages::Flow`, `::Batch`, `::Taps` | parts | `take`, `drop`, `take_while`, `drop_while`; `batch`, `collect`; `peek`, `count_into`, `dump_to` |

### 4.2 The protocols the core relies on

A part says what it can be by its methods, each called as a run
starts, returning closures that share that run's state. These are the
whole contract between Ekorn and code built on it, and none of them
needs the code to load Ekorn:

| Role | Method | Returns |
|---|---|---|
| **Source** | `ekorn_source` | its step, called with nothing, giving the next value or values, or an empty list at the end; optionally its end, told how the run ended; optionally a context for the run |
| **Stage made for a run** | `ekorn_stage` | its step, called with each value, returning a list; optionally its flush, called when its input runs out, its values going on; optionally its end |
| **Sink** | `ekorn_sink_scalar` or `ekorn_sink` | its step, called with each value, its return ignored; its flush, giving its result, one value for `ekorn_sink_scalar`, `undef` if it has none; optionally its end |

And beside them:

- **A plain code reference** is a source or a stage, by where it's
  given, with no flush or end.
- **A pipeline** given as a stage has its stages spliced in.
- **`is_sink`** says whether a part is a sink, `'scalar'` or `'list'`,
  or false; a pipeline by the sink it ends in (D43).
- **`is_stage`** takes a code reference, a pipeline, or anything
  offering `ekorn_stage`, `ekorn_sink_scalar` or `ekorn_sink`. A part offering more
  than one of those three croaks when given to `new`, as they'd be
  called in the same place.
- **A stop** is an exception `isa Ekorn::Pipeline::Stop`.
- **A stage may ask** `Ekorn::Pipeline::ending()`, true while a flush
  runs and its values go on, and `Ekorn::Pipeline::run_context()`, the
  context its run's source gave.
- **The caller may ask** an iterator `ended`: nothing while its run
  goes, then `done`, `stopped` or `died` (D34).

The core asks Ekorn's classes only to splice a pipeline, to read a
gather's block, which may return a pipeline as its step (as v0.2.0's
could), and to recognise a stop.

### 4.3 Every type is an Element

Every type Ekorn makes is an object of a class built on
Ekorn::Pipeline::Element: a hash holding what it was made with, and a
`call` field, the closure that does its work. Element overloads `&{}`
to return that closure, so an Element is called as a code reference.
The closure never refers to the object, so the object is freed as soon
as nothing else holds it.

```
Ekorn::Pipeline::Element          call, &{}
  ├─ Ekorn::Pipeline::Stage       ekorn_stage: its code
  ├─ Ekorn::Pipeline::Gather      ekorn_stage: its block's step, flush and end
  ├─ Ekorn::Pipeline::Sink        ::Scalar, ekorn_sink_scalar; ::List, ekorn_sink
  ├─ Ekorn::Pipeline::Source      ekorn_source
  ├─ Ekorn::Pipeline::Iterator    ekorn_source: a run already
  └─ Ekorn::Pipeline              a list of stages: call pushes values
```

`new` makes a Stage of each plain code reference it's given, so a
pipeline is made of parts offering role methods, and a run calls a
Stage's code as it is, costing nothing per value:

```perl
my $double   = sub { $_[0] * 2 };    # $_ is set only in a run
my $pipeline = Ekorn::Pipeline->new($double);
my($stage)   = $pipeline->stages;
say ref $stage;                                        # Ekorn::Pipeline::Stage
say $stage->code == $double ? 'the same code' : '';    # the same code
say ref(\&$stage), ' ', join ',', $stage->(4);         # CODE 8
```

An Element isn't a code reference to code that checks the type, with
`ref` or Ref::Util's `is_coderef`. Inside Ekorn, everything asks what
a thing can do instead.

## 5. A run, step by step

A **run** is one call of a pipeline with values, or one iterator made
from it.

### 5.1 The flow

```
  $pipeline->iterator($source)
        |
        |  1. Set up, as the run starts (D21)
        |     the source: ekorn_source, if it offers one; a code
        |       reference is its own step
        |     the stages, in order: each by its role method; a gather
        |       by its block; a code reference as it is
        |     if a set-up dies, what's set up is told "died"
        v
  an Iterator, $next
        |
        |  2. Each $next->() pulls until a value comes out, or the run
        |     has ended:
        |
        |     a value waiting?  ---- yes ---> run it through the stages
        |        | no                         from where it waits
        |        v
        |     source not done?  ---- yes ---> pull; an empty list, or a
        |        | no                         stop, means done
        |        v
        |     a flush to call?  ---- yes ---> call it, first stage
        |        | no                         first; its values go on
        |        v
        |     return nothing
        |
        |  3. The run ends as soon as nothing in it can still act on a
        |     value: the source done, every flush called, and every
        |     value waiting past the last stage (D15). Each end is then
        |     called once, the source's first, then the stages', first
        |     stage first (D11), told how from where it stands; and
        |     $next->ended says how, for the caller (D34).
        v
  the run has ended; what's still waiting is handed out
```

A stage that returns several values hands out the first, and the rest
wait, on a stack, each with the stage it waits at, so the order of
values is kept. Nothing is run early so that a run can end (D22).

### 5.2 How each part learns how the run ended

- **`died`:** the run died: a stage, a flush, the source or a set-up.
- **`stopped`:** its input was cut short: a stop came at or after it
  while it still had values to come, or the run was ended from
  outside before its input ran out.
- **`done`:** its input ran out, and the run didn't die. A part whose
  input ran out before a stop is `done`, whatever follows it (D20). A
  sink that stops the run itself is `done`, and its flush gives its
  result (D16). A source that throws a stop is `done`, and what it
  carries is its last (D16).

Here, `noisy_count` before and after `take(2)`:

```perl
my $next = Ekorn::Pipeline->new(noisy_count('before'), take(2), noisy_count('after'))
    ->iterator(noisy(1 .. 5));
say 'result: ', join ', ', $next->();
# source: done
# before: done
# after: done
# result: 1
```

`noisy_count('before')` held back every value, so `take(2)` saw only
its result, 5, and `noisy_count('after')` counted that one value.
Every part's input ran out, so each is `done`. With `take(2)` first,
the stop comes while the source still has values:

```perl
my $next = Ekorn::Pipeline->new(take(2), noisy_count('after'))->iterator(noisy(1 .. 5));
say 'result: ', join ', ', $next->();
# source: stopped
# after: done
# result: 2
```

### 5.3 The bookkeeping

The verdicts of section 5.2 come from two flags and a pointer, kept by
each run in `_iterator`, and one decision made when the run ends:

- **`$source_done`,** set when the source returns an empty list, or
  throws a stop of its own.
- **`@input_done`,** a flag for each stage, set once the stage has had
  all its input.
- **`$next_flush`,** a pointer into the stages: every stage before it
  has been passed by the flushes, or cut off by a stop.

They're set in three places:

- **As the flushes run.** Once the source is done, the flushes are
  called in order, first stage first. Before the flush at stage *n*,
  `$input_ran_out->(n)` marks every stage from `$next_flush` to *n*:
  everything upstream of them has run out and been flushed, so their
  input is complete. As the run ends normally, `$end_if_ended` marks
  the rest, to the last stage.
- **At a stop.** A stop at stage *n* means the source isn't pulled
  again, and moves `$next_flush` to *n* + 1, or to *n* for a sink that
  stopped the run itself, as its flush is still to come. Of the stages
  it passes over, those whose input had run out are marked, by
  `$input_ran_out_at_stop`: only once nothing more can come from
  upstream, and only up to the first that still has a value waiting
  for it, or a flush before it still to be called. The rest aren't:
  their input was cut short. Nor is the source, unless it had already
  run out.
- **From outside.** `finish`, or an iterator let go, moves
  `$next_flush` past the last stage, marking nothing more.

When the run ends, `$finish` decides each verdict, once:

- **the run died:** every end is told `died`;
- **otherwise:** the source is `done` if `$source_done` is set, else
  `stopped`; each stage is `done` if its flag in `@input_done` is set,
  else `stopped`;
- **and for the caller,** `$ended`, which the iterator's `ended`
  returns once the iterator has given all it will, been finished or
  died: `died` if the run died, `stopped` if `finish` dropped values
  still to be handed out, else the source's verdict. It becomes `died`,
  and nothing more is handed out, if an end dies as the run
  finishes.

So the design's rule, `done` if its input ran out and `stopped` if it
was cut short, is "was this part's flag set before the run ended?"

The second example of section 5.2, `take(2)` before the sink, goes so:

| Step | What happens | `$source_done` | `@input_done`: take, after | `$next_flush` |
|---|---|---|---|---|
| pull 1 | 1 goes through `take` and `after` | no | no, no | 0 |
| pull 2 | `take` passes 2 and throws a stop | no | no, no | 1, passing over `take` |
| flush | `after`'s flush, its input complete | no | no, **yes** | 2 |
| end | nothing can act: the run ends | no: `stopped` | `take` has no end; `after`: `done` | |

And with the stop after the sink, as D20 has it, every part's input
runs out first:

```perl
my $next = Ekorn::Pipeline->new(noisy_count('sink'), take(1))->iterator(noisy(1 .. 3));
say 'result: ', join ', ', $next->();
# source: done
# sink: done
# result: 3
```

| Step | What happens | `$source_done` | `@input_done`: sink, take | `$next_flush` |
|---|---|---|---|---|
| pulls 1 to 3 | each goes into the sink, which holds it | no | no, no | 0 |
| pull 4 | an empty list: the source has run out | **yes** | no, no | 0 |
| flush | the sink's, giving 3; its input is complete | yes | **yes**, no | 1 |
| stop | `take(1)` passes 3 and throws a stop: nothing waits for it, and no flush comes before it | yes | yes, **yes** | 2 |
| end | nothing can act: the run ends | yes: `done` | the sink: `done`; `take`: `done`, had it an end | |

Had the sink given two values, the second would still have been
waiting for `take` as it stopped, and `take`, cut short, would be
`stopped`.

### 5.4 When flushes and ends run

- **A flush** is called once its part's input runs out normally: the
  values ran out, a stop came in a stage before it, or a sink stopped
  the run itself. Its values go on, with `ending()` true. A gather that
  stops the run isn't flushed, as in v0.2.0.
- **An end** is called once, when the run has ended, and told how.
  With a sink last, that's as soon as its result is ready, before it's
  handed out, so a sink committing on `done` commits then:

```perl
my $next = Ekorn::Pipeline->new(to_array)->iterator(noisy(qw(a b c)));
say $next->();
say $next->();
# source: done
# a
# b
```

- **An end that dies** while the run is already dying is a warning
  naming it, and the first error is kept. One that dies as the run ends
  normally is thrown, once the rest, told `died`, have run (section 8).

### 5.5 Ending a run from outside

An iterator not read to its end is ended by its `finish` method, which
takes no verdict of its own, or as it's let go. Each part is told how
from where it stands, and what was still to be handed out is dropped.

```perl
my $next = Ekorn::Pipeline->new(stage {uc})->iterator(noisy(qw(a b c)));
say $next->();
say $next->ended // 'still going';
$next->finish;
say scalar(my @rest = $next->());
say $next->ended;
# A
# still going
# source: stopped
# 0
# stopped
```

`ended` tells the caller whether the source was read to its end:
here, it wasn't. Read to the end, it would say `done`; had anything
died, `died`. Until the iterator is spent or finished, it says
nothing.

```perl
{
    my $next = Ekorn::Pipeline->new(stage {uc})->iterator(noisy(qw(a b c)));
    say $next->();
}
say 'after the block';
# A
# source: stopped
# after the block
```

Called from inside one of its own run's stages, `finish` stops the run
there: no later stage sees the value in flight.

## 6. The components

### 6.1 Ekorn::Pipeline

`new(@stages)` makes a pipeline: each stage a code reference, which it
makes a Stage, a pipeline, whose stages are spliced in, or a part
offering a stage's or a sink's role method. It reads no names.

Called with values, a pipeline pushes them through. In list context it
returns what comes out; in scalar context, how many, unless its last
stage is a scalar sink, when it gives that sink's result (D17).
`iterator($source)` pulls instead: `$source` is a code reference, or
anything offering `ekorn_source`, an iterator included. `stages` returns
the stages, to splice into another pipeline.

A pipeline holds only what it was made of, so one pipeline can run any
number of times, even at once:

```perl
my $counted = Ekorn::Pipeline->new(sub { $_ * 10 }, count);
my $one = $counted->iterator(from_arrayref([1, 2, 3]));
my $two = $counted->iterator(from_arrayref([4, 5]));
say $two->(), ' ', $one->();    # 2 3
```

`ending()` and `run_context()` are what a stage may ask (section
4.2). A pushed run has no context, even one pushed inside a stage of
another run (D24).

`pipeline(...)` and `named(...)` are as built for roadmap 2026-0011 and
2026-0020: `pipeline` exported from Ekorn::Pipeline, and names kept per
class. The design moves `pipeline` to Factories and keeps names per
package; until that's built, see section 10.2.

### 6.2 Ekorn::Pipeline::Iterator

What `iterator` returns: an Element, called as `$next->()`, with
`finish` and `DESTROY` (section 5.5). Its `ekorn_source` makes it a
source to another run, which ends it, through `finish`, when that run
ends, and passes on its context (section 6.8). Once it's spent, having
handed out all it will, been finished, or died, its `ekorn_source`
croaks rather than give nothing (D41); an iterator whose run has ended
with values still to give, such as a list sink's, isn't spent until
they've gone. As a source, it has `|` and `@{}`, once Operators is
loaded, as Ekorn's other sources have.

`ended` tells its caller whether the source was read to its end, once
the iterator has given all it will, been finished or died, and nothing
before (D34, D48): `done` if it was, `stopped` if a stop, or `finish`,
cut the reading short, or `finish` dropped values still to be handed
out, and `died` if anything in it died, an end included. `$finish`
decides it from `$source_done` (section 5.3), and `$end_run` makes it
`stopped` if it dropped values:

```perl
my $all  = Ekorn::Pipeline->new(sub { $_->{title} })->iterator(from_arrayref(\@tracks));
my $some = Ekorn::Pipeline->new(sub { $_->{title} }, take(2))->iterator(from_arrayref(\@tracks));
my @all  = map { $all->() } 1 .. 7;
my @some = map { $some->() } 1 .. 3;
say $all->ended, ' ', $some->ended;    # done stopped
```

### 6.3 Stage, Gather, Source and Sink, and the words

| Word | Class | Its block |
|---|---|---|
| `stage {...}` | `Ekorn::Pipeline::Stage->new($code)` | the stage itself, called with each value |
| `gather {...}` | `Ekorn::Pipeline::Gather->new($setup)` | a set-up, returning the step, or a pipeline, and optionally a flush and an end |
| `source {...}` | `Ekorn::Pipeline::Source->new($setup)` | a set-up, returning the step, and optionally an end and a context |
| `sink {...}` | `Ekorn::Pipeline::Sink->new($setup)` | a set-up, returning the step, the flush, giving a list, and optionally an end |
| `sink_scalar {...}` | `Ekorn::Pipeline::Sink->new_scalar($setup)` | the same, the flush giving one value (D47) |

A set-up declares the run's state with `my`, so two runs of one source
don't share a position, or a filehandle:

```perl
my $countdown = source {
    my $n = 3;
    return sub () { $n > 0 ? $n-- : () };
};
my $first  = Ekorn::Pipeline->new->iterator($countdown);
my $second = Ekorn::Pipeline->new->iterator($countdown);
say $first->(), $first->(), $second->();    # 323
```

A sink's flush gives its result, and its end is told how the run
ended. Here, rows are kept only if the whole run went through, as a
transaction would be, even when it's a stage after the sink that dies:

```perl
my @saved;
my $save = sink_scalar {
    my @pending;
    return (
        sub ($row) { push @pending, $row },
        sub ()     { scalar @pending },
        sub ($how) { push @saved, @pending if $how eq 'done' },
    );
};

say Ekorn::Pipeline->new($save)->(1, 2, 3);                                 # 3
eval { Ekorn::Pipeline->new($save, sub { die "Later\n" })->(4, 5) };
say "saved: @saved";                                                        # saved: 1 2 3
```

A sink can go anywhere: its result goes on through the stages after
it. `to_array` passes on what it holds, once it has it all, and
`count` one number:

```perl
say join ', ', Ekorn::Pipeline->new(to_array, stage {uc})->(qw(a b));    # A, B
say Ekorn::Pipeline->new(count, sub {"$_ tracks"})->(@tracks);            # 6 tracks
```

A Stage wraps the code given and never blesses it; it refuses one of
Ekorn's own types, as a gather made a Stage would run per value.

Called directly, each type does what its role means (D42). A Sink
called with values pushes them through a fresh sink of its set-up, as
a pipeline of the one sink would, and gives its result, so a sink can
be tested on its own; the closure holds the set-up, not the sink, so a
code reference taken from a sink keeps working after the sink has
gone. A Source called directly croaks, as a run of its own would never
be ended:

```perl
say count->(1, 2, 3);                      # 3
say join ', ', to_array->(qw(a b));        # a, b
eval { from_arrayref([1])->() };
print $@ =~ s( \ at\ \S+\ line\ \d+ )( at LINE)xr;
# Expected a source to be read through iterator at LINE.
```

### 6.4 Gather and Stop

As in v0.2.0, a gather's set-up returns its step, and optionally a
flush, which v0.2.0 called its end function; it may now return an end
too, told how the run ended. A stop carries values on:

```perl
use Ekorn::Pipeline::Stages::Batch;
say join ' ', map {"[@$_]"} Ekorn::Pipeline->new(batch(2))->(1 .. 5);    # [1 2] [3 4] [5]
```

### 6.5 Ekorn::Pipeline::Sources

| Source | Gives |
|---|---|
| `from_arrayref(\@array)` | the array's values, from the first, each run |
| `from_file($path)` | the file's records, as `$/` divides them, with `$/` taken off; the file is opened as the run starts, and closed as it ends |

```perl
my $next = Ekorn::Pipeline->new(take(2))->iterator(from_file($setlist));
while (my($line) = $next->()) { say $line }
# Parklife
# Song 2
```

### 6.6 Ekorn::Pipeline::Sinks

| Sink | Role | Gives |
|---|---|---|
| `all_items` | list | every item, as a list |
| `only_item` | scalar | the one item; `undef` if none; at a second, a warning, and the run stops, giving the first |
| `count` | scalar | how many values there were |
| `first_item` | scalar | the first value, stopping the run there; `undef` if there were none |
| `to_array` | list | every value, as a list |
| `to_arrayref`, `to_arrayref(\@array)` | scalar | an array reference of every value: your array, filled, or a new one |
| `to_file($path)` | scalar | writes each value, then `$/`, giving how many; opened as the run starts, closed as it ends |

The sinks taking no arguments have an empty prototype, so `count + 0`
reads as `count() + 0`. `to_file` writes `$/` after each value, so what
`from_file` reads, `to_file` writes back unchanged; in paragraph mode,
`$/` set to `""`, it writes a blank line after each.

```perl
my($copied) = Ekorn::Pipeline->new(to_file("$dir/copy.txt"))->iterator(from_file($setlist))->();
say $copied;    # 3

my $next = Ekorn::Pipeline->new->iterator(from_file("$dir/copy.txt"));
while (my($line) = $next->()) { say $line }
# Parklife
# Song 2
# Tender
```

### 6.7 Ekorn::Pipeline::Operators

`use Ekorn::Pipeline::Operators` puts `|` and `@{}` in force for the
rest of its scope, marking it in `%^H`; `no Ekorn::Pipeline::Operators`
takes them out. Used where they aren't in force, they croak, rather
than Perl's `|` quietly ORing two addresses (Q23). Loaded, the module
gives Ekorn's sources `|` and `@{}`, and its stages, gathers and sinks
`|`:

| Written | Gives |
|---|---|
| `$source \| $stage` | a chain: a source of the values from `$source` through the stage |
| `$source \| ... \| $sink` | a scalar sink's result, at once; a list sink, such as `to_array`, croaks: use `to_arrayref` |
| `$stage \| $stage` | a chain of stages: a pipeline, of a subclass that has `\|` |
| `@{ $source }` | every value the source gives, as an array |

```perl
my $titles = from_arrayref(\@tracks) | stage { $_->{title} };
say $titles | count;                                        # 6
say join ', ', @{ $titles | take(2) | to_arrayref };        # Dancing Queen, Knowing Me, Knowing You

my $clean = stage { s( \A \s+ | \s+ \z )()xgr } | stage {uc};
say join ',', $clean->(' a ', 'b ');                        # A,B
say join ',', @{ from_arrayref([' c']) | $clean };          # C
```

A chain from a source is a Source made for a run, whose set-up makes
an iterator of its stages over its source, so it can be used again, as
`$titles` is. A chain must start with a source or a stage made with a
word: started with a plain code reference, Perl calls no overload, or,
when the right side is typed, `chain` croaks. `|` binds more loosely
than `.` and `+`, so put a chain inside a larger expression in
parentheses:

```perl
say 'Blur: ' . (from_arrayref(\@tracks) | stage { $_->{artist} eq 'Blur' ? $_ : () } | count);    # Blur: 3
```

`chain($left, $right, $swapped)` and `drain($source)` are what `|` and
`@{}` call. A package whose sources are objects of its own class gives
them `|` and `@{}` by overloading them with these (section 7.4).

### 6.8 A complete pipeline as a source

An iterator is a source, so one pipeline can read from another. When
the inner one ends in a sink, it gives the sink's result, and, nothing
following the sink, its run ends as the result is ready:

```perl
my $lines = Ekorn::Pipeline->new(stage {uc}, to_array)->iterator(noisy(qw(a b c)));
my $next  = Ekorn::Pipeline->new(take(2))->iterator($lines);
while (my($line) = $next->()) { say $line }
# source: done
# A
# B
```

Without the sink, the inner run is pulled only as needed, and ended,
as from outside, when the outer run ends. That's as `take(2)` stops on
B, before B is handed out, as nothing in the outer run can act on it:

```perl
my $lines = Ekorn::Pipeline->new(stage {uc})->iterator(noisy(qw(a b c d)));
my $next  = Ekorn::Pipeline->new(take(2))->iterator($lines);
while (my($line) = $next->()) { say $line }
# A
# source: stopped
# B
```

### 6.9 Pipes, the canned stages and Errors

Unchanged from v0.2.0, except that Errors' `@INTERNAL` lists the new
modules, so their errors are reported at the caller's line. Pipes still
has `pipeline_class`, which the design drops (section 10.2). The canned
stages made with `gather` are Gathers, and so Elements; those written
as plain subs, such as `take_while`, are still plain subs.

## 7. Building on Ekorn as it is

This is the pattern DBIx::Squirrel follows, and any package that hands
out values can: deliver parts that offer Ekorn's role methods, and let
users run them in Ekorn's pipelines, with Ekorn's parts and their own.
Nothing of Ekorn's is subclassed or wrapped. A source needs nothing of
Ekorn's loaded; the sink in 7.5 uses Ekorn's `sink_scalar` word, for
brevity, where a class with `ekorn_sink_scalar` would need nothing
either; and the overloads in 7.4 load Operators, whose functions they
name. The role methods are named for Ekorn (D49), so an object with
an ordinary method such as `as_list` is never taken for a part.

The example below is a stand-in for DBIx::Squirrel, with an in-memory
table where it would have a statement, so it runs without a database.
The examples in this section follow on from each other: each `package
My::Rows` block adds to the class.

| Here | In DBIx::Squirrel | The protocol it keeps |
|---|---|---|
| `My::Rows`, with `ekorn_source` | a statement's rows (design 12.3) | a source, giving its columns as the run's context |
| `column($name)` | `pluck`, `as_hash` (design 12.7) | a stage, asking `run_context()` |
| `insert_into($table)` | `insert_into` (design 12.4) | a sink |
| `each_row($rows, @stages)` | `iterate`, and the like | a function taking stages |
| `use overload '\|', '@{}'` | its statements, for `\|` and `@{}` | Operators' `chain` and `drain` |

### 7.1 A source of its own, that knows something

`ekorn_source` starts a run, as executing a statement would, and returns
its step, its end, which finishes it, and a context, what its stages
may need to know about this run:

```perl
package My::Rows {
    sub new ($class, $columns, @rows) { bless {columns => $columns, rows => \@rows}, $class }

    sub ekorn_source ($self) {
        my $i = 0;    # the run's position, as a statement's cursor
        return (
            sub ()     { $i < @{ $self->{rows} } ? $self->{rows}[ $i++ ] : () },
            sub ($how) { say "rows: $how" },         # where a statement would finish
            {columns => [ @{ $self->{columns} } ]},  # this run's
        );
    }
}
```

```perl
my $people = My::Rows->new([qw(id name)], [1, 'Ann'], [2, 'Bo'], [3, 'Cy']);
say scalar Ekorn::Pipeline->new(count)->iterator($people)->();
# rows: done
# 3
```

### 7.2 A function that takes stages

A function of the package's own, running its values through its
caller's stages, finds them with `is_stage`, or takes a pipeline given
last, and runs them with `new`:

```perl
package My::Rows {
    sub each_row ($rows, @stages) {
        return Ekorn::Pipeline->new(@stages)->iterator($rows);
    }
}
```

```perl
my $people = My::Rows->new([qw(id name)], [1, 'Ann'], [2, 'Bo']);
my $next   = My::Rows::each_row($people, sub { $_->[1] }, take(1));
say $next->();
# rows: stopped
# Ann
```

`take(1)` stopped the run at the first row, which went on, as a stop's
values do. Nothing more in the run could act on a value, so it ended
there, telling the source `stopped`, before the row was handed out.

### 7.3 A stage that asks about its run

A stage that needs to know about the values' source, as `pluck` needs
a statement's column names, asks `run_context()`:

```perl
package My::Rows {
    sub column ($name) {
        return sub ($row) {
            my $columns = Ekorn::Pipeline::run_context()->{columns};
            my($at) = grep { $columns->[$_] eq $name } 0 .. $#$columns;
            return $row->[$at];
        };
    }
}
```

```perl
my $people = My::Rows->new([qw(id name)], [1, 'Ann'], [2, 'Bo']);
my $next   = Ekorn::Pipeline->new(My::Rows::column('name'), stage {uc})->iterator($people);
while (my($name) = $next->()) { say $name }
# ANN
# BO
# rows: done
```

Behind an iterator, a stage sees the context of the run inside it, so
`column` works in a pipeline reading from another pipeline over the
rows.

### 7.4 `|` and `@{}` for its own sources

Operators gives `|` to Ekorn's own types. A package's class gets it by
overloading `|` and `@{}` with Operators' `chain` and `drain`, loading
Operators with an empty import list, which defines them without putting
the operators in force in the package's own scope. They're in force
where the line using them was compiled with `use
Ekorn::Pipeline::Operators`, as section 2's is:

```perl
package My::Rows {
    use Ekorn::Pipeline::Operators ();
    use overload
        '|'   => \&Ekorn::Pipeline::Operators::chain,
        '@{}' => \&Ekorn::Pipeline::Operators::drain;
}
```

```perl
my $people = My::Rows->new([qw(id name)], [1, 'Ann'], [2, 'Bo'], [3, 'Cy']);
say join ', ', @{ $people | My::Rows::column('name') | take(2) | to_arrayref };
say scalar @{$people};
# rows: stopped
# Ann, Bo
# rows: done
# 3
```

### 7.5 A sink of its own

A sink is made with `sink {...}`, or as a class of the package's own
offering `ekorn_sink_scalar` or `ekorn_sink`. Its flush gives its result, and its
end, told how the run ended, commits or rolls back:

```perl
package My::Rows {
    use Ekorn::Pipeline::Factories qw(sink_scalar);

    sub insert_into ($table) {
        return sink_scalar {
            my @pending;    # as a transaction begun
            return (
                sub ($row) { push @pending, $row },
                sub ()     { scalar @pending },
                sub ($how) { push @$table, @pending if $how eq 'done' },    # commit, or not
            );
        };
    }
}
```

```perl
my @archive;
my $people = My::Rows->new([qw(id name)], [1, 'Ann'], [2, 'Bo']);
say $people | stage { [$_->[0], uc $_->[1]] } | My::Rows::insert_into(\@archive);
say join ', ', map { $_->[1] } @archive;
# rows: done
# 2
# ANN, BO
```

### 7.6 Errors at the user's line

A package that croaks puts Ekorn's `@INTERNAL` in its `@CARP_NOT`, so
that a mistake is reported at its user's line, not inside Ekorn.

## 8. Errors

A stage that dies ends the run. Its error is thrown again, wrapped
with the stage's place in the pipeline, and the line that called it:

```perl
eval { Ekorn::Pipeline->new(sub {$_}, sub { die "No plays\n" })->(1) };
print $@ =~ s( \ at\ \S+\ line\ \d+ )( at LINE)xr;
# Pipeline stage #2 failed at LINE:
#     No plays
```

Every end is told `died` first, the source's first. An end that dies
while that happens is a warning naming it, and the first error is
kept:

```perl
my $fails = sink_scalar {
    return (sub ($value) { die "First\n" }, sub () {0}, sub ($how) { die "Second\n" });
};
local $SIG{__WARN__} = sub ($warning) { print $warning =~ s( \ at\ \S+\ line\ \d+ )( at LINE)xr };
eval { Ekorn::Pipeline->new($fails)->iterator(noisy(1))->() };
print $@ =~ s( \ at\ \S+\ line\ \d+ )( at LINE)xr;
# source: died
# The end of stage #1 died while the run was already dying: Second at LINE.
# Pipeline stage #1 failed at LINE:
#     First
```

An end that dies as the run ends normally is thrown, once the ends
after it are told `died`, as "Pipeline end of the source failed" or
"Pipeline end of stage #2 failed", with its message.

The messages the new code adds, to be settled when the design's items
are built:

| Message | When |
|---|---|
| `Expected stage #%d to be a stage, not a source` | a part offering only `ekorn_source`, given to `new` as a stage |
| `Expected stage #%d to offer one of ekorn_stage, ekorn_sink_scalar and ekorn_sink, not %s` | a part offering more than one |
| `Expected the source to return a code reference, and optionally an end and a context` | `ekorn_source` returns anything else |
| `Expected stage #%s to return a code reference, and optionally a flush and an end` | `ekorn_stage` returns anything else |
| `Expected sink #%s to return a code reference, a flush, and optionally an end` | `ekorn_sink_scalar` or `ekorn_sink` returns anything else |
| `Expected a source to be read through iterator` | a source called as a code reference |
| `Expected no stop in a set-up, as the run has nothing yet to stop` | a stop thrown from a set-up: a gather's block, `ekorn_source`, or a role method |
| `Expected no stop in an end, as the run has ended` | a stop thrown from an end, inside "Pipeline end of ... failed", or the warning when the run is already dying |
| `Expected a source with values still to give: an iterator is one run, and this one is spent` | a spent iterator given as a source |
| `Expected a source, or a stage made with a word, on the left of \|` | `chain` given anything else on its left |
| `Expected a stage or a sink on the right of \|` | `chain` given what can't go where a stage goes |
| `Expected a sink giving one value at the end of \|, not a list: use to_arrayref, not to_array` | a chain ending in a list sink |
| `Expected use Ekorn::Pipeline::Operators in scope, for %s` | `\|` or `@{}` where the operators aren't in force |
| `Pipeline end of %s failed` | an end dying as the run ends normally |
| `The end of %s died while the run was already dying: %s` | a warning |
| `Can't read %s: %s`, `Can't write %s: %s` | `from_file`, `to_file` |

## 9. What the tests prove

`t/15-proofs.t` holds the design's proofs (its section 19), its
settled decisions, and the pattern of section 7. Every other test file
passes. All but three are unchanged from before the prototype: `t/02`
and `t/03` changed with Elements (D4), and `t/03` and `t/11` with a
gather's end (D12), which made a third value from a gather's block
valid, as v0.3.0 changes.

| Subtest | Proves | Design |
|---|---|---|
| 19.1, six subtests | a source joined directly to a sink: the copy; the ends, the source's first; `first_item`'s stop; a sink that can't be set up, or dies; both forms agreeing | 19.1, 5.3, 5.4, D11 |
| A sink commits only if the whole run went through | a stage dying after it; the source's end dying first; a pulled sink committing as its result is ready | D6, D11, D15 |
| An end that dies | the warning naming it; the rest told `died` | 5.4, D27 |
| How each part is told the run ended | `done` for input that ran out; a source that stops; ended from outside | 5.3, D16, D20, D22 |
| 19.2, eight subtests | a complete pipeline as a source; abandoned; finished, taking no verdict; finished from inside a stage | 19.2, 5.5, D15, D28 |
| The caller asks how the run ended | `ended`: nothing while it goes; `done`, `stopped`, `died` | 5.5, D34 |
| A spent iterator is no source for another run | read in part, it goes on; spent or finished, it croaks; ended with values still to give, it gives them | 4.2, D41 |
| A part called directly | a sink gives its result, tested on its own; a source croaks; `is_sink` | D42, D43 |
| Fixes from the fourth review | a stop from an end or a set-up an error, not a raw stop; an iterator chaining and draining; a spent or died iterator refused; a pipeline made with `new` with no `\|`; a sink's code reference outliving it | D16, D23, D32, D41, D42 |
| Sinks and context | `to_arrayref`, and `to_array` croaking at the end of a chain; scalar context; a scalar sink of nothing; precedence | D10, D17, D25 |
| Chains | chains of stages; `@{}`; a plain code reference on the left; `\|` where Operators isn't in force | 9, D14, D23, Q23 |
| Ekorn's types are Elements, offering role methods | Stages made of code; each type's role; a source as a stage; a part with two stage-place roles | D4, D5, D13, D19 |
| A package delivers parts, using Ekorn as it is | section 7's pattern: `ekorn_source` with a context, `run_context()` behind an iterator, each run's own, none in a pushed run; `chain` and `drain` | D1, D5, D7, D24 |

## 10. Design and implementation, side by side

Two lists. The first takes each part of the design and says whether
the code does it. The second takes what the code does that the design
doesn't say, or says otherwise. A change to either side changes a row
here; a row that's out of date is drift.

Status: **built** as the design says; **built, differs**, with how;
**not built**; **not code**, for what's a rule or a plan.

### 10.1 The design, part by part

| Design | What it says | Status |
|---|---|---|
| 2 | the stream concept applied to functions (D26) | built: sections 3 and 7 |
| 3, principle 1 | opt-in, in layers | built: Operators in force only where used (Q23); the lifecycle touches only what's made for a run |
| 3, principle 2 | other packages use Ekorn as it is | built: section 7 and its test |
| 3, principle 3 | the contract is the protocols | built: section 4.2 |
| 3, principle 4 | words in Factories | built, differs: `stage`, `source`, `sink`, `sink_scalar` and `gather` are there; `pipeline` is still in Ekorn::Pipeline (D30) |
| 3, principle 6 | every type an Element; `is_stage` by the role methods (D13) | built |
| 3, principle 8 | nothing that works today changes, but by v0.3.0's changes | built: every existing test passes; three changed with v0.3.0's changes (section 9) |
| 4.2 | the six types; a sink usually last, its result going on | built: section 6.3 |
| 4.2, 19.2 | a complete pipeline, pulled, is a source, its run ending as its result is ready | built: section 6.8 |
| 4.2 | a pipeline holds no source; a source joined to one is a source (D33) | built: `new` refuses a source as a stage; a chain and an iterator are sources |
| 4.3 | push and pull; a scalar sink's result in scalar context (D17) | built |
| 4.4 | the protocols, by role methods (D5), with a context (D7); one stage-place method (D19); a scalar sink giving one value (D25) | built |
| 5.2 | made for a run by role methods; set-ups as the run starts (D21) | built |
| 5.3 | how each part is told the run ended (D20) | built |
| 5.4 | a flush and an end (D6, D12); a run ends when nothing can act (D15, D22); the source's end first (D11); an end dying during a die warns, naming it (D27); stops from a source, a flush, an end (D16) | built |
| 5.5 | an abandoned iterator ends its run (D28); `finish` takes no verdict, and drops what's left | built |
| 5.5 | the caller asks how the run ended, `$next->ended`: whether the source was read to its end, said once spent (D34, D48) | built |
| 4.4, 12.7 | a context describes the run's source, not the values (D46) | built |
| 5.6 | `ending()`, true while a flush runs and its values go on | built |
| 6.1 | Element, and the Stage, Gather, Source, Sink classes | built: Sink's roles by its subclasses, Scalar and List |
| 6.1 | `pipeline_in` (D37) | not built |
| 6.2 | the words, `sink` for a list sink and `sink_scalar` for a scalar one (D47) | built, differs: no `pipeline` in Factories |
| 7 | names per package | built, differs: names are still per class, as 2026-0020 built them |
| 8.1 | canned stages as objects (Q12, settled by D4) | built, differs: those made with `gather` are; `take_while`, `drop_while` and the taps written as plain subs aren't |
| 8.2 | sources | built: `from_arrayref`, `from_file`. Not built: `from_array`, `from_fh`, `from_hash`, `from_hashref`, `counter`, `unfold`, `cycle`, `concat`, `interleave` |
| 8.3 | sinks, in two families (D50) | built: `all_items`, `first_item`, `only_item`, `count`, `to_array`, `to_arrayref`, `to_file`. Not built: `last_item`, `any_item`, `every_item`, `fold`, `joined`, `group_by`, `for_each`, `to_fh`, `to_hash`, `to_hashref` |
| 9 | chains from a source or a stage (D14, D23); a list sink croaking at the end (D10); `chain` and `drain` for a package's class; in force lexically (Q23) | built |
| 9 | `\|=` | built: Perl makes it from `\|` |
| 10 | Sugar | not built |
| 12 | DBIx::Squirrel as a user of Ekorn | built, as a stand-in: section 7 |
| 12.7 | a stage asks `run_context()` (D7, D24) | built |
| 13 | v0.3.0, on this branch until then | not code |
| 13 | a pipeline's name in its stages' errors joins v0.3.0 (D40) | not built |
| 14 | `pipeline`'s `import`, names per class and `pipeline_class` go | not built: all three are still there |
| 4.2 | a spent iterator croaks as a source (D41) | built |
| 3, principle 6 | each type, called directly, does what its role means (D42) | built |
| 11.1 | `is_sink`, on request (D43) | built |
| 19 | the proofs | built: section 9 |

### 10.2 The code, where the design doesn't say, or says otherwise

| The code | Design | To do |
|---|---|---|
| Names per class, `pipeline` exported from Ekorn::Pipeline with its own `import`, and Pipes' `pipeline_class` are still in the code | 7, 14, D30 say they go | built when the design is split into items |
| `iterator`'s message for what isn't a source is still v0.2.0's "Expected a code reference", though it takes sources; a gather's is still "...and optionally an end function", though a gather may return a flush and an end | the reference draft's diagnostics | change with the messages, at v0.3.0 (the design's section 20) |
| `to_file` in paragraph mode writes a blank line after each record | 8.3 says `$/` | say so, or change it |
| An end's error from `DESTROY` is a warning, "(in cleanup)", as Perl gives every error in a destructor | 5.4: thrown | say so: a run ended as its iterator is let go can't throw |
| Ends run during global destruction, in no set order | 5.5 warns of it | nothing |

## 11. Known gaps

- **Coverage is below the floors** on this branch, in the new modules'
  error paths and their POD, which is a placeholder in each. CI doesn't
  run on `pipeline-experimental`. Each item the design is split into
  brings its part up to the floors.
- **The new modules have no documentation** beyond this, the design,
  and its draft reference and how-to sections.
- **The error messages** in section 8 aren't settled, and aren't yet in
  any DIAGNOSTICS.
