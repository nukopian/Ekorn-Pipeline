# Ekorn::Pipeline reference

<!-- stopwords: 21st -->

Stages for any function: let the caller finish the job.

A function that hands out values takes a list of *stages* from its
caller, as its last arguments, and runs each value through them. A
stage can change a value, drop it, or turn it into several, and can
stop the pipeline early, so that the function makes no more values
than its caller wants.

This reference describes every module, function and method, and how a
pipeline behaves, with examples; [the how-to](HOWTO.md) shows how to do
common tasks with them, one recipe at a time. Notes marked **For stage
authors** are for those writing stages for others, and
[Writing stages](#writing-stages) brings them together. Each module's
own POD says the same things more briefly, and is the authority where
the two differ.

Ekorn::Pipeline needs Perl 5.36 or later. Its version is 0.x, so the
interface may still change before 1.0, but the version says when it
can: a release that only fixes or adds moves the last number, as
v0.1.1, and one that changes how stages behave, or drops or renames a
name, moves the middle one, as v0.2.0. [Changes](../Changes) says what
each release changed.

## Contents

- [At a glance](#at-a-glance)
- [Terms](#terms)
- [Pipelines: Ekorn::Pipeline](#pipelines-ekornpipeline)
- [How values go through stages](#how-values-go-through-stages)
- [Stopping a pipeline: Ekorn::Pipeline::Stop](#stopping-a-pipeline-ekornpipelinestop)
- [Gathering: Ekorn::Pipeline::Gather](#gathering-ekornpipelinegather)
- [pipe and tap: Ekorn::Pipeline::Pipes](#pipe-and-tap-ekornpipelinepipes)
- [Canned stages](#canned-stages)
- [Errors: Ekorn::Pipeline::Errors](#errors-ekornpipelineerrors)
- [Writing stages](#writing-stages)
- [Writing functions that take stages](#writing-functions-that-take-stages)
- [Diagnostics](#diagnostics)
- [Exports](#exports)
- [The modules](#the-modules)

## At a glance

```perl
use v5.36;
use Ekorn::Pipeline;
use Ekorn::Pipeline::Stop;                                       # Stop
use Ekorn::Pipeline::Gather;                                     # gather
use Ekorn::Pipeline::Stages::Flow qw(:all);                      # take, drop, take_while, drop_while
use Ekorn::Pipeline::Stages::Batch;                              # batch, collect
use Ekorn::Pipeline::Stages::Taps qw(:all);                      # peek, count_into, dump_to

# A pipeline: a list of stages, each a code reference given one value,
# in $_ and as its argument, returning nothing, one value or several.
my $p = Ekorn::Pipeline->new(
    sub { $_ % 3 ? $_ : () },    # filter: drop multiples of 3
    sub { $_ * 10 },             # map: ten times each
    sub { ($_, -$_) },           # flatMap: each, and its negative
);

# Pushed: called with values, it returns what comes out.
say join ' ', $p->(1 .. 4);    # 10 -10 20 -20 40 -40

# Pulled: given a source, it hands out the results one per call.
my $n    = 0;
my $next = Ekorn::Pipeline->new(sub { $_ * $_ }, take(3))->iterator(sub { ++$n });
my @squares;
while (my($square) = $next->()) { push @squares, $square }
say "@squares";    # 1 4 9

# A function of your own, taking stages from its caller.
sub numbers (@stages) { Ekorn::Pipeline->new(@stages)->(1 .. 10) }
say join ' ', numbers(drop(2), take(3));    # 3 4 5
```

## Terms

- **Value:** anything a pipeline is given, or a stage returns. `undef`,
  0 and the empty string are values.
- **Stage:** a code reference, called with one value, returning a list
  of values: none, one or several. A pipeline can also be used as a
  stage (see [A pipeline as a stage](#a-pipeline-as-a-stage)).
- **Pipeline:** a list of stages, made with `Ekorn::Pipeline->new`.
- **Run:** one call of a pipeline with values, or one iterator made
  from it. Stages made with `gather` start afresh on each run.
- **Source:** a code reference an iterator calls for values, returning
  the next value or values, or an empty list when there are no more.
- **Result:** a value that comes out of the last stage.
- **Stop:** the exception a stage throws to end its run early, with
  `Stop` or `Ekorn::Pipeline::Stop->throw`.
- **End function:** a function a `gather` stage can have, called once
  the values run out, whose values go on through the stages after it.

## Pipelines: Ekorn::Pipeline

```perl
use Ekorn::Pipeline;
use Ekorn::Pipeline qw(is_stage);
```

It exports nothing by default, and `is_stage` on request.

### new

```perl
my $p = Ekorn::Pipeline->new(@stages);
```

Returns a pipeline that runs values through `@stages`, in order. Each
stage must be a code reference or a pipeline; anything else croaks,
naming its position: "Expected stage #2 to be a code reference". A stage
can be any code reference: an anonymous `sub`, a reference to a named
one, such as `\&trim`, a stage made by a function, such as `take(10)`,
or one made with `gather`.

With no stages, a pipeline returns its values unchanged.

### A pipeline as a stage

You can give `new` a pipeline wherever it takes a stage. Its stages
are spliced in where it stands:

```perl
my $clean = Ekorn::Pipeline->new(sub { s( \A \s+ | \s+ \z )()xgr }, sub { length ? $_ : () });
say join '|', Ekorn::Pipeline->new($clean, take(2))->(' a ', '  ', 'b ', 'c');    # a|b
```

This runs exactly like `Ekorn::Pipeline->new($clean->stages, take(2))`.
The spliced stages belong to the new pipeline's run, so a `take`
inside `$clean` limits the whole run, not each value. Pipelines can be
nested this way to any depth, and a pipeline of a subclass of
Ekorn::Pipeline works too.

The only difference is in error messages. Given `$clean` itself, a
stage inside it is named by its position in each pipeline: the third
stage of a pipeline given second is `#2.3`, and three levels down,
`#1.2.3`. Given `$clean->stages`, it's named by its position in the
combined list: `#4`, if one stage came before it.

The stages spliced in are whatever the pipeline's [stages](#stages)
method returns, so a subclass can override it. If the override returns
a different list, its stages are named by their position in that list.

To run a pipeline on each value separately instead, call it from a
stage, as
[Calling a pipeline from a stage](#calling-a-pipeline-from-a-stage)
shows.

### Calling a pipeline

```perl
my @results = $p->(@values);
my $count   = $p->(@values);
```

A pipeline is an object that can be called as a code reference. Called
with values, it runs each of them through the stages, in order, and
returns what comes out of the last: in list context, the results; in
scalar context, how many there are.

```perl
my $evens = Ekorn::Pipeline->new(sub { $_ % 2 ? () : $_ });
my @evens = $evens->(1 .. 6);
my $count = $evens->(1 .. 6);
say "@evens, $count of them";    # 2 4 6, 3 of them
```

Each call is a run. A pipeline can be called as often as you like, and
from inside one of its own stages.

### iterator

```perl
my $next = $p->iterator($source);
while (my($result) = $next->()) { ... }
```

Returns a closure handing out, one per call, the values that come out
of the stages, pulling values from `$source` as they're needed.
`$source` is a code reference, called with no arguments, returning the
next value, several values, or an empty list when there are no more. It
croaks "Expected a code reference" if `$source` isn't one.

- The source is called only when a result is wanted, and only once the
  values from its last call have all gone through the stages, so a
  source reading a file, a socket or a database reads no more than its
  caller asks for.
- The closure returns one result per call, and an empty list once the
  results run out, on every call after that. Read it in list context,
  as `my($x) = $next->()`, so that a result of `undef`, 0 or `''` isn't
  taken for the end.
- Once the source has returned an empty list, or a stage has stopped
  the pipeline, the source isn't called again.
- The end functions of `gather` stages are called once the source
  runs out, or after a stop, before the closure returns an empty list.
- If a stage or an end function dies, the call dies with it, and the
  iterator has ended: every call after returns an empty list, nothing
  waiting goes on, no end function is called, and the source isn't
  called again, as when a pushed run dies. So an end such as
  `collect`'s never reports on a run that lost values. To skip a bad
  value and carry on, catch the error inside the stage, as the how-to's
  "Catch errors in a stage, but not a stop" does.

Each iterator is a run of its own, so two iterators from one pipeline
can be read in turn, and each has its own `gather` stages:

```perl
my $numbered = Ekorn::Pipeline->new(gather { my $n = 0; sub { ++$n . $_ } });
my @a = qw(a b);
my @b = qw(x y);
my $first  = $numbered->iterator(sub { @a ? shift @a : () });
my $second = $numbered->iterator(sub { @b ? shift @b : () });
say join ' ', $first->(), $second->(), $first->(), $second->();    # 1a 1x 2b 2y
```

A source that returns `shift @queue // ()` ends at the first `undef` in
the queue; `@queue ? shift @queue : ()` doesn't. A filehandle is read
in scalar context, `sub { scalar(<$fh>) // () }`, so that each call
reads one line.

### stages

```perl
my @stages = $p->stages;
```

Returns the pipeline's stages, in order: a copy, so changing it
changes nothing in the pipeline. A pipeline that was given as a stage
appears as the stages it was made of. In scalar context, it returns how
many there are.

The list can go anywhere stages go, including to a function that
accepts only code references. To give `new` the pipeline itself, see
[A pipeline as a stage](#a-pipeline-as-a-stage).

```perl
my $clean = Ekorn::Pipeline->new(sub { s( \A \s+ | \s+ \z )()xgr }, sub { length ? $_ : () });
say join '|', Ekorn::Pipeline->new($clean->stages, take(2))->(' a ', '  ', 'b ', 'c');    # a|b
```

Either way, the stages run as if they had been written out in full:

- A stop in one of them ends the whole run, and the source isn't called
  again.
- A `gather` stage starts afresh on each run, so pipelines that share
  it, or use it twice, don't share its state. A plain closure is the
  same code reference wherever it goes, so anything it keeps is
  shared. Keep state in `gather` instead.
- A stage that dies is named by its position, as
  [A pipeline as a stage](#a-pipeline-as-a-stage) describes.

Calling a pipeline from a stage is different: each call is a run of
its own, as
[Calling a pipeline from a stage](#calling-a-pipeline-from-a-stage)
explains.

### is_stage

```perl
use Ekorn::Pipeline qw(is_stage);

is_stage($thing)
```

True if `$thing` can be used as a stage: a code reference (including
a stage made with `gather`), or a pipeline of Ekorn::Pipeline or a
subclass. It's the same test [new](#new) uses. It's exported on
request.

Use it in a function that takes its stages from the end of its
arguments, so that it accepts the same stages `new` does, pipelines
included. [Writing functions that take stages](#writing-functions-that-take-stages)
has an example.

```perl
say join ' ', map { is_stage($_) ? 'yes' : 'no' }
    sub { $_ }, take(1), Ekorn::Pipeline->new, 'x', [];    # yes yes yes no no
```

### ending

```perl
Ekorn::Pipeline::ending()
```

True while the values going through the stages come from an end
function, rather than from the source or the values a pipeline was
called with. It isn't exported.

It's for code that tells its stages about the value they're given,
such as the value it came from, which a value an end function makes
doesn't have. DBIx::Squirrel, for instance, tells its stages the row a
value was made from, and has none to tell while `ending` is true.

```perl
my @seen = Ekorn::Pipeline->new(
    collect { scalar @_ },
    sub { Ekorn::Pipeline::ending() ? "count $_" : $_ },
)->(qw(a b c));
say "@seen";    # count 3
```

A pipeline run inside a stage has its own: in a pipeline called from a
stage while `ending` is true, `ending` is false until one of its own
end functions is called.

## How values go through stages

### One value at a time

Each value goes through every stage before the next one starts, as it
would in a `for` loop. So the results come out in order, each stage
sees the values in order, and nothing is held between stages, except by
a stage that holds values itself, such as `batch` or `collect`.

When a stage returns several values, the first goes on through the
rest of the stages, then the second, and so on, before the next value
from the source or the caller:

```perl
my @trace;
Ekorn::Pipeline->new(
    sub { push @trace, "1:$_"; ("$_.1", "$_.2") },
    sub { push @trace, "2:$_"; $_ },
)->(qw(a b));
say "@trace";    # 1:a 2:a.1 2:a.2 1:b 2:b.1 2:b.2
```

### What a stage is given

A stage is called with one value, both as its only argument and in
`$_`, so it can name the value with a signature, `sub ($track) { ... }`,
or leave the signature out and use `$_`, `sub { ... }`.

- `$_` is local to each call, so the caller's `$_` is left as it was,
  and a stage can call code that uses `$_` itself.
- The values a pipeline is called with are copied, so assigning to `$_`
  or `$_[0]` changes the pipeline's copy, not the caller's variable.
- A reference is copied as a reference: a stage that changes the hash
  or array it's given changes the caller's.

> **For stage authors:** a stage is always called with exactly one
> argument, so a signature of one is safe. Don't change the value
> you're given, unless that's what your stage is for and its
> documentation says so: return a new value instead.

### What a stage returns

A stage returns a list, and what it returns is all that goes on:

| It returns | Its kind | What goes on |
|---|---|---|
| an empty list | a filter | nothing: the value is dropped, and the stages after it don't see it |
| one value | a map | that value, in place of the one it was given |
| several values | a flatMap | each of them, in order, through the rest of the stages |

`undef`, 0 and `''` are values, so `return undef` passes on `undef`,
and a stage ending in a test, such as `sub { $_ > 2 }`, passes on what
the test returns, not the value. To drop a value, return an empty list:
`return;` or `()`.

> **For stage authors:** a stage run for its side effects, such as
> logging, returns the value it was given, as `peek` does, or it drops
> it.

### Runs

Each call of a pipeline with values is a run, and so is each iterator
made from it. At the start of each run, the block of every `gather`
stage is called, so what those stages keep starts afresh. An iterator's
run starts when it's made, not when it's first read.

A stage that isn't made with `gather` is the same code reference on
every run, so whatever it keeps in a closure stays there from one run
to the next:

```perl
my $count = 0;
my $plain = Ekorn::Pipeline->new(sub { ++$count });
my @first  = $plain->(qw(a b));
my @second = $plain->(qw(a b));
say "@first / @second";    # 1 2 / 3 4
```

> **For stage authors:** anything a stage keeps, even a count, goes in
> a `gather` block. A stage made once may be given to several
> pipelines, run more than once, or run by two iterators at the same
> time.

### Calling a pipeline from a stage

A stage can run a pipeline of its own, so stages can be built from
stages:

```perl
my $trim = Ekorn::Pipeline->new(sub { s( \A \s+ | \s+ \z )()xgr }, sub { length ? $_ : () });
say join '|', Ekorn::Pipeline->new(sub { $trim->($_) })->(' a ', '  ', 'b ');    # a|b
```

Each call of the inner pipeline is a run of its own: its `gather`
stages start afresh on each value the outer stage is given, its end
functions are called at the end of each call, and a stop in it ends
only that call, not the outer pipeline. To have its stages run in the
outer pipeline's run instead, give the pipeline itself as a stage (see
[A pipeline as a stage](#a-pipeline-as-a-stage)).

## Stopping a pipeline: Ekorn::Pipeline::Stop

```perl
use Ekorn::Pipeline::Stop;       # Stop
use Ekorn::Pipeline::Stop ();    # nothing: call Ekorn::Pipeline::Stop->throw
```

A stop is the exception that ends a run early and quietly.

### Stop

```perl
Stop();
Stop(@values);
```

Throws a stop carrying `@values`, the last values of the stage that
throws it. It's the same as `Ekorn::Pipeline::Stop->throw(@values)`,
and is exported by default.

### throw

```perl
Ekorn::Pipeline::Stop->throw(@values);
My::Stop->throw(@values);
```

Throws a stop carrying `@values`, blessed into the class it's called
on, so a subclass of Ekorn::Pipeline::Stop throws one of its own.

### What a stop does

When a stage throws a stop:

- The rest of the stage that threw it doesn't run.
- The results already out are kept: returned, in a pushed run, or
  already handed out, by an iterator.
- The values the stop carries go on through the stages after the one
  that threw it, as that stage's last values.
- Nothing else is processed. The values waiting to go through the
  stages are dropped: the rest of the values a pipeline was called
  with, the rest of what a source returned in one call, and the rest of
  what a stage returned as a flatMap. The source isn't called again.
- The end functions of `gather` stages after the one that stopped are
  called, in order, so they get the values that went by before the
  stop, and the values it carries. Those of the stage that stopped, and
  of the stages before it, aren't.

```perl
my @seen;
my @out = Ekorn::Pipeline->new(
    sub { push @seen, $_; $_ == 3 ? Stop('three') : $_ },
    sub { uc },
)->(1 .. 5);
say "@out; saw @seen";    # 1 2 THREE; saw 1 2 3
```

An end function can stop the pipeline too. The values its stop carries
go on through the stages after it, and the ends after it are still
called.

### The stop object

A stop is an array reference, blessed into its class. Its first
element is that class, and the rest are the values it was thrown with:

```perl
eval { Ekorn::Pipeline::Stop->throw(1, 2) };
say ref $@, ' ', "@{$@}[1 .. $#{$@}]";    # Ekorn::Pipeline::Stop 1 2
```

As a string, a stop is "Stop used outside a pipeline", with a newline,
which is what a user sees if one is thrown with no pipeline to catch
it.

A stop that isn't an array, made without `throw`, as by blessing a
hash into the class, still stops the pipeline, but carries nothing.

### Subclasses

A pipeline recognises a stop with `isa`, so a stop of a subclass of
Ekorn::Pipeline::Stop stops it too, and behaves in the same way.

### Catching errors in a stage

A stop is an exception, so a stage that catches errors itself, with
`eval` or `try`, catches stops too, including those of the stages it
runs, such as `take`'s. It must throw them on:

```perl
use experimental qw(try);

my @out = Ekorn::Pipeline->new(sub ($x) {
    try {
        Stop() if $x > 2;
        return 10 / $x;
    }
    catch ($e) {
        die $e if $e isa 'Ekorn::Pipeline::Stop';
        return 'n/a';
    }
})->(0, 1, 2, 3);
say "@out";    # n/a 10 5
```

Test with `isa 'Ekorn::Pipeline::Stop'`, not with `ref`, so that a stop
of a subclass is thrown on too.

## Gathering: Ekorn::Pipeline::Gather

```perl
use Ekorn::Pipeline::Gather;       # gather
use Ekorn::Pipeline::Gather ();    # nothing: call Ekorn::Pipeline::Gather::gather
```

A plain stage can't tell when the last value has gone by, and whatever
it keeps stays from one run to the next. A stage that gathers values,
to give them in batches or all together, needs both: state of its own
on each run, and a call at the end. `gather` makes such a stage.

### gather

```perl
my $stage = gather { ...; return ($stage, $end) };
my $stage = gather { ...; return $stage };
```

Returns a stage that a pipeline makes afresh at the start of each run,
by calling the block, so whatever the block declares is fresh on each
run. The block returns:

- the stage, called with each value, as any stage is;
- optionally, an end function, called once the values run out.

`gather` croaks "Expected a code reference" if it's given something
other than a block or code reference. The block is called when the run
starts, not when `gather` is: when the pipeline is called with values,
or an iterator is made from it. So a block that returns something
other than one or two code references is reported then, as "Expected
stage #%d, made with gather, to return one or two code references".

What `gather` returns is a code reference, blessed into
Ekorn::Pipeline::Gather, so it can be given wherever a stage can.

```perl
sub running_total () {
    return gather {
        my $total = 0;    # this run's
        return sub ($n) { $total += $n };
    };
}

my $p = Ekorn::Pipeline->new(running_total());
say join ' ', $p->(1, 2, 3);    # 1 3 6
say join ' ', $p->(1, 2, 3);    # 1 3 6
```

### End functions

An end function is called with no arguments, and with `$_` undefined,
once the values run out: in a pushed run, after the last value has gone
through; with an iterator, once the source returns an empty list, or
after a stop. What it returns goes on through the stages after its
own, as what a stage returns does: nothing, one value, or several.

- It's called even when no values went by, so an end can give an empty
  result, such as `[]`, or nothing at all.
- The ends are called in order, first stage first. What one returns
  goes through the stages after it, and those stages' ends see it,
  before the next end is called. So a `collect` after a `batch` gets
  `batch`'s last, short batch.
- After a stop, only the ends of the stages after the one that stopped
  are called, as [What a stop does](#what-a-stop-does) says.
- While the values an end returns go through the stages,
  [`ending`](#ending) is true.
- An end that dies is reported as its stage would be, by the stage's
  place.

```perl
sub average () {
    return gather {
        my($sum, $n) = (0, 0);
        my $stage = sub ($x) { $sum += $x; $n++; return };
        my $end   = sub ()   { $n ? $sum / $n : () };
        return ($stage, $end);
    };
}

say Ekorn::Pipeline->new(average())->(2, 4, 9);    # 5
say scalar Ekorn::Pipeline->new(average())->();    # 0
```

The second line prints 0, the number of results: with no values, the
end returns nothing.

> **For stage authors:** a stage that holds values gives them up in
> its end, as `batch` and `collect` do, so none are lost when the
> values run out. Give the end a signature of none, `sub ()`.

## pipe and tap: Ekorn::Pipeline::Pipes

```perl
package My::Client;
use parent 'Ekorn::Pipeline::Pipes';
```

A parent class giving its children two methods, `pipe` and `tap`,
which run the object they're called on through a pipeline of stages.
The first stage is given the object, in `$_` and as its argument.
DBIx::Squirrel's database and statement handles have the same two
methods.

### pipe

```perl
my @results = $object->pipe(@stages);
my $first   = $object->pipe(@stages);
```

Runs the object through a pipeline of `@stages`, and returns what
comes out of the last one. In scalar context, it returns the first of
the results, or `undef` if there are none, where a pipeline called in
scalar context returns how many there are. With no stages, it returns
the object.

### tap

```perl
$object = $object->tap(@stages);
```

Runs the object through a pipeline of `@stages` for their side effects,
and returns the object, whatever comes out of the stages, so a chain
of method calls can carry on after it.

```perl
package Counter {
    use parent 'Ekorn::Pipeline::Pipes';
    sub new ($class) { bless {n => 0}, $class }
    sub up ($self) { $self->{n}++; $self }
    sub n ($self) { $self->{n} }
}

say Counter->new->up->tap(sub { $_->up })->up->n;    # 3
say scalar Counter->new->pipe(sub { $_->n + 10 });   # 10
```

## Canned stages

Stages for any values, whatever they are and wherever they come from,
in three modules. Each is a function that returns a stage, and checks
what it's given when it's called, not on each value, croaking at the
caller's line if it's wrong. Those that keep state or hold values are
made with `gather`, so they start afresh on each run.

| Stage | Module | Passes on | Exported |
|---|---|---|---|
| `take($count)` | Flow | the first `$count` values, then stops | by default |
| `drop($count)` | Flow | all but the first `$count` values | by default |
| `take_while { ... }` | Flow | values until the block is false of one, then stops | on request |
| `drop_while { ... }` | Flow | values from the first the block is false of | on request |
| `batch($size)` | Batch | array references of `$size` values, the last shorter | by default |
| `collect` | Batch | at the end, an array reference of every value | by default |
| `collect { ... }` | Batch | at the end, what the block makes of every value | by default |
| `peek { ... }` | Taps | every value, after calling the block with it | by default |
| `count_into(\$n)` | Taps | every value, counting them into `$n` | by default |
| `dump_to($fh)` | Taps | every value, after writing it to `$fh` or STDERR | on request |

Each module exports its defaults with a plain `use`, and every stage it
has with `:all`. To have the defaults and one more, name `:DEFAULT`
too:

```perl
use Ekorn::Pipeline::Stages::Flow qw(:DEFAULT take_while);
```

### Ekorn::Pipeline::Stages::Flow

Stages that decide which values go on, by their place or by a test.

#### take

```perl
take($count)
```

Passes on the first `$count` values, then stops the pipeline, so an
iterator calls its source no more. The last value it passes on goes
with the stop, so the source isn't asked for one more than is wanted.
With fewer values, it passes them all on. `take(0)` passes on none,
but sees one value first, as a stage isn't called until there is one:
with an iterator, the source is called once.

It croaks "Expected a count of 0 or more" if `$count` isn't a whole
number.

#### drop

```perl
drop($count)
```

Drops the first `$count` values, and passes on the rest. With `take`,
it gives a page: `drop(20), take(10)` passes on the 21st to the 30th.
It croaks "Expected a count of 0 or more" if `$count` isn't a whole
number.

#### take_while

```perl
take_while { ... }
```

Passes on values while the block is true of them, then stops the
pipeline at the first it's false of, which isn't passed on. The block
is given each value in `$_` and as its argument. It croaks "Expected a
code reference" if it isn't given a block or code reference.

#### drop_while

```perl
drop_while { ... }
```

Drops values while the block is true of them, and passes on the rest,
from the first it's false of. Once it's false, the block isn't called
again on that run. The block is given each value in `$_` and as its
argument. It croaks "Expected a code reference" if it isn't given a
block or code reference.

```perl
say join ' ', Ekorn::Pipeline->new(drop_while { $_ < 3 }, take_while { $_ < 6 })->(1 .. 9);
# 3 4 5
```

### Ekorn::Pipeline::Stages::Batch

Stages that gather values, and pass them on together. Both hold values,
and pass on what they still hold once the values run out.

#### batch

```perl
batch($size)
```

Passes values on in batches of `$size`, each a new array reference.
Once the values run out, the last batch, which may be shorter, goes
on. There's no empty batch: without values, there's no batch at all.
It holds no more than one batch at a time. It croaks "Expected a batch
size of 1 or more" if `$size` isn't a whole number above 0.

#### collect

```perl
collect
collect { ... }
```

Holds every value, and once they run out, passes on an array reference
of them, or, given a block, what the block returns, called once with
the values as its arguments. What the block returns goes through the
stages after it, as what a stage returns does: nothing, one value, or
several. It's called even without values, so `collect` still gives a
result: an empty array, or what the block makes of none. It croaks
"Expected a code reference" if it's given something other than a
block or code reference.

`collect` holds every value until the end, so the whole result is in
memory at once.

```perl
say join ' ', map { "[@$_]" } Ekorn::Pipeline->new(batch(2))->(1 .. 5);    # [1 2] [3 4] [5]
say Ekorn::Pipeline->new(collect { join '+', @_ })->(1 .. 3);               # 1+2+3
```

### Ekorn::Pipeline::Stages::Taps

Stages that look at each value as it goes by, and pass it on as it is,
for logging, counting or debugging.

#### peek

```perl
peek { ... }
```

Calls the block with each value, in `$_` and as its argument, and
passes the value on, whatever the block returns. It croaks "Expected a
code reference" if it isn't given a block or code reference.

#### count_into

```perl
count_into(\$count)
```

Counts the values into `$count`, setting it to 0 at the start of each
run, so after a run it holds how many values went by, even when that's
none. It croaks "Expected a reference to a scalar" if it isn't given
one.

#### dump_to

```perl
dump_to($fh)
dump_to
```

Writes each value to `$fh`, or to STDERR, with Data::Dumper, its keys
in order and indented by two, and passes it on. It croaks "Expected an
open filehandle" if `$fh` isn't one.

It's for debugging. It writes each value in full, secrets and all, and
doesn't escape control characters in strings, so a value from outside
can send escape sequences to a terminal.

## Errors: Ekorn::Pipeline::Errors

### When a stage dies

A stage, or an end function, that dies with a message is named by its
position, counting from 1 (`#2.3` for one inside a pipeline given as a
stage). It's reported at the line that ran the pipeline: the call of
the pipeline, or of the iterator that asked for the result. The
message it died with follows, indented by four spaces:

```text
Pipeline stage #2 failed at app.pl line 12:
    No name for user 7 at app.pl line 9.
```

An exception object, such as a stop or an object of a class of your
own, is thrown on as it is, so code that catches it can tell it by its
class.

Either way, the run has ended. A pushed run returns nothing, and an
iterator returns an empty list on every call after, without calling
its source or any end function again, as [iterator](#iterator) says.

A mistake in making a pipeline, such as a stage that isn't a code
reference, or in making a canned stage, such as `take(-1)`, is
reported at the line that made it, before any value goes through.

### croakf

```perl
use Ekorn::Pipeline::Errors qw(croakf);

croakf 'Expected a length of 0 or more, not %s', $length;
```

Croaks with a message made by `sprintf` from a format and its
arguments, reporting it at the same line as Carp's `croak` would: the
line that called the function calling `croakf`. It's exported only on
request.

It's for modules of stages outside Ekorn::Pipeline too. Called from a
function that makes a stage, in a package of its own, it reports a
mistake at the line that called the function, with no more set up. A
`%` in the message is written `%%`.

The format is a literal, written in the code: values go in as
arguments, through `%s` and the like, never as the format. A format
made from data does whatever its `%` directives say, such as
`%999999999s`, which makes a string of a gigabyte.

### @INTERNAL and @CARP_NOT

```perl
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;
```

`@Ekorn::Pipeline::Errors::INTERNAL` lists the packages of
Ekorn::Pipeline. Each of its modules that croaks takes the list as its
`@CARP_NOT`, so that Carp looks past all of them to the first line
outside, where the user's code is.

A package that puts the list in its own `@CARP_NOT` is looked past
too:

- **A module of functions taking stages,** which runs its callers'
  stages, has their errors reported at its callers' lines, rather than
  at its own line that ran the pipeline. DBIx::Squirrel does this.
- **A module of stages whose helpers are in another package** puts
  that package in its `@CARP_NOT`, and the helper's package puts the
  module's, so that `croakf` in the helper reports at the line that
  called the module. A helper in the same package needs nothing.

## Writing stages

A stage for others to use is written as the canned stages are, so that
it works alongside them.

- **A function that makes a stage.** A plain `sub` is a stage. For a
  stage others will use, write a function that returns one, as
  `take(10)` does. It can take options, and check them once, when it's
  called, not on each value.
- **Report mistakes at the caller's line,** with `croakf`, from a
  package of your own, as [croakf](#croakf) says, with a literal
  format and the values as its arguments. Put "Expected" first,
  and say what was expected, as the canned stages do: "Expected a count
  of 0 or more".
- **One argument in; a list out.** The stage is given one value, in `$_`
  and as its argument. It returns an empty list to drop it, one value to
  pass it on, or several. Return the value from a stage run for its side
  effects.
- **Don't change the value you're given,** unless that's the stage's
  job and its documentation says so.
- **State goes in `gather`,** even a count, so that it starts afresh on
  each run, and two runs at once don't share it.
- **Values held go out in an end function,** called even when there
  were no values, with no arguments and `$_` undefined.
- **Stop when no more values are wanted,** with `Stop`, so an iterator
  reads no more. Pass the last value on with the stop, as `take` does,
  so the source isn't asked for one more than is needed.
- **Throw stops on.** A stage that catches errors throws a stop on with
  `die $e if $e isa 'Ekorn::Pipeline::Stop';`.
- **Say what the stage takes and gives,** in its documentation: what
  kind of value it's given, what it passes on, whether it holds values
  or stops, and what it croaks with.
- **Names.** A name says what the stage does to a value, and a tap's
  says it passes values on, as `peek` and `count_into` do. Avoid names
  that common modules export: Flow has `drop`, not `skip`, which
  Test2::V0 and Test::More both export, and Test2::V0 also exports
  names such as `field`, `item` and `call`.
- **Exports.** Export the stages a module is usually used for by
  default, in `@EXPORT`, the rest in `@EXPORT_OK`, and all of them with
  an `:all` tag.
- **Where it goes.** Stages for any values go under
  `Ekorn::Pipeline::Stages::*`. Stages for one kind of value or one
  source go under the namespace of the module that knows about it, as
  DBIx::Squirrel's stages for rows are `DBIx::Squirrel::Stages::Rows`.
- **Tests.** A pipeline called with values tests a stage with nothing
  else to set up. Run it twice, to show it starts afresh, with no
  values, to show what its end gives, and through an iterator, counting
  the calls of the source, to show a stage that stops reads no more
  than it should.

```perl
package My::Stages::Numbers {
    use Ekorn::Pipeline::Errors qw(croakf);
    use Ekorn::Pipeline::Gather qw(gather);
    use Ekorn::Pipeline::Stop qw();

    # Pass on values until their sum would pass $limit, then stop.
    sub sum_up_to ($limit) {
        croakf 'Expected a number for the limit, not %s', $limit // 'undef'
            unless defined $limit && $limit =~ m( \A -? \d+ (?: \.\d+ )? \z )xa;
        return gather {
            my $sum = 0;    # this run's
            return sub ($n) {
                Ekorn::Pipeline::Stop->throw if $sum + $n > $limit;
                $sum += $n;
                return $n;
            };
        };
    }
}

say join ' ', Ekorn::Pipeline->new(My::Stages::Numbers::sum_up_to(10))->(4, 3, 2, 5, 1);    # 4 3 2
```

## Writing functions that take stages

- **Take the stages last,** after whatever arguments the function
  needs, as `sub lines_of ($file, @stages)`. A caller who wants nothing
  done passes none.
- **Push what you have; pull what you make.** Call the pipeline with
  values already in memory. For values made one at a time, give
  `iterator` a source and return the iterator, so a stage that stops
  saves the work of making the rest.
- **Let stages do the optional work.** An option that filters,
  reshapes or limits what's returned is one a stage does already. Keep
  the arguments only the function can act on, such as which file to
  read.
- **Say what the first stage is given,** and number your own stages
  into it, if the function puts stages of its own before its caller's.
- **Report errors at your callers' lines,** by putting
  `@Ekorn::Pipeline::Errors::INTERNAL` in the module's `@CARP_NOT`.
- **Find the stages with `is_stage`,** if the arguments before them
  can be anything, so that callers can pass a pipeline as a stage, as
  they can to `new`.

```perl
use Ekorn::Pipeline qw(is_stage);

# The values given, up to the stages at the end, through those stages.
sub only (@args) {
    my @stages;
    unshift @stages, pop @args while @args && is_stage($args[-1]);
    return Ekorn::Pipeline->new(@stages)->(@args);
}

my $evens = Ekorn::Pipeline->new(sub { $_ % 2 ? () : $_ });
say join ' ', only(1 .. 10, $evens, take(3));    # 2 4 6
```

```perl
package My::Files {
    use Ekorn::Pipeline;
    our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

    # The lines of a file, without their newlines, through the caller's stages.
    sub lines_of ($file, @stages) {
        open my $fh, '<', $file or die "Can't read $file: $!\n";
        return Ekorn::Pipeline->new(sub { s( \n \z )()xr }, @stages)
            ->iterator(sub { scalar(<$fh>) // () });
    }
}

my $text = "one\ntwo\nthree\n";
my $next = My::Files::lines_of(\$text, sub { uc }, take(2));
my @lines;
while (my($line) = $next->()) { push @lines, $line }
say "@lines";    # ONE TWO
```

## Diagnostics

Every message Ekorn::Pipeline writes, by module. Each is reported at
the line of the caller's code that caused it.

### Ekorn::Pipeline

- **Expected stage #%d to be a code reference:** a stage given to
  `new` wasn't a code reference or a pipeline. It's also raised for a
  pipeline whose overridden `stages` method returned something that
  isn't a code reference.
- **Expected a code reference:** the source given to `iterator` wasn't
  a code reference.
- **Expected stage #%s, made with gather, to return one or two code
  references:** the block given to `gather` for that stage returned
  something other than a stage, or a stage and an end function.
  Reported when the run starts.
- **Pipeline stage #%s failed at %s line %d:** a stage, or its end
  function, died with a message, which follows, indented. An exception
  object is thrown on as it is.

In these two, a stage is named by its position: `#2` for the second
stage, or `#2.3` for the third stage of a pipeline given as the second
stage.

### Ekorn::Pipeline::Stop

- **Stop used outside a pipeline:** a stop was thrown with no pipeline
  running to catch it.

### Ekorn::Pipeline::Gather

- **Expected a code reference:** `gather` was given something other
  than a block or code reference.

### Canned stages

- **Expected a count of 0 or more:** `take` or `drop` was given
  something other than a whole number.
- **Expected a batch size of 1 or more:** `batch` was given something
  other than a whole number above 0.
- **Expected a code reference:** `take_while`, `drop_while`, `collect`
  or `peek` was given something other than a block or code reference.
- **Expected a reference to a scalar:** `count_into` was given
  something other than a reference to a scalar.
- **Expected an open filehandle:** `dump_to` was given something other
  than an open filehandle.

## Exports

| Module | By default | On request | Tags |
|---|---|---|---|
| `Ekorn::Pipeline` | nothing | `is_stage` | |
| `Ekorn::Pipeline::Stop` | `Stop` | | |
| `Ekorn::Pipeline::Gather` | `gather` | | |
| `Ekorn::Pipeline::Pipes` | nothing: a parent class | | |
| `Ekorn::Pipeline::Errors` | nothing | `croakf` | |
| `Ekorn::Pipeline::Stages::Flow` | `take`, `drop` | `take_while`, `drop_while` | `:all` |
| `Ekorn::Pipeline::Stages::Batch` | `batch`, `collect` | | `:all` |
| `Ekorn::Pipeline::Stages::Taps` | `peek`, `count_into` | `dump_to` | `:all` |

To import nothing from a module that exports by default, give it an
empty list: `use Ekorn::Pipeline::Stop ();`.

## The modules

| Module | What it is |
|---|---|
| `Ekorn::Pipeline` | Runs values through a list of stages: `new`, `iterator`, `stages`, `is_stage` and `ending`. |
| `Ekorn::Pipeline::Stop` | Ends a pipeline early: `Stop` and `throw`. |
| `Ekorn::Pipeline::Gather` | Makes a stage afresh for each run, with a function called at the end: `gather`. |
| `Ekorn::Pipeline::Pipes` | A parent class giving `pipe` and `tap` methods. |
| `Ekorn::Pipeline::Errors` | Reports errors at the caller's line: `croakf` and `@INTERNAL`. |
| `Ekorn::Pipeline::Stages::Flow` | Canned stages taking or dropping values: `take`, `drop`, `take_while`, `drop_while`. |
| `Ekorn::Pipeline::Stages::Batch` | Canned stages gathering values: `batch`, `collect`. |
| `Ekorn::Pipeline::Stages::Taps` | Canned stages run for their side effects: `peek`, `count_into`, `dump_to`. |
