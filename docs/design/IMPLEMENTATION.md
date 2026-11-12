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
   sinks and stages of its own, without subclassing or wrapping
   anything of Ekorn's (section 7).
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
  data in section 2, and prints what its comments say. Check them
  before committing a change to them, as the how-to's are checked.
- **It says what the code does, plainly, even where that's wrong.**
  A behaviour that's a bug, or that the design doesn't want, is
  described as it is, and listed in section 10.2 until it's fixed.

## 2. The examples' data

Every example below runs after this block. It loads what the examples
use, the tracks the how-to uses, a file of three lines, and two parts
that say how their run ended, so the examples can show it: `noisy`, a
source, and `noisy_count`, a sink.

```perl
use v5.36;
use Ekorn::Pipeline;
use Ekorn::Pipeline::Factories qw(stage source sink gather);
use Ekorn::Pipeline::Sources   qw(from_arrayref from_file);
use Ekorn::Pipeline::Sinks     qw(count first_value to_array to_file);
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
        my @left = @values;
        return (sub () { @left ? shift @left : () }, sub ($how) { say "source: $how" });
    };
}

# A sink counting its values, saying how its run ended.
sub noisy_count ($label) {
    return sink {
        my $n = 0;
        return (sub ($value) { $n++; return }, sub ($how) { say "$label: $how"; $n });
    };
}
```

## 3. In a nutshell

A **pipeline** is a list of **stages**. Values go in, one at a time;
each stage turns a value into none, one or several; what comes out of
the last stage is the result.

Values come in two ways. **Pushed**, the pipeline is called with them.
**Pulled**, it's given a **source**, a function giving the next value
each time it's called, and returns an **iterator**, which pulls from
the source only as it needs to.

```perl
my $blur = Ekorn::Pipeline->new(sub { $_->{artist} eq 'Blur' ? $_ : () }, sub { $_->{title} });

say join ', ', $blur->(@tracks);    # Girls & Boys, Parklife, Country House

my $next = $blur->iterator(from_arrayref(\@tracks));
say $next->();                      # Girls & Boys
```

A **sink** is a stage that holds back every value, and gives a result
at its end. Last in a pipeline, its result is what the run gives:

```perl
say Ekorn::Pipeline->new(sub { $_->{plays} > 6000 ? $_ : () }, count)->(@tracks);    # 3
```

What's new on this branch is the **lifecycle**: a source or sink that
opens something is **made for a run**, afresh each time, and **told how
the run ended**, `done`, `stopped` or `died`, however it ended, so it
can close or commit or roll back:

```perl
my($n) = Ekorn::Pipeline->new(take(2), count)->iterator(noisy(1 .. 5))->();
say $n;
# source: stopped
# 2
```

`take(2)` stopped the run after two values, so the source was told
`stopped`, and read no further. `count`, after the stop, saw its
stream end normally, so it was told `done` and gave its count.

## 4. Architecture

### 4.1 The modules

```
                         your code, and packages built on Ekorn
                                         |
       +---------------------------------+------------------------------+
       |                                 |                              |
  Operators (|)                 Sources, Sinks                 Stages::Flow, ::Batch,
  opt-in: gives                 ready-made parts               ::Taps: ready-made
  Source objects |              (from_file, to_file,           stages (take, batch,
       |                         count, first_value...)         peek...)
       |                                 |                              |
       +--------------+------------------+                              |
                      |                                                 |
               Factories: the words                                     |
               stage, source, sink, gather                              |
                      |                                                 |
       +--------------+-------------+-------------+                     |
       |              |             |             |                     |
     Stage         Source         Sink         Gather <-----------------+
   (wraps a     (a set-up for  (a set-up for  (a set-up for a
    stage)       each run)      each run)      stage and an end)
       |              |             |             |
       +--------------+------+------+-------------+
                             |
                     Ekorn::Pipeline: the core
              new, iterator, the run loop, the lifecycle,
                   ending(), run_source(), names
                             |
          Element   Iterator   Stop   Errors   Pipes
```

Each layer uses only those below it. Nothing below Factories knows the
words; nothing below Operators knows `|`. The core knows the classes
only by what they can do: an object with a `for_run` method is made
for a run, whatever its class (section 4.2).

| Module | Layer | What it holds |
|---|---|---|
| `Ekorn::Pipeline` | core | the pipeline class; `new`, `iterator`, `stages`, `named`, `pipeline`; the run loop and the lifecycle; `ending()`, `run_source()`, `is_stage` |
| `Ekorn::Pipeline::Element` | core | the base of every type: a hash, called as a code reference, which says whether it goes where a stage goes |
| `Ekorn::Pipeline::Iterator` | core | what `iterator` returns: called for each value, it ends its run when it's let go, or when it's told to |
| `Ekorn::Pipeline::Stop` | core | `Stop(...)`, and `throw`, which end a run early from inside a stage |
| `Ekorn::Pipeline::Gather` | core | `gather {...}`: a stage made for a run, with an end that lets out what it held |
| `Ekorn::Pipeline::Errors` | core | `croakf`, and `@INTERNAL`, the packages Carp looks past |
| `Ekorn::Pipeline::Pipes` | core | `pipe` and `tap`, for a class's objects to run themselves through stages |
| `Ekorn::Pipeline::Stage` | 1 | a stage as an object, wrapping a code reference |
| `Ekorn::Pipeline::Source` | 1 | a source made for each run, from a set-up |
| `Ekorn::Pipeline::Sink` | 1 | a sink made for each run, from a set-up |
| `Ekorn::Pipeline::Factories` | 1 | the words: `stage`, `source`, `sink`, `gather` |
| `Ekorn::Pipeline::Sources` | 2 | `from_arrayref`, `from_file` |
| `Ekorn::Pipeline::Sinks` | 2 | `count`, `first_value`, `to_array`, `to_file` |
| `Ekorn::Pipeline::Operators` | 3 | `\|` for Ekorn's sources, and `chain`, for a class of sources of its own |
| `Ekorn::Pipeline::Stages::Flow`, `::Batch`, `::Taps` | parts | `take`, `drop`, `take_while`, `drop_while`; `batch`, `collect`; `peek`, `count_into`, `dump_to` |

