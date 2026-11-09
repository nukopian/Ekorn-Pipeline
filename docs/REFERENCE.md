# Ekorn::Pipeline reference

<!-- stopwords: 21st -->

Stages for any function: let the caller finish the job.

A function that hands out values takes a list of *stages* from its
caller, as its last arguments, and runs each value through them. A
stage can change a value, drop it, or turn it into several. It can
also stop the pipeline early, so the function makes no more values
than its caller wants.

This reference describes every module, function and method, and how a
pipeline behaves, with examples. [The how-to](HOWTO.md) shows how to
do common tasks, one recipe at a time. Notes marked **For stage
authors** are for people writing stages for others;
[Writing stages](#writing-stages) collects them. Each module's POD
says the same more briefly, and is the authority where they differ.

Ekorn::Pipeline needs Perl 5.36 or later. Its version is 0.x, so the
interface may still change before 1.0, but the version number says
when. A release that only fixes or adds moves the last number, as in
v0.1.1. One that changes how stages behave, or drops or renames a
name, moves the middle number, as in v0.2.0. [Changes](../Changes)
says what each release changed.

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

# A pipeline: a list of stages. A stage is a code reference given one
# value, in $_ and as its argument, returning nothing, one value or
# several; or another pipeline, standing for its stages.
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
- **Stage:** a code reference or another pipeline. A code reference
  is called with one value, and returns a list of values: none, one or
  several. A pipeline stands for its own stages (see
  [A pipeline as a stage](#a-pipeline-as-a-stage)).
- **Pipeline:** a list of stages, made with `Ekorn::Pipeline->new`.
- **Run:** one call of a pipeline with values, or one iterator made
  from it. Stages made with `gather` start afresh on each run.
- **Source:** a code reference an iterator calls for values. It returns
  the next value or values, or an empty list when there are no more.
- **Result:** a value that comes out of the last stage.
- **Stop:** the exception a stage throws to end its run early, with
  `Stop` or `Ekorn::Pipeline::Stop->throw`.
- **End function:** a function a `gather` stage can have. It's called
  once the values run out, and its values go on through the stages
  after it.

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
stage must be a code reference or a pipeline. Anything else croaks,
naming its position: "Expected stage #2 to be a code reference".

Any code reference will do: an anonymous `sub`, a reference to a named
one such as `\&trim`, a stage made by a function such as `take(10)`, or
one made with `gather`.

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
with values, it runs each of them through the stages, in order. In
list context it returns the results; in scalar context, how many there
are.

```perl
my $evens = Ekorn::Pipeline->new(sub { $_ % 2 ? () : $_ });
my @evens = $evens->(1 .. 6);
my $count = $evens->(1 .. 6);
say "@evens, $count of them";    # 2 4 6, 3 of them
```

Each call is a run. You can call a pipeline as often as you like, even
from inside one of its own stages.

### iterator

```perl
my $next = $p->iterator($source);
while (my($result) = $next->()) { ... }
```

Returns a closure that hands out the results one per call, pulling
values from `$source` as they're needed. `$source` is a code reference
called with no arguments. It returns the next value, several values,
or an empty list when there are no more. If `$source` isn't a code
reference, `iterator` croaks "Expected a code reference".

- The source is called only when a result is wanted, and only once the
  values from its last call have all gone through the stages. A source
  reading a file, a socket or a database reads no more than its caller
  asks for.
- The closure returns one result per call. Once the results run out,
  it returns an empty list, on every call. Read it in list context, as
  `my($x) = $next->()`, so that a result of `undef`, 0 or `''` isn't
  taken for the end.
- Once the source has returned an empty list, or a stage has stopped
  the pipeline, the source isn't called again.
- The end functions of `gather` stages are called once the source
  runs out, or after a stop, before the closure returns an empty list.
- If a stage or an end function dies, the call dies with it, and the
  iterator has ended, as a pushed run does. Every call after returns
  an empty list. Nothing waiting goes on, no end function is called,
  and the source isn't called again. So an end such as `collect`'s
  never reports on a run that lost values. To skip a bad value and
  carry on, catch the error inside the stage, as in the how-to's
  "Catch errors in a stage, but not a stop".

Each iterator is a run of its own. Two iterators from one pipeline can
be read in turn, and each has its own `gather` stages:

```perl
my $numbered = Ekorn::Pipeline->new(gather { my $n = 0; sub { ++$n . $_ } });
my @a = qw(a b);
my @b = qw(x y);
my $first  = $numbered->iterator(sub { @a ? shift @a : () });
my $second = $numbered->iterator(sub { @b ? shift @b : () });
say join ' ', $first->(), $second->(), $first->(), $second->();    # 1a 1x 2b 2y
```

A source that returns `shift @queue // ()` ends at the first `undef` in
the queue; `@queue ? shift @queue : ()` doesn't. Read a filehandle in
scalar context, `sub { scalar(<$fh>) // () }`, so that each call reads
one line.

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

It's for code that tells its stages more about each value, such as
where it came from. A value from an end function has no such origin.
DBIx::Squirrel, for instance, tells its stages which row a value was
made from, and has no row to give while `ending` is true.

```perl
my @seen = Ekorn::Pipeline->new(
    collect { scalar @_ },
    sub { Ekorn::Pipeline::ending() ? "count $_" : $_ },
)->(qw(a b c));
say "@seen";    # count 3
```

A pipeline run inside a stage has its own `ending`. In a pipeline
called from a stage while `ending` is true, `ending` is false until
one of the inner pipeline's own end functions is called.

## How values go through stages

This section describes stages that are code references. A pipeline
given as a stage stands for its stages, and each of them behaves as
described here.

### One value at a time

Each value goes through every stage before the next one starts, as it
would in a `for` loop. The results come out in order, and each stage
sees the values in order. Nothing is held between stages, except by a
stage that holds values itself, such as `batch` or `collect`.

When a stage returns several values, the first goes through the rest
of the stages, then the second, and so on. Only then does the next
value come from the source or the caller:

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
`$_`. It can name the value with a signature, `sub ($track) { ... }`,
or use `$_`, `sub { ... }`.

- `$_` is local to each call. The caller's `$_` is left alone, and a
  stage can call code that uses `$_` itself.
- The values a pipeline is called with are copied. Assigning to `$_`
  or `$_[0]` changes the pipeline's copy, not the caller's variable.
- A reference is copied as a reference. A stage that changes the hash
  or array it's given changes the caller's.

> **For stage authors:** a stage is always called with exactly one
> argument, so a one-argument signature is safe. Don't change the
> value you're given; return a new value instead. The exception is a
> stage whose job, as documented, is to change it.

### What a stage returns

A stage returns a list, and what it returns is all that goes on:

| It returns | Its kind | What goes on |
|---|---|---|
| an empty list | a filter | nothing: the value is dropped, and the stages after it don't see it |
| one value | a map | that value, in place of the one it was given |
| several values | a flatMap | each of them, in order, through the rest of the stages |

`undef`, 0 and `''` are values, so `return undef` passes on `undef`.
A stage ending in a test, such as `sub { $_ > 2 }`, passes on what the
test returns, not the value. To drop a value, return an empty list:
`return;` or `()`.

> **For stage authors:** a stage run for its side effects, such as
> logging, must return the value it was given, as `peek` does, or the
> value is dropped.

### Runs

Each call of a pipeline with values is a run, and so is each iterator
made from it. At the start of each run, the block of every `gather`
stage is called, so what those stages keep starts afresh. An
iterator's run starts when the iterator is made, not when it's first
read.

A stage not made with `gather` is the same code reference on every
run. Whatever it keeps in a closure stays there from one run to the
next:

```perl
my $count = 0;
my $plain = Ekorn::Pipeline->new(sub { ++$count });
my @first  = $plain->(qw(a b));
my @second = $plain->(qw(a b));
say "@first / @second";    # 1 2 / 3 4
```

> **For stage authors:** put anything a stage keeps, even a count, in
> a `gather` block. A stage made once may be given to several
> pipelines, run more than once, or run by two iterators at once.

### Calling a pipeline from a stage

A stage can run a pipeline of its own, so stages can be built from
stages:

```perl
my $trim = Ekorn::Pipeline->new(sub { s( \A \s+ | \s+ \z )()xgr }, sub { length ? $_ : () });
say join '|', Ekorn::Pipeline->new(sub { $trim->($_) })->(' a ', '  ', 'b ');    # a|b
```

Each call of the inner pipeline is a run of its own. Its `gather`
stages start afresh on each value the outer stage is given, and its
end functions are called at the end of each call. A stop in it ends
only that call, not the outer pipeline. To run its stages in the outer
pipeline's run instead, give the pipeline itself as a stage (see
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
throws it. It's the same as `Ekorn::Pipeline::Stop->throw(@values)`.
It's exported by default.

### throw

```perl
Ekorn::Pipeline::Stop->throw(@values);
My::Stop->throw(@values);
```

Throws a stop carrying `@values`, blessed into the class it's called
on. A subclass of Ekorn::Pipeline::Stop throws a stop of its own
class.

### What a stop does

When a stage throws a stop:

- The rest of the stage that threw it doesn't run.
- The results already out are kept: returned by a pushed run, or
  already handed out by an iterator.
- The values the stop carries go on through the stages after the one
  that threw it, as that stage's last values.
- Nothing else is processed. Values waiting to go through the stages
  are dropped: the rest of the values a pipeline was called with, the
  rest of what a source returned in one call, and the rest of what a
  stage returned as a flatMap. The source isn't called again.
- The end functions of `gather` stages after the one that stopped are
  called, in order. They get the values from before the stop, and the
  values it carries. The ends of the stage that stopped, and of the
  stages before it, aren't called.

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

As a string, a stop is "Stop used outside a pipeline", with a newline.
That's what a user sees if one is thrown with no pipeline to catch it.

A stop that isn't an array, made without `throw` (by blessing a hash
into the class, say), still stops the pipeline, but carries nothing.

### Subclasses

A pipeline recognises a stop with `isa`, so a stop of a subclass of
Ekorn::Pipeline::Stop works in exactly the same way.

### Catching errors in a stage

A stop is an exception, so a stage that catches errors itself, with
`eval` or `try`, catches stops too, including stops from stages it
runs, such as `take`'s. It must throw them again:

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
of a subclass is thrown again too.

## Gathering: Ekorn::Pipeline::Gather

```perl
use Ekorn::Pipeline::Gather;       # gather
use Ekorn::Pipeline::Gather ();    # nothing: call Ekorn::Pipeline::Gather::gather
```

A plain stage can't tell when the last value has gone by, and whatever
it keeps stays from one run to the next. A stage that gathers values,
to give them in batches or all together, needs both: fresh state on
each run, and a call at the end. `gather` makes such a stage.

### gather

```perl
my $stage = gather { ...; return ($stage, $end) };
my $stage = gather { ...; return $stage };
```

Returns a stage that a pipeline makes afresh at the start of each run,
by calling the block. Whatever the block declares is fresh on each
run. The block returns:

- the stage, called with each value, like any stage;
- optionally, an end function, called once the values run out.

`gather` croaks "Expected a code reference" if it's given something
other than a block or code reference. The block is called when a run
starts, not when `gather` is called: when the pipeline is called with
values, or an iterator is made from it. A block that returns something
other than one or two code references is reported then, as "Expected
stage #%s, made with gather, to return one or two code references".

What `gather` returns is a code reference, blessed into
Ekorn::Pipeline::Gather, so it can go wherever a stage can.

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
once the values run out. In a pushed run, that's after the last value
has gone through. With an iterator, it's once the source returns an
empty list, or after a stop. What it returns goes on through the
stages after its own, just like what a stage returns: nothing, one
value, or several.

- It's called even when no values went by, so an end can give an empty
  result, such as `[]`, or nothing at all.
- The ends are called in order, first stage first. What one returns
  goes through the stages after it, and their ends see it, before the
  next end is called. So a `collect` after a `batch` gets `batch`'s
  last, short batch.
- After a stop, only the ends of the stages after the one that stopped
  are called (see [What a stop does](#what-a-stop-does)).
- While the values an end returns go through the stages,
  [`ending`](#ending) is true.
- An end that dies is reported as its stage would be, by the stage's
  position.

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

The second line prints 0, the number of results. With no values, the
end returns nothing.

> **For stage authors:** a stage that holds values should give them
> up in its end, as `batch` and `collect` do, so none are lost when the
> values run out. Give the end an empty signature, `sub ()`.

## pipe and tap: Ekorn::Pipeline::Pipes

```perl
package My::Client;
use parent 'Ekorn::Pipeline::Pipes';
```

A parent class that gives its children two methods, `pipe` and `tap`.
Each runs the object it's called on through a pipeline of stages. The
first stage is given the object, in `$_` and as its argument.
DBIx::Squirrel's database and statement handles have the same two
methods.

### pipe

```perl
my @results = $object->pipe(@stages);
my $first   = $object->pipe(@stages);
```

Runs the object through a pipeline of `@stages`, and returns what
comes out of the last stage. In scalar context, it returns the first
result, or `undef` if there are none. (A pipeline called in scalar
context returns how many there are; `pipe` doesn't.) With no stages,
it returns the object.

### tap

```perl
$object = $object->tap(@stages);
```

Runs the object through a pipeline of `@stages` for their side effects,
and returns the object, whatever the stages return. A chain of method
calls can carry on after it.

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
in three modules. Each is a function that returns a stage. It checks
its arguments when it's called, not on each value, and croaks at the
caller's line if they're wrong. Those that keep state or hold values
are made with `gather`, so they start afresh on each run.

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

Each module exports its defaults with a plain `use`, and every stage
it has with `:all`. To get the defaults and one more, name `:DEFAULT`
too:

```perl
use Ekorn::Pipeline::Stages::Flow qw(:DEFAULT take_while);
```

### Ekorn::Pipeline::Stages::Flow

Stages that decide which values go on, by their position or by a
test.

#### take

```perl
take($count)
```

Passes on the first `$count` values, then stops the pipeline, so an
iterator stops calling its source. The last value it passes on goes
with the stop, so the source isn't asked for one more than is wanted.
If there are fewer values, it passes them all on. `take(0)` passes on
none, but it still sees one value first, because a stage isn't called
until there is one. With an iterator, the source is called once.

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

Passes on values while the block returns true for them, then stops the
pipeline at the first value it returns false for. That value isn't
passed on. The block gets each value in `$_` and as its argument. It
croaks "Expected a code reference" if it isn't given a block or code
reference.

#### drop_while

```perl
drop_while { ... }
```

Drops values while the block returns true for them, then passes on the
rest, starting with the first value it returns false for. After that,
the block isn't called again on that run. The block gets each value in
`$_` and as its argument. It croaks "Expected a code reference" if it
isn't given a block or code reference.

```perl
say join ' ', Ekorn::Pipeline->new(drop_while { $_ < 3 }, take_while { $_ < 6 })->(1 .. 9);
# 3 4 5
```

### Ekorn::Pipeline::Stages::Batch

Stages that gather values and pass them on together. Both pass on what
they still hold once the values run out.

#### batch

```perl
batch($size)
```

Passes values on in batches of `$size`, each a new array reference.
Once the values run out, the last batch goes on, which may be shorter.
There's never an empty batch: with no values, there's no batch at all.
It holds no more than one batch at a time. It croaks "Expected a batch
size of 1 or more" if `$size` isn't a whole number above 0.

#### collect

```perl
collect
collect { ... }
```

Holds every value. Once they run out, it passes on an array reference
of them. Given a block, it calls the block once, with the values as
its arguments, and passes on what the block returns: nothing, one
value, or several, just like a stage. The block is called even with no
values, so `collect` always gives a result: an empty array, or what the
block makes of none. It croaks "Expected a code reference" if it's
given something other than a block or code reference.

`collect` holds every value until the end, so the whole result is in
memory at once.

```perl
say join ' ', map { "[@$_]" } Ekorn::Pipeline->new(batch(2))->(1 .. 5);    # [1 2] [3 4] [5]
say Ekorn::Pipeline->new(collect { join '+', @_ })->(1 .. 3);               # 1+2+3
```

### Ekorn::Pipeline::Stages::Taps

Stages that look at each value as it goes by and pass it on unchanged,
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

Counts the values into `$count`. It sets `$count` to 0 at the start of
each run, so after a run it holds how many values went by, even if
none did. It croaks "Expected a reference to a scalar" if it isn't
given one.

#### dump_to

```perl
dump_to($fh)
dump_to
```

Writes each value to `$fh`, or to STDERR, with Data::Dumper, keys
sorted and indented by two, and passes it on. It croaks "Expected an
open filehandle" if `$fh` isn't one.

It's for debugging. It writes each value in full, secrets and all. It
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
own, is thrown again unchanged, so code that catches it can tell it by
its class.

Either way, the run has ended. A pushed run returns nothing. An
iterator returns an empty list on every call after, without calling
its source or any end function again (see [iterator](#iterator)).

A mistake in making a pipeline, such as a stage that isn't a code
reference, or in making a canned stage, such as `take(-1)`, is
reported at the line that made it, before any value goes through.

### croakf

```perl
use Ekorn::Pipeline::Errors qw(croakf);

croakf 'Expected a length of 0 or more, not %s', $length;
```

Croaks with a message made by `sprintf` from a format and its
arguments, at the line Carp's `croak` would report: the line that
called the function that called `croakf`. It's exported only on
request.

It's for modules of stages outside Ekorn::Pipeline too. Called from a
function that makes a stage, it reports a mistake at the line that
called the function, with nothing more to set up. A `%` in the message
is written `%%`.

Write the format as a literal in the code. Values go in as arguments,
through `%s` and the like, never in the format. A format made from
data does whatever its `%` directives say: `%999999999s` makes a
string of a gigabyte.

### @INTERNAL and @CARP_NOT

```perl
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;
```

`@Ekorn::Pipeline::Errors::INTERNAL` lists the packages of
Ekorn::Pipeline. Each of its modules that croaks uses the list as its
`@CARP_NOT`, so Carp looks past all of them to the first line outside,
in the user's code.

A package that puts the list in its own `@CARP_NOT` is looked past
too:

- **A module of functions that take stages** runs its callers' stages.
  With the list, their errors are reported at its callers' lines, not
  at the module's own line that ran the pipeline. DBIx::Squirrel does
  this.
- **A module of stages whose helpers are in another package** puts
  that package in its `@CARP_NOT`, and the helpers' package puts the
  module's. Then `croakf` in a helper reports at the line that called
  the module. A helper in the same package needs nothing.

## Writing stages

Write a stage for others the way the canned stages are written, so it
works alongside them.

- **Write a function that makes the stage.** A plain `sub` is a stage,
  but for one others will use, write a function that returns it, as
  `take(10)` does. The function can take options, and check them once,
  when it's called, not on each value.
- **Report mistakes at the caller's line** with `croakf` (see
  [croakf](#croakf)), using a literal format and passing the values as
  arguments. Start with "Expected" and say what was expected, as the
  canned stages do: "Expected a count of 0 or more".
- **One argument in, a list out.** The stage gets one value, in `$_`
  and as its argument. It returns an empty list to drop it, one value
  to pass it on, or several. A stage run for its side effects returns
  the value.
- **Don't change the value you're given,** unless that's the stage's
  documented job.
- **Keep state in `gather`,** even a count, so it starts afresh on each
  run and two runs at once don't share it.
- **Give up held values in an end function.** It's called even when
  there were no values, with no arguments and `$_` undefined.
- **Stop when no more values are wanted,** with `Stop`, so an iterator
  reads no more. Pass the last value on with the stop, as `take` does,
  so the source isn't asked for one more than is needed.
- **Throw stops again.** A stage that catches errors should throw a
  stop again with `die $e if $e isa 'Ekorn::Pipeline::Stop';`.
- **Document what the stage takes and gives:** what kind of value it
  expects, what it passes on, whether it holds values or stops, and
  what it croaks with.
- **Names.** A name says what the stage does to a value. A tap's name
  says it passes values on, as `peek` and `count_into` do. Avoid names
  that common modules export: Flow has `drop`, not `skip`, because
  Test2::V0 and Test::More both export `skip`. Test2::V0 also exports
  names such as `field`, `item` and `call`.
- **Exports.** Export the stages a module is mostly used for by
  default, in `@EXPORT`. Put the rest in `@EXPORT_OK`, and all of them
  in an `:all` tag.
- **Where it goes.** Stages for any values go under
  `Ekorn::Pipeline::Stages::*`. Stages for one kind of value or one
  source go under the namespace of the module that knows about it. For
  example, DBIx::Squirrel's stages for rows are in
  `DBIx::Squirrel::Stages::Rows`.
- **Tests.** Calling a pipeline with values tests a stage with nothing
  else to set up. Run it twice, to show it starts afresh. Run it with
  no values, to show what its end gives. And run it through an
  iterator, counting the source's calls, to show that a stage that
  stops reads no more than it should.

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

- **Take the stages last,** after the function's own arguments, as in
  `sub lines_of ($file, @stages)`. A caller who wants nothing done
  passes no stages.
- **Push what you have; pull what you make.** Call the pipeline with
  values already in memory. For values made one at a time, give
  `iterator` a source and return the iterator. Then a stage that stops
  saves the work of making the rest.
- **Let stages do the optional work.** A stage can already filter,
  reshape or limit what's returned, so don't add options for it. Keep
  the arguments only the function can act on, such as which file to
  read.
- **Say what the first stage is given.** If the function puts stages
  of its own before its caller's, say so: error messages count them in
  the stages' positions.
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