### 4.2 The protocols the core relies on

These are the protocols as the code checks them. Some are by what a
thing can do, `can('for_run')` above all; but many are by Ekorn's own
classes: the core asks `isa` of Ekorn::Pipeline (to splice it),
Gather, Source (refused as a stage), Stage (to unwrap it), Iterator (as
a source), Element (in `is_stage`) and Stop; and Operators asks it of
Sink and Chain. So a part of a package's own, which isn't one of
Ekorn's classes, can't yet take every role an Ekorn part can (section
10.2, and decision D5 in 2026-0022's record):

| Protocol | As the core checks it | What it must do |
|---|---|---|
| **Stage** | a code reference, or an Element whose `goes_as_stage` is true (`is_stage`) | called with one value, in `$_` and `$_[0]`, return a list |
| **Pipeline as a stage** | `isa Ekorn::Pipeline` | its stages are spliced in where it's given |
| **Source** | a code reference, or made for a run | called with nothing, return the next value or values, or an empty list when there are no more |
| **Made for a run** | a blessed object that `can('for_run')` | `for_run` returns a step, a code reference, and an end, a code reference or nothing. Given as a stage, it must also be a stage: an Element, or a code reference; one that's neither is taken only as a source |
| **Sink** | a stage made for a run | its step returns nothing, as Ekorn's sinks' do, though what it returns would go on; its end is called with how the run ended, and, when `done`, returns the result |
| **Stop** | an exception `isa Ekorn::Pipeline::Stop` | thrown from a stage, it ends the run; values it carries go on through the stages after it |
| **An iterator as a source** | `isa Ekorn::Pipeline::Iterator` | the outer run ends it, with `finish($how)` |
| **What a stage may ask** | `Ekorn::Pipeline::ending()`, `Ekorn::Pipeline::run_source()` | true while values come from an end; the run's source, as it was given |

A sink and a stage made for a run are the same thing to the core: a
stage whose object has `for_run`. Ekorn::Pipeline::Sink is one; a
package's own class with `for_run` is another.

### 4.3 Every type is an Element

Every type Ekorn makes, the pipeline included, is an object of a
class built on Ekorn::Pipeline::Element: a hash holding what it was
made with, and a `call` field, the closure that does its work. Element
overloads `&{}` to return that closure, so an Element is called as a
code reference, `$element->(...)`, or with its `call` method. The
closure never refers to the object, so the object is freed as soon as
nothing else holds it.

```
Ekorn::Pipeline::Element          call, &{}, goes_as_stage
  ├─ Ekorn::Pipeline::Stage       wraps a code reference
  ├─ Ekorn::Pipeline::Gather      a set-up: step, and an end told nothing
  ├─ Ekorn::Pipeline::Sink        a set-up: step, and an end told how
  ├─ Ekorn::Pipeline::Source      a set-up: step, and an end told how
  ├─ Ekorn::Pipeline::Iterator    a run: call pulls, finish ends it
  └─ Ekorn::Pipeline              a list of stages: call pushes values
```

`goes_as_stage` says whether an Element can go where a stage goes. It's
true unless a class says not, as Source and Iterator do, and it's what
`is_stage` asks of an Element. A plain code reference is a stage too,
and `new` makes it a Stage, so a pipeline is made of Elements only.
A run calls a Stage's code as it is, so wrapping costs nothing per
value.

```perl
my $double   = sub { $_[0] * 2 };    # $_ is set only in a run
my $pipeline = Ekorn::Pipeline->new($double);
my($stage)   = $pipeline->stages;
say ref $stage;                                        # Ekorn::Pipeline::Stage
say $stage->code == $double ? 'the same code' : '';    # the same code
say ref(\&$stage), ' ', join ',', $stage->(4);         # CODE 8
```

An Element isn't a code reference to code that checks the type, with
`ref` or Ref::Util's `is_coderef`. Inside Ekorn, `is_stage` and
`iterator` ask what a thing can do instead.

Element is how Ekorn builds its own types. A package built on Ekorn
doesn't subclass it: it keeps the protocols of section 4.2, as
section 7 shows.

## 5. A run, step by step

A **run** is one call of a pipeline with values, or one iterator made
from it. Everything below happens once per run.

### 5.1 The flow

```
  $pipeline->iterator($source)
        |
        |  1. Set up
        |     the source: for_run, if it's made for a run; an iterator
        |       is used as it is, and ended with finish; a code
        |       reference has no end
        |     the stages, in order: a gather's block is called; a stage
        |       made for a run (a sink) has for_run called; others are
        |       used as they are
        |     if a set-up dies, what's set up already is told "died"
        v
  an Iterator, $next
        |
        |  2. Each $next->() pulls until a value comes out, or the run
        |     has ended:
        |
        |     a value waiting?  ---- yes ---> run it through the stages
        |        | no                         from where it waits
        |        v
        |     source not done?  ---- yes ---> pull; an empty list means
        |        | no                         done; else run the first
        |        v                            value, the rest wait
        |     an end to call?   ---- yes ---> call it: a gather's with
        |        | no                         nothing, a sink's with
        |        v                            "done"; what it returns
        |     finish the run                  goes on through the
        |     and return nothing              stages after it
        |
        |  3. Finish (once): each sink not yet called is told how the
        |     run ended, first stage first, then the source's end, last
        v
  the run has ended
```

A value that comes out of the last stage is handed out at once. A
stage that returns several values hands out the first, and the rest
wait, on a stack, each with the stage it waits at, so the order of
values is kept.

### 5.2 How each part learns how the run ended

From where it stands, as section 5.3 of the design says:

| The run | The source, and stages up to the one that stopped | Stages after the one that stopped |
|---|---|---|
| ran out of values | `done` | `done` |
| was stopped by a stage | `stopped` | `done` |
| had a stage, an end or the source die | `died` | `died` |
| was ended from outside: `finish`, or let go | `stopped`, or what `finish` was given | the same |

And one exception: **a sink that stops the run is told `done`,** and
its end's result goes on, as it's what decided the run had enough.
That's how `first_value` works.

Here, `noisy_count` before and after `take(2)`:

```perl
my $next = Ekorn::Pipeline->new(noisy_count('before'), take(2), noisy_count('after'))
    ->iterator(noisy(1 .. 5));
say 'result: ', join ', ', $next->();
# before: done
# after: done
# source: done
# result: 1
```

Nothing stopped the source here: `noisy_count('before')` held back
every value, so `take(2)` saw only its result, 5, and passed it on,
and `noisy_count('after')` counted that one value. A sink is a stage
like any other, and what follows it gets its result. With `take(2)` first, the stop comes while values are still
flowing:

```perl
my $next = Ekorn::Pipeline->new(take(2), noisy_count('after'))->iterator(noisy(1 .. 5));
say 'result: ', join ', ', $next->();
# after: done
# source: stopped
# result: 2
```

A sink before a stop is never told `stopped`: it holds back every
value, so nothing after it runs until the source has run out, and a
stop after it can't cut the source off. A sink is told `stopped` only
when its run is ended from outside (section 5.4).

What's before a stop and *is* told `stopped` is a stage made for a run
whose step passes values on. The core doesn't ignore what a sink's
step returns: it goes on, as any stage's does, so `sink {...}` with a
step that returns its value is a stage whose end always runs:

```perl
my $passing = sink {
    return (sub ($value) {$value}, sub ($how) { say "passing: $how"; return });
};
my $next = Ekorn::Pipeline->new($passing, take(2))->iterator(noisy(1 .. 5));
say join ', ', $next->(), $next->(), $next->();
# passing: stopped
# source: stopped
# 1, 2
```

### 5.3 When ends run

- **A gather's end** runs when its stage's stream ended normally: the
  values ran out, or a stop came in a stage before it. Its values go
  on through the stages after it. After a stop at or after it, or a
  die, it isn't called. Unchanged from v0.2.0.
- **A sink's end** always runs, once. Told `done`, it runs in the same
  sequence as gathers' ends, first stage first, and what it returns
  goes on. Otherwise it runs when the run finishes, and what it
  returns is dropped.
- **The source's end** runs last, once every stage's end has been
  called. That's as soon as no end is left, which can be before every
  value from the ends has been handed out: a pipeline ending in
  `to_array` has finished with its source at its first value.
- **An end that dies** while the run is already dying is reported as
  a warning, and the first error is kept. One that dies as the run
  ends normally is thrown, once the rest, told `died`, have run.

```perl
my $next = Ekorn::Pipeline->new(to_array)->iterator(noisy(qw(a b c)));
say $next->();
say $next->();
# source: done
# a
# b
```

### 5.4 Ending a run from outside

An iterator that isn't read to its end can be ended by calling its
`finish` method, or by letting it go: its `DESTROY` calls `finish`.
Either way, its sinks and source are told `stopped`, unless `finish`
was given something else, and it hands out nothing more.

```perl
my $next = Ekorn::Pipeline->new(stage {uc})->iterator(noisy(qw(a b c)));
say $next->();
$next->finish;
say scalar(my @rest = $next->());
# A
# source: stopped
# 0
```

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

## 6. The components

### 6.1 Ekorn::Pipeline

`new(@stages)` makes a pipeline: each stage a code reference, which
it makes a Stage, a pipeline, whose stages are spliced in, or an
Element that goes where a stage goes. It croaks if given a source as a
stage. It reads no names.

Called with values, a pipeline pushes them through, and returns what
comes out. `iterator($source)` pulls instead: `$source` is a code
reference, an Iterator, or any object made for a run. `stages`
returns the stages, as Elements, to splice into another pipeline.

A pipeline holds only what it was made of. Everything a run needs is
made by `_iterator` when the run starts (section 5.1), so one pipeline
can run any number of times, even at once:

```perl
my $counted = Ekorn::Pipeline->new(sub { $_ * 10 }, count);
my $one = $counted->iterator(from_arrayref([1, 2, 3]));
my $two = $counted->iterator(from_arrayref([4, 5]));
say $two->(), ' ', $one->();    # 2 3
```

`ending()` is true while the values going through the stages came from
an end. `run_source()` returns the source the run was given, as it was
given, for a stage to ask what it knows (section 7.3). Pushed, a run's
source is a closure over the values, and has nothing to tell.

`pipeline(...)` and `named(...)` are as built for roadmap 2026-0011 and
2026-0020: `pipeline` exported from Ekorn::Pipeline, and names kept per
class. The design moves `pipeline` to Factories and keeps names per
package; until that's built, see section 10.2.

### 6.2 Ekorn::Pipeline::Iterator

What `iterator` returns: an Element, called as `$next->()` as before,
with `finish($how)` and `DESTROY` (section 5.4).
Given to another pipeline's `iterator` as its source, it's ended by
that run, through `finish` (section 6.8).

### 6.3 Stage, Source and Sink, and the words

Each class takes one code reference, and the words in Factories are
one line over each:

| Word | Class | Its block |
|---|---|---|
| `stage {...}` | `Ekorn::Pipeline::Stage->new($code)` | the stage itself, called with each value |
| `source {...}` | `Ekorn::Pipeline::Source->new($setup)` | a set-up, run at the start of each run, returning the step and, optionally, the end |
| `sink {...}` | `Ekorn::Pipeline::Sink->new($setup)` | a set-up, returning the step and the end |
| `gather {...}` | `Ekorn::Pipeline::Gather`'s `gather` | a set-up, returning the step and, optionally, an end with no arguments |

A set-up declares the run's state with `my`, and returns closures that
share it. So two runs of one source don't share a position, or a
filehandle:

```perl
my $countdown = source {
    my $n = 3;
    return sub () { $n > 0 ? $n-- : () };
};
my $first  = Ekorn::Pipeline->new->iterator($countdown);
my $second = Ekorn::Pipeline->new->iterator($countdown);
say $first->(), $first->(), $second->();    # 323
```

A sink's end is told how the run ended. Here, rows are kept only if
every one went through, as a database's transaction would be:

```perl
my @saved;
my $save = sink {
    my @pending;
    return (
        sub ($row) { push @pending, $row; return },
        sub ($how) {
            push @saved, @pending if $how eq 'done';
            return scalar @pending;
        },
    );
};

say Ekorn::Pipeline->new($save)->(1, 2, 3);                                       # 3
eval { Ekorn::Pipeline->new(sub { $_ == 5 ? die "Bad row\n" : $_ }, $save)->(4, 5) };
say "saved: @saved";                                                              # saved: 1 2 3
```

A sink can go anywhere: its result goes on through the stages after
it. `to_array` passes on what it holds, once it has it all, and
`count` one number:

```perl
say join ', ', Ekorn::Pipeline->new(to_array, stage {uc})->(qw(a b));      # A, B
say Ekorn::Pipeline->new(count, sub {"$_ tracks"})->(@tracks);              # 6 tracks
```

A Stage wraps the code given; it never blesses it, so a named sub
given to `stage` is left as it was. A Source called directly, as a
code reference, outside a run, makes a run of its own and steps it,
but that run is never ended. A Sink called directly croaks: it has no
meaning outside a run.

### 6.4 Gather and Stop

As in v0.2.0, except that a Gather is an Element, made by
`Ekorn::Pipeline::Gather->new($setup)`, which `gather` calls. Called,
it calls its set-up, as the core does at the start of each run. A
gather's set-up returns its step, and optionally an end called with
nothing; a stop carries values on:

```perl
use Ekorn::Pipeline::Stages::Batch;
say join ' ', map {"[@$_]"} Ekorn::Pipeline->new(batch(2))->(1 .. 5);    # [1 2] [3 4] [5]
```

### 6.5 Ekorn::Pipeline::Sources

| Source | Gives |
|---|---|
| `from_arrayref(\@array)` | the array's values, from the first, each run |
| `from_file($path)` | the file's records, as `$/` divides them, with `$/` taken off; the file is opened when the iterator is made, and closed when the run ends, however it ends |

```perl
my $next = Ekorn::Pipeline->new(take(2))->iterator(from_file($setlist));
while (my($line) = $next->()) { say $line }
# Parklife
# Song 2
```

### 6.6 Ekorn::Pipeline::Sinks

| Sink | Gives |
|---|---|
| `count` | how many values there were |
| `first_value` | the first value, stopping the run there |
| `to_array` | every value, as a list; with `\|`, an array reference |
| `to_file($path)` | writes each value, then `$/`, giving how many; opened when the iterator is made, closed when the run ends |

`to_file` writes `$/` after each value, so what `from_file` reads,
`to_file` writes back unchanged. In paragraph mode, `$/` set to `""`,
it writes a blank line after each, as `chomp` took off every newline
there was.

```perl
my($copied) = Ekorn::Pipeline->new(to_file("$dir/copy.txt"))->iterator(from_file($setlist))->();
say $copied;    # 3

my $next = Ekorn::Pipeline->new->iterator(from_file("$dir/copy.txt"));
while (my($line) = $next->()) { say $line }
# Parklife
# Song 2
# Tender
```

A sink that gives a list is marked when it's made,
`Ekorn::Pipeline::Sink->new($setup, list => 1)`, as `to_array` is. The
mark matters only to `|` (section 6.7), and `sink {...}` makes a sink
giving one value.

### 6.7 Ekorn::Pipeline::Operators

Loading it gives Ekorn's sources `|`, and nothing else gets it:

| Written | Gives |
|---|---|
| `$source \| $stage` | a chain: a new source, of the values from `$source` through the stage |
| `$chain \| $stage` | a longer chain |
| `$source \| ... \| $sink` | the sink's result, at once: one value, or, for a sink giving a list, an array reference |

```perl
use Ekorn::Pipeline::Operators;

my $titles = from_arrayref(\@tracks) | stage { $_->{title} };
say $titles | count;                       # 6
say ref($titles | take(2) | to_array);     # ARRAY
say join ', ', @{ $titles | take(2) | to_array };    # Dancing Queen, Knowing Me, Knowing You
```

A chain is itself a Source made for a run, whose set-up makes an
iterator of its stages over its source, and whose end finishes that
iterator. So a chain can be used again, as `$titles` is above, and
every chain's run is ended as any other source's is.

Perl calls an overload only when the left side is an object with one,
so the chain must start with a source, and only `|` is built: not a
stage joined to a stage, `|=` or `@{}`. A plain code reference can
follow a source, as the left side is the object.

`chain($left, $right, $swapped)` is the function `|` calls. A package
whose sources are objects of its own class gives them `|` by
overloading it with that function (section 7.4).

### 6.8 A complete pipeline as a source

A pipeline pulled from a source is an iterator, and an iterator is a
source, so one pipeline can read from another. When the inner one ends
in a sink, it gives the sink's result:

```perl
my $lines = Ekorn::Pipeline->new(stage {uc}, to_array)->iterator(noisy(qw(a b c)));
my $next  = Ekorn::Pipeline->new(take(2))->iterator($lines);
while (my($line) = $next->()) { say $line }
# source: done
# A
# B
```

The inner run read everything at the first pull, and ended, telling
its source `done`, before the outer run had its first value. The outer
`take(2)` then stopped the outer run, which told its source, the inner
iterator, `stopped`; but that run had ended, so nothing more was told.
Without `to_array`, the inner run is pulled only as needed, and the
outer stop reaches its source:

```perl
my $lines = Ekorn::Pipeline->new(stage {uc})->iterator(noisy(qw(a b c d)));
my $next  = Ekorn::Pipeline->new(take(2))->iterator($lines);
while (my($line) = $next->()) { say $line }
# A
# B
# source: stopped
```

### 6.9 Pipes, the canned stages and Errors

Unchanged from v0.2.0, except that Errors' `@INTERNAL` lists the new
modules, so their errors are reported at the caller's line. Pipes still
has `pipeline_class`, which the design drops (section 10.2).

## 7. Building on Ekorn as it is

This is the pattern DBIx::Squirrel follows, and any package that hands
out values can: deliver parts that keep the protocols of section 4.2,
and let users run them in Ekorn's pipelines, with Ekorn's parts and
their own. Nothing of Ekorn's is subclassed or wrapped, and Ekorn needs
to know nothing about the package.

The example below is a stand-in for DBIx::Squirrel, with an in-memory
table where it would have a statement, so it runs without a database.
Each piece maps to something DBIx::Squirrel has or plans:

| Here | In DBIx::Squirrel | The protocol it keeps |
|---|---|---|
| `My::Rows`, with `for_run` and `columns` | a statement's rows (design 12.3) | made for a run, as a source |
| `column($name)` | `pluck`, `as_hash` (design 12.7) | a stage, asking `run_source()` |
| `insert_into($table)` | `insert_into` (design 12.4) | a sink |
| `each_row($rows, @stages)` | `iterate`, and the like | a function taking stages |
| `use overload '\|'` | its statements, if it wants `\|` | Operators' `chain` |

### 7.1 A source of its own, that knows something

A class whose objects have `for_run` is a source made for a run. Its
set-up is `for_run` itself: it starts the run, as executing a
statement would, and returns the step and the end, which finishes it.
The examples in this section follow on from each other: each `package
My::Rows` block adds to the class.

```perl
package My::Rows {
    use Ekorn::Pipeline::Errors qw();
    our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

    sub new ($class, $columns, @rows) { bless {columns => $columns, rows => \@rows}, $class }
    sub columns ($self)               { @{ $self->{columns} } }

    sub for_run ($self) {
        my $i = 0;    # the run's position, as a statement's cursor
        return (
            sub ()     { $i < @{ $self->{rows} } ? $self->{rows}[ $i++ ] : () },
            sub ($how) { say "rows: $how" },    # where a statement would finish
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
caller's stages, finds them as any user of Ekorn does, and runs them
with `new`. It never reads names: a caller who uses one turns it into
a pipeline with `pipeline`, where they wrote it.

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
say 'next pull';
$next->();
# Ann
# next pull
# rows: stopped
```

`take(1)` stopped the run at the first row, which went on, as a stop's
values do. The source is told when the run finishes, after the stages
have finished with what it gave: here, at the next pull, which finds
nothing more. Had the iterator been let go instead, it would have been
told then.

### 7.3 A stage that asks its source

A stage that needs to know about the values' source, as `pluck` needs
a statement's column names, asks `run_source()`, and calls the
source's own methods. Ekorn hands over the source as it was given, and
knows nothing of what it can do.

```perl
package My::Rows {
    sub column ($name) {
        return sub ($row) {
            my @columns = Ekorn::Pipeline::run_source()->columns;
            my($at) = grep { $columns[$_] eq $name } 0 .. $#columns;
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

In a pipeline that reads from another, a stage sees its own run's
source: for the outer pipeline, that's the inner iterator.

### 7.4 `|` for its own sources

Operators gives `|` to Ekorn's sources only. A package's class gets it
by overloading `|` with Operators' `chain`, which takes any source made
for a run on its left:

```perl
package My::Rows {
    use Ekorn::Pipeline::Operators;
    use overload '|' => \&Ekorn::Pipeline::Operators::chain;
}
```

```perl
my $people = My::Rows->new([qw(id name)], [1, 'Ann'], [2, 'Bo'], [3, 'Cy']);
say join ', ', @{ $people | My::Rows::column('name') | take(2) | to_array };
# rows: stopped
# Ann, Bo
```

### 7.5 A sink of its own

A sink is made with `sink {...}`, or as a class of the package's own
with `for_run`. Its end is told how the run ended, to commit or roll
back:

```perl
package My::Rows {
    use Ekorn::Pipeline::Factories qw(sink);

    sub insert_into ($table) {
        return sink {
            my @pending;    # as a transaction begun
            return (
                sub ($row) { push @pending, $row; return },
                sub ($how) {
                    return 0 unless $how eq 'done';    # as a rollback
                    push @$table, @pending;            # as a commit
                    return scalar @pending;
                },
            );
        };
    }
}
```

```perl
my @archive;
my $people = My::Rows->new([qw(id name)], [1, 'Ann'], [2, 'Bo']);
say $people | sub { [$_->[0], uc $_->[1]] } | My::Rows::insert_into(\@archive);
say join ', ', map { $_->[1] } @archive;
# rows: done
# 2
# ANN, BO
```

### 7.6 Errors at the user's line

A package that croaks puts Ekorn's `@INTERNAL` in its `@CARP_NOT`, as
`My::Rows` does in 7.1, so that a mistake is reported at its user's
line, not inside Ekorn.

## 8. Errors

A stage that dies ends the run. Its error is thrown again, wrapped
with the stage's place in the pipeline, and the line that called the
pipeline:

```perl
eval { Ekorn::Pipeline->new(sub {$_}, sub { die "No plays\n" })->(1) };
print $@ =~ s( \ at\ \S+\ line\ \d+ )( at LINE)xr;
# Pipeline stage #2 failed at LINE:
#     No plays
```

What's made for a run is told `died` first, the source last. An end
that dies while that happens is a warning, keeping the first error
(the warning has the line of the call that ran the pipeline):

```perl
my $fails = sink {
    return (sub ($value) { die "First\n" }, sub ($how) { die "Second\n" });
};
local $SIG{__WARN__} = sub ($warning) { print $warning =~ s( \ at\ \S+\ line\ \d+ )( at LINE)xr };
eval { Ekorn::Pipeline->new($fails)->iterator(noisy(1))->() };
print $@ =~ s( \ at\ \S+\ line\ \d+ )( at LINE)xr;
# An end died while the run was already dying: Second at LINE.
# source: died
# Pipeline stage #1 failed at LINE:
#     First
```

The messages the new code adds, to be settled when the design's items
are built:

| Message | When |
|---|---|
| `Expected stage #%d to be a stage, not a source` | a Source given to `new` as a stage |
| `Expected the set-up of a source to return a code reference, and optionally an end` | a source's set-up returns anything else |
| `Expected the set-up of a sink to return a code reference and an end` | a sink's set-up returns anything else |
| `Expected a sink to be run in a pipeline` | a sink called as a code reference |
| `Expected a source on the left of \|` | `chain` given something on its left that isn't made for a run, or is a sink |
| `Expected a stage or a sink on the right of \|` | `chain` given a source, or what isn't a stage, on its right |
| `Can't read %s: %s`, `Can't write %s: %s` | `from_file`, `to_file` |
| `An end died while the run was already dying: %s` | a warning (section 5.3) |

## 9. What the tests prove

`t/15-proofs.t` holds the design's proofs (its section 19) and the
pattern of section 7. Every other test file passes. All but two are
unchanged from before the prototype; `t/02` and `t/03` changed with
Elements, as v0.3.0 changes (section 10.1), so v0.2.0's behaviour is
otherwise kept. Some subtests below assert the prototype's behaviour
where the design has since settled otherwise, such as the source's end
running last: section 10 says which.

| Subtest | Proves | Design |
|---|---|---|
| 19.1 it copies, and gives how many records | `from_file` to `to_file`, pulled and with `\|` | 19.1 |
| 19.1 a last line without a newline gains one | `to_file` writes `$/` after each record | 8.3 |
| 19.1 run out: both told done, the source last | the ends, their order | 5.3, 5.4, Q5 |
| 19.1 stopped by first_value | one pull; the source told `stopped` | 5.3, 8.3 |
| 19.1 a sink that can't be set up | the source told `died` | 5.4 |
| 19.1 a sink that dies on a value | both told `died`; the error thrown | 5.3 |
| 19.1 both forms agree | `\|` and `iterator` give the same result and ends | 9, 19.1 |
| An end that dies (Q6), two subtests | the warning; the rest told `died` | 5.4, Q6 |
| 19.2 the inner run ends at the first pull | the source's end as soon as no end is left | 4.2, 19.2 |
| 19.2 a die in the outer run doesn't reach the inner | | 19.2 |
| 19.2 a result of one value is a source of one value | | 19.2 |
| 19.2 without a sink, the inner run is pulled only as needed | an iterator as a source, ended through `finish` | 19.2 |
| 19.2 abandoned, it ends | `DESTROY` | 5.5, Q7 |
| 19.2 ended by finish, it stops | nothing more pulled or handed out | 5.5 |
| 19.2 with \|, a chain of a complete pipeline is a result | `to_array` gives a reference | 9 |
| Ekorn's types are Elements | each type an Element; a code reference given to `new` made a Stage; what goes where a stage goes | principle 6, 6.1 |
| A package delivers parts, using Ekorn as it is | section 7's pattern: `for_run`, `run_source()`, `chain` | 3 (principles 2, 3), 12, Q21 |

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
| 3, principle 1 | opt-in, in layers | built: Operators changes nothing until loaded, then for the whole program (D8, open); the lifecycle touches only what's made for a run |
| 3, principle 2 | other packages use Ekorn as it is | built, as far as the code's protocols allow: section 7 and its test; see principle 3 |
| 3, principle 3 | the contract is the protocols | built, differs: the core still tells roles apart by Ekorn's classes (10.2, D5, D13) |
| 3, principle 4 | words in Factories | built, differs: `stage`, `source`, `sink` and `gather` are there; `pipeline` is still in Ekorn::Pipeline |
| 3, principle 6 | every type an Element; `is_stage` by the role methods (D13) | built, differs: `is_stage` asks an Element `goes_as_stage` |
| 3, principle 8 | nothing that works today changes | built: every existing test passes; `t/02` and `t/03` changed with Elements, as v0.3.0 changes (the 13 row); `iterator` returns an object, called as a code reference (Q7) |
| 4.2 | the six types; a sink usually last, its result going on | built: section 6.3 |
| 4.2 | a complete pipeline, pulled, is a source, its run ending as its result is ready | built: section 6.8 |
| 4.3 | push and pull | built |
| 4.3 | a pushed run in scalar context gives a scalar sink's result (D17) | built, differs: it gives how many results came out, so `count` last gives 1 |
| 4.4 | the protocols, by role methods, with a context for each run | built, differs: `for_run` for every role, no context; adds an iterator as a source, ended by `finish` |
| 4.4 | an object offers at most one of `as_stage`, `as_scalar`, `as_list` (D19) | not built: no role methods yet (D5) |
| 5.2 | made for a run, by one method per role (D5) | built, differs: one method, `for_run`, for every role |
| 5.2 | set-ups run when the run starts (D21) | built |
| 5.3 | told how it ended, from where it stands; a part whose input had run out is `done` (D20) | built, differs: ended from outside, every unended part is told `stopped`, even one whose input ran out; after a stop, such a part is told `stopped` or `done` by what follows it (10.2) |
| 5.4 | a flush and an end for everything made for a run (D6, D12) | built, differs: a sink has one end, giving its result and told how; a gather has no end told how |
| 5.4 | a run ends when nothing can act on a value (D15) | built, differs: a sink's end runs when its own input runs out, the source's when no end is left, and a pulled run's otherwise at the next pull, or as it's let go |
| 5.4 | the source's end first (D11, Q5) | built, differs: last |
| 5.4 | ends wait for the stages, nothing run early; `finish` drops what's still to be handed out (D22) | built |
| 5.4 | an end dying during a die warns, naming the end (Q6) | built, differs: the warning doesn't say which end |
| 5.4 | a stop from a source, a flush or an end (D16) | built, differs: a stop from a source goes to the caller as an object, and the source is told `died` |
| 5.5 | an abandoned iterator ends its run (Q7); `finish` takes no verdict | built, differs: `finish` takes any verdict (10.2) |
| 5.6 | `ending()`, true while a flush runs and its values go on, a sink's result included (D16) | built |
| 6.1 | Element, and the Stage, Gather, Source, Sink classes and constructors | built, differs: Element has `goes_as_stage`; Sink takes `list => 1` |
| 13 | Gather an Element; `stages` returns Elements | built: two tests in `t/02` and `t/03` changed with it |
| 6.1 | `pipeline_in` (Q10) | not built |
| 6.2 | the words | built, differs: no `pipeline` in Factories; a sink's set-up returns two closures, not three |
| 7 | names per package | built, differs: names are still per class, as 2026-0020 built them |
| 8.1 | canned stages as objects (Q12) | not built: they're gathers and code references, as in v0.2.0 |
| 8.2 | sources | built: `from_arrayref`, `from_file`. Not built: `from_array`, `from_fh`, `from_hash`, `from_hashref`, `counter`, `unfold`, `cycle`, `concat`, `interleave` |
| 8.3 | a scalar sink gives one value, `undef` if it has none (D25) | built, differs: `first_value` with no values gives nothing |
| 8.3 | sinks; `to_arrayref` gives an array reference (D10) | built: `count`, `first_value`, `to_array`, `to_file`. Not built: `to_arrayref`, `to_fh`, `to_hash`, `to_hashref`, `group_by`, `last_value`, `any_value`, `every_value`, `fold`, `joined`, `for_each` |
| 9 | a chain starts with a typed source or stage; a package's class overloads `\|` with `chain`, and `@{}` with `drain` (D14, D23) | built, differs: only a source starts one; no chain of stages; no `drain` |
| 9 | sinks taking no arguments have an empty prototype | built, differs: `count` and the rest don't, so `$src \| count + 0` dies |
| 9 | a chain ending in a list sink croaks (D10) | built, differs: it gives an array reference |
| 9 | `\|` between stages; `\|=`; `@{}` | not built |
| 9 | a chain ending in a sink is a result, not a source | built |
| 10 | Sugar | not built |
| 11.1 | the modules | built for those above; Sugar not built |
| 12 | DBIx::Squirrel as a user of Ekorn | built, as a stand-in: section 7 |
| 12.7, Q21 | a stage asks for its run's context, `run_context()` (D7); a pushed run has none (D24) | built, differs: `run_source()` gives the source object, and Ekorn's closure in a pushed run |
| 13 | v0.3.0, on this branch until then | not code |
| 14 | `pipeline`'s `import`, names per class and `pipeline_class` go | not built: all three are still there |
| 17 | decisions | not code |
| 19 | the proofs | built, differs: `t/15` asserts the prototype's order of ends, the source's last, where D11 has it first |
| Q13 | `is_source` | built, differs: not needed; `iterator` takes anything made for a run |
| Q19 | the proving code kept | not code, open |
| Q20, Q22 | re-exports; names in errors | not code |

### 10.2 The code, where the design doesn't say, or says otherwise

Each of these is for the design to take in, or the code to change.
2026-0022's change record has the findings at more length. Rows marked
"build" are settled in the design, and wait for the code.

| The code | Design | To do |
|---|---|---|
| One method, `for_run`, serves every role, and the core tells roles apart by Ekorn's classes and by position: a package's own blessed-code source given as a stage is taken for a sink, and crashes; its own sink under `\|` gives a chain, which never runs; its hash-based sink is refused; Ekorn's own Sink is taken as a source. A list sink is marked by `Sink->new($setup, list => 1)`, and a sink's step's return goes on | D5: one method per role, `as_source`, `as_stage`, `as_scalar`, `as_list`; a sink's step's return ignored | build D5 |
| `is_stage` asks an Element `goes_as_stage`, so a package's own object with `as_scalar` would be refused by `new` | D13: `is_stage` by the role methods | build D13 |
| A sink has one end, giving its result and told how; a gather's end is v0.2.0's, with no end told how | D6, D12: a flush and an end for everything made for a run | build D6, D12 |
| A sink's end runs when its own input runs out; the source's when no end is left, though values from ends may still be coming; a pulled run's otherwise at the next pull, or as it's let go, when an end's error becomes a warning | D15: a run ends when nothing in it can act on a value | build D15 |
| The source's end runs last | D11: first | build D11 |
| `run_source()` gives the source object, shared by every run; Ekorn's closure in a pushed run, and in a pushed run inside a stage; undefined in ends called as the run finishes; an intermediate iterator when there is one | D7, D24: a context for each run, from `as_source`, asked for with `run_context()`; a pushed run has none | build D7, D24 |
| `\|` ending in `to_array` gives an array reference; `to_arrayref` and `to_hashref` aren't built | D10 | build D10 |
| A pushed run in scalar context gives how many results came out, so `count` last gives 1 | D17: a scalar sink's result | build D17 |
| A `Stop` thrown by a source goes to the caller as an object, and the source is told `died` | D16: it ends the source's values, which is told `done` | build D16 |
| Ended from outside, every part not yet ended is told `stopped`, even one whose input ran out, such as a source that had returned empty while a gather's flush was still giving values | 5.3, 5.5: `done` for a part whose input ran out | fix |
| `finish($how)` takes any verdict: `finish('done')` on a half-read run tells the sink `done`, so it commits a partial run | 5.5: `finish` takes no verdict of its own | fix: `finish` takes none |
| After a stop, a part whose input had run out is told `stopped` or `done` by what follows it: `stopped` if a sink is still to flush after the stop, `done` if not; and a stop from a gather's flush tells the source `stopped` | D20: `done`, whatever follows | fix |
| An inner iterator not yet ended, used as a source, is told the outer run's `died`, through `finish` | 5.3: ended from outside, it's `stopped` | fix |
| `first_value` with no values gives nothing | D25: one value, `undef` | build D25 |
| `count`, `first_value` and `to_array` have no empty prototype, so `$src \| count + 0` reads as `count(+0)`, and dies | 9: an empty prototype | fix |
| `\|` can't start with a stage, and there's no `drain` for a package's own `@{}` | D23 | build D23 |
| `finish` called from inside one of the run's own stages tells the sink `stopped`, then calls its step again with the value in flight | not said | decide: refuse it, or stop at once |
| An error from a source's end is wrapped as a stage's failure, with an empty stage name and a warning, when a sink is last; thrown as it is when there are no ends; a warning from `DESTROY` | 5.4: thrown, after the rest are told `died` | fix with D11 and D15 |
| The warning for an end that dies during a die doesn't say which end | Q6: it does | fix |
| `Stage->new` takes any object overloading `&{}`, a Gather included, which then runs per value | not said | refuse what isn't a plain stage |
| An iterator given as a source is ended by the outer run, with `finish`, which `DESTROY` also calls | 4.4 says an iterator passes on its context, but not how it's ended | add to 4.4 |
| `iterator` takes any object with `for_run`, not only code references | Q13 asks for `is_source` | settle Q13 so |
| Loading Operators gives every Source `\|`, everywhere in the program | principle 1 and 17.11 say opt-in | D8 |
| An Iterator given as a source to a second run gives nothing, with no error: there's no reusable source of a sink's result | 4.2 and 9 point to `iterator` for one | D9 |
| A Source given as a stage croaks | no message in the diagnostics | add one |
| A Source called directly, outside a run, makes a run of its own, never ended | principle 6 says every type works as a code reference | say what it means for a source |
| A Sink called directly croaks | as above | as above |
| `to_file` in paragraph mode writes a blank line after each record | 8.3 says `$/` | say so, or change it |
| Names per class, `pipeline` exported from Ekorn::Pipeline with its own `import`, and Pipes' `pipeline_class` are still in the code | 7, 14 say they go | built when the design is split into items |

## 11. Known gaps

- **Coverage is below the floors** on this branch, in the new modules'
  error paths and their POD, which is a placeholder in each. CI doesn't
  run on `pipeline-experimental`. Each item the design is split into
  brings its part up to the floors.
- **The new modules have no documentation** beyond this, the design,
  and its draft reference and how-to sections.
- **The error messages** in section 8 aren't settled, and aren't yet in
  any DIAGNOSTICS.
