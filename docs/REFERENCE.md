# Ekorn::Pipeline reference

<!-- stopwords: 21st -->

Stages for any function: let the caller finish the job.

A function that hands out values takes a list of *stages* from its
caller, as its last arguments, and runs each value through them. A
stage can change a value, drop it, or turn it into several. It can
also stop the pipeline early, so the function makes no more values
than its caller wants.

This reference describes every module, function and method, and how a
pipeline behaves, with examples. [The user guide](HOWTO.md) tours the
package from the bottom up, with recipes for what each part can do.
Notes marked **For stage authors** are for people writing stages for
others; [Writing stages](#writing-stages) collects them. Each module's
POD says the same more briefly, and is the authority where they
differ.

Ekorn::Pipeline needs Perl 5.36 or later. Its version is 0.x, so the
interface may still change before 1.0, but the version number says
when. A release that only fixes or adds moves the last number, as in
v0.1.1. One that changes how stages behave, or drops or renames a
name, moves the middle number, as in v0.2.0. [Changes](../Changes)
says what each release changed.

## Contents

- [At a glance](#at-a-glance)
- [Importing: Ekorn::Pipeline::Tooling](#importing-ekornpipelinetooling)
- [Terms](#terms)
- [Pipelines: Ekorn::Pipeline](#pipelines-ekornpipeline)
- [Words: Ekorn::Pipeline::Factories](#words-ekornpipelinefactories)
- [How values go through stages](#how-values-go-through-stages)
- [Runs and how they end](#runs-and-how-they-end)
- [Stopping a pipeline: Ekorn::Pipeline::Stop](#stopping-a-pipeline-ekornpipelinestop)
- [Gathering: Ekorn::Pipeline::Gather](#gathering-ekornpipelinegather)
- [pipe and tap: Ekorn::Pipeline::Pipes](#pipe-and-tap-ekornpipelinepipes)
- [Canned stages](#canned-stages)
- [Sources: Ekorn::Pipeline::Sources](#sources-ekornpipelinesources)
- [Sinks: Ekorn::Pipeline::Sinks](#sinks-ekornpipelinesinks)
- [JSON: Ekorn::Pipeline::JSON](#json-ekornpipelinejson)
- [Operators: Ekorn::Pipeline::Operators](#operators-ekornpipelineoperators)
- [Errors: Ekorn::Pipeline::Errors](#errors-ekornpipelineerrors)
- [Writing stages](#writing-stages)
- [Writing functions that take stages](#writing-functions-that-take-stages)
- [Delivering parts for Ekorn](#delivering-parts-for-ekorn)
- [Making each kind of part](#making-each-kind-of-part)
- [Diagnostics](#diagnostics)
- [Exports](#exports)
- [The modules](#the-modules)

## At a glance

```perl
use v5.36;
use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:all);    # every stage, source, sink and word

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
my $next = Ekorn::Pipeline->new(
    sub { $_ * $_ },
    take(3),
)->iterator(sub { ++$n });
my @squares;
while (my($square) = $next->()) { push @squares, $square }
say "@squares";    # 1 4 9

# A function of your own, taking stages from its caller.
sub numbers (@stages) { Ekorn::Pipeline->new(@stages)->(1 .. 10) }
say join ' ', numbers(
    drop(2),
    take(3),
);
# 3 4 5
```

## Importing: Ekorn::Pipeline::Tooling

```perl
use Ekorn::Pipeline::Tooling qw(:all);              # everything below
use Ekorn::Pipeline::Tooling qw(:stages :sinks);    # or some tags
use Ekorn::Pipeline::Tooling qw(take keep_all);     # or some names
```

What a caller uses to do work is made in several modules, each
described below. Ekorn::Pipeline::Tooling exports all of it, from one
place, by tags that follow the modules that make it:

| Tag | Holds | Made in |
|---|---|---|
| `:core` | `Stop`, `gather` | [Stop](#stopping-a-pipeline-ekornpipelinestop), [Gather](#gathering-ekornpipelinegather) |
| `:flow` | `take`, `take_first`, `take_last`, `take_single`, `take_if`, `take_while`, `drop`, `drop_if`, `drop_while` | [Stages::Flow](#ekornpipelinestagesflow) |
| `:batch` | `batch`, `collect` | [Stages::Batch](#ekornpipelinestagesbatch) |
| `:taps` | `peek`, `count_into`, `dump_to` | [Stages::Taps](#ekornpipelinestagestaps) |
| `:stages` | `:flow`, `:batch` and `:taps` | |
| `:sources` | `from_array`, `from_fh`, `from_file`, `counter` | [Sources](#sources-ekornpipelinesources) |
| `:sinks` | `count_items`, `keep`, `keep_all`, `keep_first`, `keep_last`, `keep_single`, `to_fh`, `to_file` | [Sinks](#sinks-ekornpipelinesinks) |
| `:json` | `from_json`, `from_jsonl`, `to_json`, `to_jsonl` | [JSON](#json-ekornpipelinejson) |
| `:words` | `pipeline`, `stage`, `gather`, `source`, `generator`, `yield`, `sink_one`, `sink_many` | [Factories](#words-ekornpipelinefactories) |
| `:all` | all of the above | |

- **Nothing by default.** Ask for tags, names, or both. An unknown tag
  or name is Exporter's error: it warns `"%s" is not defined in
  %Ekorn::Pipeline::Tooling::EXPORT_TAGS`, or `"%s" is not exported by
  the Ekorn::Pipeline::Tooling module`, and dies `Can't continue after
  import errors`.
- **The same subs.** Each name is the sub its own module exports,
  prototype and all, so `take_if { ... }` and `stage { ... }` parse as
  they do imported from there, and importing a name from both does no
  harm.
- **A tag holds every name its module exports,** by default or on
  request. What a tag holds is part of the interface: a name may be
  added to one in a release that only adds, but is dropped or renamed
  only in one that moves the middle number of the version.
- **What it leaves out:** what's for extending the package rather than
  using it, `is_stage` and `is_sink`, from Ekorn::Pipeline, and
  `croakf`, from Ekorn::Pipeline::Errors, which you import from their
  modules; and the operators, which only `use
  Ekorn::Pipeline::Operators` puts in force, in its own scope (see
  [Operators](#operators-ekornpipelineoperators)).

## Terms

- **Value:** anything a pipeline is given, or a stage returns. `undef`,
  0 and the empty string are values.
- **Stage:** a code reference, another pipeline, or a part made for
  each run. A code reference is called with one value, and returns a
  list of values: none, one or several. A pipeline stands for its own
  stages (see [A pipeline as a stage](#a-pipeline-as-a-stage)). A part
  made for each run is a gather, a sink, or anything offering a
  stage's or a sink's role method (see [Delivering parts for
  Ekorn](#delivering-parts-for-ekorn)).
- **Pipeline:** a list of stages, made with `Ekorn::Pipeline->new`
  or the word `pipeline`.
- **Name:** a name a pipeline is kept under, with `named`, so that
  `pipeline` and `named` can take it where they take a stage. A name
  is in a package, which says whose it is (see [Named
  pipelines](#named-pipelines)).
- **Word:** a short function that makes one of Ekorn's types, such as
  `pipeline` or `source {...}`, from Ekorn::Pipeline::Factories.
- **Run:** one call of a pipeline with values, or one iterator made
  from it. Gathers, sources and sinks are made afresh for each run.
- **Source:** what an iterator pulls values from: a code reference,
  called with nothing, returning the next value or values, or an empty
  list when there are no more; or a source made for each run, which is
  told when the run ends (see [Sources](#sources-ekornpipelinesource)).
- **Sink:** a part that consumes every value and, when they run out,
  gives its result: one value, such as a count, for a sink of one, or a
  list, such as every value, for a sink of many. Usually the last
  stage, when its result is what the run gives (see
  [Sinks](#sinks-ekornpipelinesink)).
- **Made for a run:** made afresh at the start of each run, by a
  set-up block, so that each run has state of its own. Gathers,
  sources and sinks are.
- **Result:** a value that comes out of the last stage.
- **Stop:** the exception a stage throws to end its run early, with
  `Stop` or `Ekorn::Pipeline::Stop->throw`.
- **Flush:** what a gather or a sink does when its input runs out:
  what it returns goes on through the stages after it. A gather's held
  values, a sink's result. v0.2.0 called a gather's flush its *end
  function*.
- **End:** a function a gather, a source or a sink can have, called
  once, when the run has ended, told how.
- **How a run ended:** `done`, `stopped` or `died`, as each part of
  the run sees it from where it stands (see [How a run
  ends](#how-a-run-ends)).

## Pipelines: Ekorn::Pipeline

```perl
use Ekorn::Pipeline;
use Ekorn::Pipeline v0.1.3 qw(is_stage);
use Ekorn::Pipeline v0.3.0 qw(is_sink);
```

It exports nothing by default, and `is_stage` and `is_sink` on
request. `is_stage` is new in v0.1.3, so ask for that version on the
`use` line, as above. Without it, `use Ekorn::Pipeline qw(is_stage)`
compiles under v0.1.2, which has no `import`, and fails only when
`is_stage` is called. `pipeline_in`, `named` and `is_sink` are new in
v0.3.0. The word `pipeline`, which makes a pipeline whose stages can
be names, is in [Factories](#words-ekornpipelinefactories).

A subclass inherits its `import`, Exporter's, so `use My::Pipeline;`
imports nothing, and `use My::Pipeline qw(name)` croaks unless the
subclass exports `name` itself. Before v0.1.3, a subclass ignored the
list.

### new

```perl
my $p = Ekorn::Pipeline->new(@stages);
```

Returns a pipeline that runs values through `@stages`, in order. Each
stage must be something [is_stage](#is_stage) is true for: a code
reference, a pipeline, or a part offering a stage's or a sink's role
method, such as a gather or a sink. Anything else croaks, naming its
position: "Expected stage #2 to be a code reference or a pipeline". A
source croaks too: "Expected stage #2 to be a stage, not a source".

Any code reference will do: an anonymous `sub`, a reference to a named
one such as `\&trim`, or a stage made by a function such as
`take(10)`. So will a stage made with `gather`, and a sink, usually
last (see [Sinks](#sinks-ekornpipelinesink)).

With no stages, a pipeline returns its values unchanged.

### A pipeline as a stage

You can give `new` a pipeline wherever it takes a stage. Its stages
are spliced in where it stands:

```perl
my $clean = Ekorn::Pipeline->new(
    sub { s( \A \s+ | \s+ \z )()xgr },
    sub { length ? $_ : () },
);
say join '|', Ekorn::Pipeline->new(
    $clean,
    take(2),
)->(' a ', '  ', 'b ', 'c');
# a|b
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
stage, as [Calling a pipeline from a
stage](#calling-a-pipeline-from-a-stage) shows.

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

A pipeline ending in a sink gives the sink's result instead. In list
context, that's the sink's list, or a sink of one's one value. In
scalar context, a sink of one gives its value, and a sink of many its
list as an array reference:

```perl
use Ekorn::Pipeline::Sinks qw(count_items keep_all);

my $n    = Ekorn::Pipeline->new(count_items)->('a', 'b');
my $kept = Ekorn::Pipeline->new(keep_all)->('a', 'b');
say "$n: @$kept";    # 2: a b
```

Each call is a run. You can call a pipeline as often as you like, even
from inside one of its own stages.

### iterator

```perl
my $next = $p->iterator($source);
while (my($result) = $next->()) { ... }
```

Returns an iterator, an object called as a code reference, that hands
out the results one per call, pulling values from `$source` as they're
needed. `$source` is a code reference called with no arguments, which
returns the next value, several values, or an empty list when there are
no more; or anything offering `EKORN_SOURCE`, such as a source made for
each run (see [Sources](#sources-ekornpipelinesource)), or another
iterator. Given anything else, `iterator` croaks "Expected a code
reference".

- The source is called only when a result is wanted, and only once the
  values from its last call have all gone through the stages. A source
  reading a file, a socket or a database reads no more than its caller
  asks for.
- The iterator returns one result per call. Once the results run out,
  it returns an empty list, on every call. Read it in list context, as
  `my($x) = $next->()`, so that a result of `undef`, 0 or `''` isn't
  taken for the end.
- Once the source has returned an empty list, or a stage has stopped
  the pipeline, the source isn't called again.
- The flushes of gathers and sinks are called once their input runs
  out, before the iterator returns an empty list, and the ends as the
  run ends (see [Runs and how they end](#runs-and-how-they-end)).
- If a stage or a flush dies, the call dies with it, and the iterator
  has ended, as a pushed run does. Every call after returns an empty
  list. Nothing waiting goes on, no flush is called, and the source
  isn't called again; each end is told `died`. So a flush such as
  `collect`'s never reports on a run that lost values. To skip a bad
  value and carry on, catch the error inside the stage, as in the
  user guide's "Catch errors in a stage, but let a stop through".
- The iterator has methods to read every value still to come, or only
  the first, to end the run early, and to say how it ended (see
  [Iterators](#iterators-ekornpipelineiterator)).

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

The list can go anywhere stages go: to `new`, or to a function that
takes stages. Each is one of Ekorn's types, an object called as a code
reference: a code reference given to `new` comes back as an
Ekorn::Pipeline::Stage of it (see [Stages and
elements](#stages-and-elements)). So a function that takes only plain
code references, testing them with `is_coderef` or `ref`, won't take
them; v0.2.0 gave the code references themselves. To give `new` the
pipeline itself, see [A pipeline as a stage](#a-pipeline-as-a-stage).

```perl
my $clean = Ekorn::Pipeline->new(
    sub { s( \A \s+ | \s+ \z )()xgr },
    sub { length ? $_ : () },
);
say join '|', Ekorn::Pipeline->new(
    $clean->stages,
    take(2),
)->(' a ', '  ', 'b ', 'c');
# a|b
```

Either way, the stages run as if they had been written out in full:

- A stop in one of them ends the whole run, and the source isn't called
  again.
- A `gather` stage starts afresh on each run, so pipelines that share
  it, or use it twice, don't share its state. A plain closure is the
  same code reference wherever it goes, so anything it keeps is
  shared. Keep state in `gather` instead.
- A stage that dies is named by its position, as [A pipeline as a
  stage](#a-pipeline-as-a-stage) describes.

Calling a pipeline from a stage is different: each call is a run of
its own, as [Calling a pipeline from a
stage](#calling-a-pipeline-from-a-stage) explains.

### name

```perl
my $name = $p->name;
```

Returns the first name the pipeline was given with [named](#named),
qualified by its package, as `main::clean`, or `undef` if it has none.
Errors in its stages name it (see [When a stage
dies](#when-a-stage-dies)). It's new in v0.3.0.

### pipeline_in

```perl
Ekorn::Pipeline->pipeline_in($package, @stages)
```

Returns a new pipeline of its invocant's class, of `@stages`, each a
code reference, a pipeline, or the name of one, looked up in
`$package`, as [Named pipelines](#named-pipelines) explains. It's the
only method that reads names, and it's what the word
[pipeline](#pipeline) calls, with its caller's package.

Given one name and nothing else, it returns the pipeline named itself,
not a new one, if it's of the invocant's class or a subclass, so a
stage of it, given second in another pipeline, is numbered `#2.2`, as
it stands, not `#2.1.2`. A pipeline named that isn't of the invocant's
class is held in a new pipeline of it, as before. That's new in
v0.3.0.

Call it from code the user calls directly, passing the user's package,
as the word does with `scalar caller`. Code that passes stages
through, such as a function taking stages from its caller, gives them
to `new`, which reads no names: the user has already turned any names
into pipelines with `pipeline`, where they wrote them. If `new` read
names, it would look them up in the package of whatever called it,
which, for a function passing its caller's stages on, isn't the
caller's.

### named

```perl
Ekorn::Pipeline->named(clean => @stages);         # define from stages
Ekorn::Pipeline->new(@stages)->named('clean');    # name one you have
```

Names a pipeline, and returns it. On the class, it makes a pipeline of
the stages after the name, which `pipeline` would take, names
included, looked up in its caller's package, so a pipeline can be
defined from others. A subclass makes one of its own class. On a
pipeline, it names that one, and croaks if given stages after the
name.

The name is kept in the caller's package, unless it's qualified, as
[Named pipelines](#named-pipelines) explains. A name is identifiers,
as Perl's, joined by `::`, such as `clean`, `clean_2` or
`My::Module::clean`. Anything else croaks: "Expected a name, made of
words joined by ::".

A name can't be defined twice, whatever class `named` is called on.

```perl
use Ekorn::Pipeline::Factories qw(pipeline);

Ekorn::Pipeline->named(trimmed  => sub { s( \A \s+ | \s+ \z )()xgr });
Ekorn::Pipeline->named(nonempty => sub { length ? $_ : () });
Ekorn::Pipeline->named(cleaned =>
    'trimmed',
    'nonempty',
);

say join ',', pipeline('cleaned')->(' a ', '  ', 'b ');    # a,b
```

### Named pipelines

A named pipeline is kept for the life of the program, in a package,
which says whose name it is. These rules say which pipeline a name
means:

- **A name is kept per package.** `named` keeps it in the package that
  called it, and `pipeline` and `named` look it up in the package that
  called them, so two modules can each have a `clean` of their own.
- **A qualified name is another package's.** `My::Module::clean` names
  `clean` in My::Module, wherever it's used. Code that names or looks
  up pipelines on another package's behalf qualifies them:
  `pipeline("${package}::clean")`.
- **A name is resolved when the pipeline is made,** not when it runs.
  The pipeline it names is spliced in, as a pipeline given to `new`
  is, and its stages are named in messages by their places in each:
  `#1.2`. A name alone, `pipeline('clean')`, gives that pipeline
  itself, so it adds no level of its own. `named` on a class always
  makes a new pipeline, even of one name, so a name never aliases
  another.
- **A name can't be defined twice.** Defining it again croaks: "A
  pipeline named main::clean is already defined", whatever class
  `named` was called on. Naming the same pipeline again, with
  `$p->named('clean')`, is no mistake. But `named` on a class always
  makes a new pipeline, even from a single pipeline, so
  `Ekorn::Pipeline->named(clean => $p)` twice croaks.
- **A name can't be removed.** Define each once, as a program or module
  loads, not in a sub that may be called again.
- **A pipeline, once made, keeps what it found.** As a name is looked
  up when the pipeline is made, a name defined or overridden later
  never changes a pipeline already made.
- **Only `pipeline_in`, which the word `pipeline` calls, and `named`
  read names.** `new` doesn't, and `is_stage` is false for a string, so
  a function finding its stages with `is_stage` never takes a value
  such as `'clean'` for one.

### is_stage

```perl
use Ekorn::Pipeline v0.1.3 qw(is_stage);

is_stage($thing)
```

True if `$thing` can be used as a stage: a code reference; a pipeline
of Ekorn::Pipeline or a subclass; or an object offering one of the role
methods `EKORN_STAGE`, `EKORN_SINK_ONE` and `EKORN_SINK_MANY`, such as
a stage made with `gather`, or a sink. It's the same test [new](#new)
uses. It's false for a string, even the name of a pipeline, and for a
source. It's exported on request.

Use it in a function that takes its stages from the end of its
arguments, so that it accepts the same stages `new` does, pipelines
included. [Writing functions that take
stages](#writing-functions-that-take-stages) has an example.

```perl
say join ' ', map { is_stage($_) ? 'yes' : 'no' }
    sub { $_ }, take(1), Ekorn::Pipeline->new, 'x', [];    # yes yes yes no no
```

### is_sink

```perl
use Ekorn::Pipeline qw(is_sink);

is_sink($thing)
```

Returns `one` if `$thing` is a sink of one, giving one value, and
`many` if it's a sink of many, giving a list; for a pipeline, the sink
it ends in, if any. Both are true. It's false for anything else. A sink
is anything offering `EKORN_SINK_ONE` or `EKORN_SINK_MANY`. It's
exported on request, and new in v0.3.0.

```perl
say join ' ', map { is_sink($_) || 'no' } count_items, keep_all, sub { $_ };    # one many no
```

### ending

```perl
Ekorn::Pipeline::ending()
```

True while a flush runs, and while the values it gave go through the
stages after it, rather than values from the source or the values a
pipeline was called with. It isn't exported.

It's for code that tells its stages more about each value, such as
where it came from. A value from a flush has no such origin.
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
one of the inner pipeline's own flushes is called.

### run_context

```perl
Ekorn::Pipeline::run_context()
```

Returns the context the run's source gave, if any: its `context`, or
the third part its `EKORN_SOURCE` returned as a list, such as a
statement's column names. It's for stages that need to know about the
values' source, called as they run. Each run has its own. A pushed run
has none, and an iterator used as a source passes on its own run's. It
isn't exported, and is new in v0.3.0. [Stages that ask about their
run](#stages-that-ask-about-their-run) has an example.

## Words: Ekorn::Pipeline::Factories

```perl
use Ekorn::Pipeline::Factories qw(pipeline stage gather source generator yield sink_one sink_many);
use Ekorn::Pipeline::Factories qw(:all);
```

The words make Ekorn's types, from what you write. Each is a short,
keyword-like function, one line over a class method: syntax, not
behaviour, so it lives here, not in the class it makes. A package
built on Ekorn uses them as they are (see [Delivering parts for
Ekorn](#delivering-parts-for-ekorn)). Nothing is exported by default.
Each is new in v0.3.0.

| Word | Makes | Its block |
|---|---|---|
| `pipeline(@stages)` | a pipeline | (takes a list) |
| `stage {...}` | a Stage | the stage itself |
| `gather {...}` | a Gather | a set-up, returning the step, and, optionally, the flush and the end |
| `source {...}` | a Source | a set-up, returning the step, and, optionally, the end and a context |
| `generator {...}` | a Source | a block, called once each run, giving every value it passes to `yield` |
| `sink_one {...}` | a Sink of one | a set-up, returning the step, the flush, giving the result, one value, and, optionally, the end |
| `sink_many {...}` | a Sink of many | the same, its flush giving a list |

A word given something other than a block or code reference croaks
"Expected a code reference". Each passes on the messages of the class
it makes.

`gather {...}` is the same `gather` that Ekorn::Pipeline::Gather
exports, as it always has, and is described with it (see
[gather](#gather)).

### pipeline

```perl
pipeline(@stages)
```

Returns a new pipeline of `@stages`, each a code reference, a pipeline,
or the name of one, looked up now, in the package that called
`pipeline`, unless it's qualified; or, given one name alone, the
pipeline it names, itself, as [pipeline_in](#pipeline_in) describes:

```perl
# A new pipeline, from stages:
pipeline(
    sub { uc },
    take(5),
);

# The pipeline named clean, itself:
pipeline('clean');

# A new pipeline: the one named clean, then more stages:
pipeline(
    'clean',
    take(5),
);

# Another package's, qualified:
pipeline(
    'My::Module::clean',
    sub {...},
);
```

It's `Ekorn::Pipeline->pipeline_in(scalar caller, @stages)` (see
[pipeline_in](#pipeline_in)). A name is looked up when the pipeline is
made, as [Named pipelines](#named-pipelines) explains, so one not
defined croaks then: "No pipeline named main::clean". Anything that
isn't a code reference, a pipeline or a name croaks, naming its
position: "Expected stage #2 to be a code reference, a pipeline or the
name of one".

Being short, it's handy for passing stages as one pipeline, given
last. A function whose values can be code references can't tell them
from stages with `is_stage`, but it can take a pipeline given last as
its stages, as [Writing functions that take
stages](#writing-functions-that-take-stages) shows.

### stage

```perl
stage { BLOCK }
stage sub ($row) { ... }
```

Returns a Stage: the block, called with each value, as any stage is.
It's an object called as a code reference, so it goes wherever a stage
does. To give it a signature, give it a sub. A Stage keeps what it's
given, so `stage(\&trim)` never changes `trim` itself.

### source

```perl
source { SET-UP }
```

Returns a Source made for each run, as
[Sources](#sources-ekornpipelinesource) describes. Its set-up returns
its step, called with nothing, again and again, giving the next value
or values, or an empty list when there are no more; optionally, its
end, told how the run ended; and, optionally, a context for the run,
which its stages ask for with [run_context](#run_context). With a
context but no end, give `undef` for the end.

```perl
sub up_to ($last) {
    return source {
        my $n = 0;    # this run's
        return sub () { $n < $last ? ++$n : () };
    };
}

my $next = Ekorn::Pipeline->new(sub { $_ * 10 })->iterator(up_to(3));
while (my($n) = $next->()) { say $n }    # 10, 20, 30
```

Each run counts from 1 again, as the set-up runs at its start. The
source in [Made for a run](#made-for-a-run) has an end. A source with
nothing to set up or end needs no word: any code reference is a
source.

### generator and yield

```perl
my $pairs = generator {
    for my $x (1 .. 3) {
        for my $y ($x .. 3) { yield [$x, $y] }
    }
};
say join ' ', map { "($_->[0],$_->[1])" } Ekorn::Pipeline->new->iterator($pairs)->all;
# (1,1) (1,2) (1,3) (2,2) (2,3) (3,3)
```

`generator` returns a Source giving what its block passes to `yield`,
as a Python generator does. Perl can't pause a sub at `yield`, so each
run calls the block once, to its end, and gives every value it yielded
in one step: the block mustn't loop without end, and runs to its end
even when a stage after it takes only some. For a producer without
end, write a `source {...}` whose step gives a value each call.
`yield` croaks "Expected yield to be called inside a generator" when
it's called outside one, and a generator read inside another's block
keeps its own.

An empty block, `generator {}`, reads as an empty hash: write
`generator { return }`.

### sink_one and sink_many

```perl
sink_one { SET-UP }
sink_many { SET-UP }
```

Returns a Sink, made for each run, as
[Sinks](#sinks-ekornpipelinesink) describes. Its set-up returns its
step, called with each value, whose return is ignored; its flush,
called when its input runs out, giving its result; and, optionally,
its end, told how the run ended. A sink made with `sink_one` gives one
value; one made with `sink_many`, a list. Asked for one value, a
pipeline ending in a sink of many gives its list as an array
reference, so write a sink of one value with `sink_one`.

```perl
my $longest = sink_one {
    my $max;
    return (
        sub ($s) { $max = $s if length $s > length($max // '') },
        sub ()   { $max },
    );
};

say Ekorn::Pipeline->new($longest)->(qw(a bbb cc));    # bbb
```

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
made from it. At the start of each run, the set-up of every gather,
source and sink is called, so what they keep starts afresh (see [Made
for a run](#made-for-a-run)). An iterator's run starts when the
iterator is made, not when it's first read.

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
my $trim = Ekorn::Pipeline->new(
    sub { s( \A \s+ | \s+ \z )()xgr },
    sub { length ? $_ : () },
);
say join '|', Ekorn::Pipeline->new(sub { $trim->($_) })->(' a ', '  ', 'b ');    # a|b
```

Each call of the inner pipeline is a run of its own. Its `gather`
stages start afresh on each value the outer stage is given, and its
flushes and ends are called at the end of each call. A stop in it ends
only that call, not the outer pipeline. To run its stages in the outer
pipeline's run instead, give the pipeline itself as a stage (see
[A pipeline as a stage](#a-pipeline-as-a-stage)).

## Runs and how they end

A run is one call of a pipeline with values, or one iterator made from
it. Each run has its own state. A part of the pipeline that needs
state, such as a batch it's filling or a file it has open, is made
afresh for each run, and can be told when the run ends, however it
ends, so it can close the file, or commit what it wrote.

### Made for a run

A gather, a source or a sink, made with a
[word](#words-ekornpipelinefactories), has a block that's its
**set-up**. The set-up runs at the start of each run. It declares
whatever the run needs, with `my`, and returns closures sharing what
it declared:

- **the step,** called with each value (a gather or a sink), or each
  time the source is pulled (a source);
- **the flush,** for a gather or a sink, called once its input runs
  out, what it returns going on through the stages after it. A sink's
  gives its result, and is required;
- **the end,** called once, when the run has ended, told how. It's
  optional;
- **a context,** for a source only, and optional: anything its stages
  may ask for with [`run_context`](#run_context).

```perl
use Ekorn::Pipeline::Factories qw(source);

sub lines_of ($path) {
    return source {
        open my $fh, '<', $path or die "Can't read $path: $!\n";    # this run's
        return (
            sub ()     { my $line = readline $fh; defined $line ? $line : () },
            sub ($how) { close $fh },
        );
    };
}
```

Two iterators of the same pipeline each get their own filehandle, from
their own call of the set-up. A plain code reference is never made for
a run: it's the same code, with the same closure, in every run.

The set-up returns its parts as a list, in the order above, leaving
out those it doesn't give from the end, and giving `undef` for one it
leaves out before one it gives. Or it returns them **by name,** as a
hash reference whose keys are `step`, `flush`, `end` and `context`,
giving only those it has, in any order:

```perl
use Ekorn::Pipeline::Factories qw(gather);

sub counted_into ($total) {
    return gather {
        my $n = 0;    # this run's
        return {
            step => sub ($x)   { $n++; $x },
            end  => sub ($how) { $$total = $n },
        };
    };
}

my $count;
Ekorn::Pipeline->new(counted_into(\$count))->(qw(a b c));
say $count;    # 3
```

A key Ekorn doesn't read is ignored, and a hash without what its part
needs, a step, and a sink's flush, croaks, as a list without them
does. Only a plain hash reference returned alone is taken for parts by
name. Parts by name are new in v0.3.0.

### How a run ends

A run ends in one of three ways, and each part's end is told which,
from where the part stands: `died` if the run died, anywhere, before
it ended; `stopped` if its input was cut short, by a stop at or after
it, or by the run being ended from outside; and `done` if its input
ran out, and the run didn't die. A part whose input had run out before
a stop is told `done`, and so is a sink that stops the run itself. For
the commonest runs:

| The run | The source, and the stages up to and including the one that stopped | The stages after it |
|---|---|---|
| ran out of values | `done` | `done` |
| was stopped by a stage | `stopped`, if it still had values to come | `done` |
| had a stage or an end die | `died` | `died` |

A stop ends the stream early for what's before it, and normally for
what's after it. So in

```perl
use Ekorn::Pipeline::Sinks qw(count_items);

my $n = Ekorn::Pipeline->new(
    take(5),
    count_items,
)->iterator(lines_of('setlist.txt'))->();
```

the file is closed, told `stopped`, and `count_items`, after `take(5)`,
is told `done`, and gives 5.

### Flushes and ends

A flush, a gather's or a sink's, is called once its input runs out
normally: when the values ran out, after a stop in a stage before it,
or, for a sink, when the sink stopped the run itself. What it returns
goes on through the stages after it, and while it runs, and they do,
[`ending`](#ending) is true. The flush of a sink of one gives one
value, `undef` if it has none. It isn't told how the run ended, as the
run hasn't.

An end:

- **always runs, once, when the run has ended,** however it ended, and
  is given how, as its argument: `done`, `stopped` or `died`. A run
  has ended as soon as nothing in it can still act on a value, so with
  a sink last, it ends as the sink's result is ready, and a sink that
  commits only when told `done` commits then, and never for a run that
  dies after it;
- **gives nothing:** what it returns is dropped;
- **runs in order:** the source's end first, then each stage's, first
  stage first, so a source that fails to close is known before any
  sink commits.

After a stage dies, every end still runs, told `died`, and then the
error is thrown again, as it would have been. An end that dies then is
reported as a warning, naming its stage, and the first error is kept.
An end that dies in a run that hadn't died ends the run with its error,
"Pipeline end of stage #2 failed at ...", and the ends after it are
told `died`.

### Sources: Ekorn::Pipeline::Source

```perl
use Ekorn::Pipeline::Source;

my $source = Ekorn::Pipeline::Source->new($setup);
```

Returns a source made afresh for each run by `$setup`, a code
reference. Anything else croaks "Expected a code reference". The
set-up returns the source's step, and optionally its end and a
context, as a list or by name (see [Made for a run](#made-for-a-run)).
Its step is called with nothing each time the run wants more values,
and returns the next value or values, or an empty list at the end. It
can also stop the run, with `Stop`, when it's had enough: the
values its stop carries are its last, and it's told `done`.

The word [source](#source) makes one from a block. A source goes to
[iterator](#iterator). It isn't a stage, and given to `new` as one, it
croaks. Called directly, as a code reference, it croaks "Expected a
source to be read through iterator": a run of its own would never be
ended, so what it opened would stay open.

`$source->EKORN_SOURCE` calls the set-up for a new run, and returns
what it returns. A run calls it as it starts; you needn't.

### Sinks: Ekorn::Pipeline::Sink

```perl
use Ekorn::Pipeline::Sink;

my $total = Ekorn::Pipeline::Sink->new_sink_one(sub {
    my $sum = 0;    # this run's
    return (sub ($x) { $sum += $x }, sub () { $sum });
});

say scalar Ekorn::Pipeline->new(
    sub { $_ * 2 },
    $total,
)->(1 .. 4);
# 20

say scalar $total->(1 .. 4);    # 10
```

A sink consumes every value it's given and, when they run out, gives
its result: one value, such as a count, for a **sink of one**, made
with `new_sink_one`, or a list, such as every value, for a **sink of
many**, made with `new_sink_many`. Each takes a set-up, a code
reference, and croaks "Expected a code reference" given anything else.
The set-up returns:

- the step, called with each value, in `$_` and as its argument. What
  it returns is ignored;
- the flush, called with nothing, once its input runs out, giving the
  result. It's required;
- optionally, the end, told how the run ended.

It returns them as a list, or by name (see [Made for a
run](#made-for-a-run)).

A sink is usually a pipeline's last stage, so that its result is what
a run gives (see [Calling a pipeline](#calling-a-pipeline)). Anywhere
else, its result goes on through the stages after it. Its step can
stop the run, with `Stop`, once it has all it wants: it still gives its
result, and is told `done`.

The words [sink_one and sink_many](#sink_one-and-sink_many) make them
from a block. A sink can be called as a code reference with values, as
a pipeline of the one sink would be, and gives its result, from a
fresh sink of its set-up each time.

Called on a subclass with an `EKORN_SINK_ONE` or `EKORN_SINK_MANY`
method of its own, `new_sink_one` or `new_sink_many` makes the
subclass; otherwise, an Ekorn::Pipeline::Sink::One or
Ekorn::Pipeline::Sink::Many. `$sink->EKORN_SINK_ONE`, or
`EKORN_SINK_MANY`, calls the set-up for a new run; you needn't.

### Iterators: Ekorn::Pipeline::Iterator

An iterator, made by [iterator](#iterator), is one run. Called as a
code reference, `$next->()`, it hands out the next value. It has
methods of its own:

```perl
my @rest  = $next->all;       # every value still to come; read to the end
my $rest  = $next->all;       # the same, as an array reference
my $first = $next->first;     # the next value, or undef; then the run ends
my $one   = $next->single;    # the next value, or undef, warning if there's another; then the run ends
$next->finish;                # end the run now
my $how   = $next->ended;     # done, stopped or died, once there's nothing more to come
```

- **`all`** reads the run to its end, and returns every value still to
  come: a list, or, in scalar context, an array reference. Values
  already waiting at the end, such as a sink of many's result, it takes
  at once.
- **`first`** returns the next value, or `undef` if there's none, and
  ends the run, as `finish` does, so nothing more is read, and a source
  holding a resource, such as a statement's lock, lets it go.
- **`single`** does as `first` does, but pulls one value more to check
  there's no other, and warns "Expected only one item, but there were
  more" if there is.
- **`finish`** ends the run now, if it hasn't ended: nothing more is
  read, and nothing waiting is handed out. Each end is told how from
  where it stands: `stopped`, if its input hadn't run out. Every call
  after returns an empty list.
- **`ended`** says whether the source was read to its end: nothing
  until the iterator has given all it will, been finished or died;
  then `done` if it was, `stopped` if a stop anywhere, such as
  `take(5)`'s, or `finish`, cut the reading short, or `finish` dropped
  values still to be handed out, and `died` if anything died.

An iterator that's dropped before its values run out ends its run when
the last reference to it goes, as `finish` does:

```perl
my($first) = Ekorn::Pipeline->new(sub { uc })->iterator(lines_of('setlist.txt'))->();
# the file is closed here, as the iterator has gone
```

Perl destroys a lexical iterator as soon as it goes out of scope. One
kept until the program ends is destroyed during global destruction,
when the order of destruction isn't guaranteed, so an end mustn't rely
on other objects then.

Each `$next->()` goes through Perl's overloading of `&{}` to find the
iterator's code. A loop pulling many values can take the code
reference once, and call it directly:

```perl
my $pull = \&$next;    # the iterator's code, found once
while (my($value) = $pull->()) { ... }
```

Keep `$next` while you use `$pull`: the code reference doesn't keep
the iterator, and an iterator let go ends its run, after which `$pull`
gives nothing. Over 300,000 values, this saves about 0.03 s.

An iterator is a source too, so it can be given to another pipeline's
`iterator`. Its values go through the second pipeline's stages, its
run ends when the second run ends, and the second run's stages see its
run's context. It's one run, so it can be a source only once, before
it has handed out everything it will; after, it croaks "Expected a
source with values still to give: an iterator is one run, and this one
is spent".

### Stages and elements

`new` keeps each code reference it's given as an
**Ekorn::Pipeline::Stage**, so that every part of a pipeline is one of
Ekorn's types. You needn't make one, but
`Ekorn::Pipeline::Stage->new($code)` does, from a code reference or an
object called as one; `$stage->code` gives back what it was made of.
Called directly, a stage calls its code with what it's given, but
doesn't set `$_`: only a run does.

Each of Ekorn's types, a pipeline, a stage, a gather, a source, a sink
and an iterator, is an **Ekorn::Pipeline::Element**: an object called
as a code reference, which holds the closure it's called as, so it's
freed as soon as nothing else holds it. `$element->call(@arguments)`
does what calling it does.

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
- The flushes of the stages after the one that stopped are called, in
  order. They get the values from before the stop, and the values it
  carries. The flushes of the stage that stopped, and of the stages
  before it, aren't called. Every end is, as the run ends: told
  `stopped` up to the stage that stopped, if its input was cut short,
  and `done` after it (see [How a run ends](#how-a-run-ends)).

```perl
my @seen;
my @out = Ekorn::Pipeline->new(
    sub { push @seen, $_; $_ == 3 ? Stop('three') : $_ },
    sub { uc },
)->(1 .. 5);
say "@out; saw @seen";    # 1 2 THREE; saw 1 2 3
```

A flush can stop the pipeline too. The values its stop carries go on
through the stages after it, and the flushes after it are still
called. An end can't: the run has ended, and a stop there is an error,
"Expected no stop in an end, as the run has ended".

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
each run, and a call when its values run out. `gather` makes such a
stage.

### gather

```perl
my $stage = gather { ...; return ($step, $flush, $end) };
my $stage = gather { ...; return ($step, $flush) };
my $stage = gather { ...; return $step };
my $stage = gather { ...; return {step => $step, end => $end} };
```

Returns a stage that a pipeline makes afresh at the start of each run,
by calling the block. Whatever the block declares is fresh on each
run. The block returns:

- the step: a code reference, called with each value like any stage,
  or a pipeline (see [A pipeline as the stage](#a-pipeline-as-the-stage));
- optionally, the flush, called once its input runs out;
- optionally, the end, called once the run has ended, told how (see
  [Flushes and ends](#flushes-and-ends)). Pass `undef` for the flush
  to have only an end, or return the parts by name (see [Made for a
  run](#made-for-a-run)).

`gather` croaks "Expected a code reference" if it's given something
other than a block or code reference. The block is called when a run
starts, not when `gather` is called: when the pipeline is called with
values, or an iterator is made from it. A block that returns anything
else is reported then, as "Expected stage #%s, made with gather, to
return a code reference or a pipeline, and optionally a flush and an
end".

What `gather` returns is an Ekorn::Pipeline::Gather, an object that
can go wherever a stage can. Its `EKORN_STAGE` method calls the block,
for a new run; a run calls it as it starts, and you needn't.
`Ekorn::Pipeline::Gather->new($block)` makes one as `gather` does.

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

### The flush

A gather's flush is called with no arguments, and with `$_` undefined,
once its input runs out. In a pushed run, that's after the last value
has gone through. With an iterator, it's once the source returns an
empty list, or after a stop before it. What it returns goes on through
the stages after its own, just like what a stage returns: nothing, one
value, or several. It's what v0.2.0 called the *end function*, and a
gather written for v0.2.0 works as it did.

- It's called even when no values went by, so a flush can give an
  empty result, such as `[]`, or nothing at all.
- The flushes are called in order, first stage first. What one returns
  goes through the stages after it, and their flushes see it, before
  the next flush is called. So a `collect` after a `batch` gets
  `batch`'s last, short batch.
- After a stop, only the flushes of the stages after the one that
  stopped are called (see [What a stop does](#what-a-stop-does)).
- While the values a flush returns go through the stages,
  [`ending`](#ending) is true.
- A flush that dies is reported as its stage would be, by the stage's
  position.

A gather's end, its third, is told how the run ended, as every end is
(see [Flushes and ends](#flushes-and-ends)).

```perl
sub average () {
    return gather {
        my($sum, $n) = (0, 0);
        my $step  = sub ($x) { $sum += $x; $n++; return };
        my $flush = sub ()   { $n ? $sum / $n : () };
        return ($step, $flush);
    };
}

say Ekorn::Pipeline->new(average())->(2, 4, 9);    # 5
say scalar Ekorn::Pipeline->new(average())->();    # 0
```

The second line prints 0, the number of results. With no values, the
flush returns nothing.

### A pipeline as the stage

A pipeline returned by a `gather` block as its stage has its stages
made for the run in its place, as if they had been given there. A
`gather` stage inside it is made afresh too, and a stop inside it ends
the whole run. So the block can build a pipeline for each run, or
choose one:

```perl
my $run   = 0;
my $alter = Ekorn::Pipeline->new(gather {
    Ekorn::Pipeline->new(
        $run++ % 2 ? sub { uc } : sub { lc },
        take(2),
    );
});
say join ' ', $alter->(qw(A b C));    # a b
say join ' ', $alter->(qw(A b C));    # A B
```

The block's flush, if it returns one, is called after the flushes of
the pipeline's own stages, and its end after their ends. A stage
inside the pipeline is named in messages by its position in each, as
`#2.3` for the third stage of the pipeline returned by stage #2.

> **For stage authors:** a stage that holds values should give them
> up in its flush, as `batch` and `collect` do, so none are lost when
> the values run out. Give the flush an empty signature, `sub ()`.

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
comes out of the last stage. The stages are what `new` takes: code
references and pipelines, not names. To use a named pipeline, pass
`pipeline('clean')`. In scalar context, it returns the first
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

Each stage is an object, an Ekorn::Pipeline::Stage or, for those made
with `gather`, an Ekorn::Pipeline::Gather, called as a code reference,
so it goes wherever a stage goes (see [Stages and
elements](#stages-and-elements)). Code testing one with `ref` or
`is_coderef` sees an object: v0.2.0 gave code references.

Each `keep` sink but `keep_all` has a `take` stage that passes on what
the sink would give as its result, so the stages after it can go on:
`take($n)` is `keep($n)`'s, and `take_first`, `take_last` and
`take_single` are `keep_first`'s, `keep_last`'s and `keep_single`'s.
`keep_all`'s would pass every value on: no stage at all. A pipeline
ending in a `take` stage, where its sink was forgotten, gives the
values in list context, and how many in scalar context, never a wrong
one.

| Stage | Module | Passes on | Exported |
|---|---|---|---|
| `take($count)` | Flow | the first `$count` values, then stops | by default |
| `drop($count)` | Flow | all but the first `$count` values | by default |
| `take_first` | Flow | the first value, then stops | on request |
| `take_last` | Flow | at the end, the last value | on request |
| `take_single` | Flow | the one value; at a second, warns and stops | on request |
| `take_if { ... }` | Flow | each value the block is true of | on request |
| `drop_if { ... }` | Flow | each value the block is false of | on request |
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

#### take_first

```perl
take_first
```

Passes on the first value, then stops the pipeline: `take(1)`, named
as the stage of the sink `keep_first`.

#### take_last

```perl
take_last
```

Passes on the last value, once there are no more, reading every one to
find it; nothing if there were none. If a stage before it stops the
pipeline, it passes on the last value to reach it.

#### take_single

```perl
take_single
```

Passes on the one value. At a second, it warns "Expected only one item,
but there were more" and stops the pipeline, so the first is all that
goes on: for when one value was meant, and its limit forgotten.

```perl
say join ' ', Ekorn::Pipeline->new(take_last)->(1 .. 9);      # 9
say join ' ', Ekorn::Pipeline->new(take_single)->(1 .. 9);    # 1, with a warning
```

#### take_if

```perl
take_if { ... }
```

Passes on each value the block returns true for, and drops the rest:
a filter, as `grep` is, testing every value. The block gets each value
in `$_` and as its argument. A plain stage ending in a test, `sub {
$_ > 2 }`, passes on what the test returns, true or false, not the
value; `take_if { $_ > 2 }` passes on the value. It croaks "Expected a
code reference" if it isn't given a block or code reference. It's new
in v0.3.0.

#### drop_if

```perl
drop_if { ... }
```

Drops each value the block returns true for, and passes on the rest:
`take_if`'s opposite. The block gets each value in `$_` and as its
argument. It croaks "Expected a code reference" if it isn't given a
block or code reference. It's new in v0.3.0.

```perl
say join ' ', Ekorn::Pipeline->new(take_if { $_ % 3 })->(1 .. 9);    # 1 2 4 5 7 8
say join ' ', Ekorn::Pipeline->new(drop_if { $_ % 3 })->(1 .. 9);    # 3 6 9
```

#### take_while

```perl
take_while { ... }
```

Passes on values while the block returns true for them, then stops the
pipeline at the first value it returns false for. That value isn't
passed on. The block gets each value in `$_` and as its argument.
Unlike `take_if`, it tests no value after the first that fails, so it
reads no further. It croaks "Expected a code reference" if it isn't
given a block or code reference.

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
say join ' ', Ekorn::Pipeline->new(
    drop_while { $_ < 3 },
    take_while { $_ < 6 },
)->(1 .. 9);
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
say Ekorn::Pipeline->new(collect { join '+', @_ })->(1 .. 3);    # 1+2+3
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

## Sources: Ekorn::Pipeline::Sources

```perl
use Ekorn::Pipeline::Sources qw(from_array from_fh from_file counter);
use Ekorn::Pipeline::Sources qw(:all);
```

Ready-made sources, needing nothing beyond Perl, for
[iterator](#iterator). Each returns a Source, made afresh for each
run, so each run reads from the start. Nothing is exported by default.
Each is new in v0.3.0.

| Source | Gives | Its end |
|---|---|---|
| `from_array(@values)` | the values given | none |
| `from_fh($fh)` | a filehandle's records, as `$/` divides them: its lines, unless `$/` is changed, or all of it as one record if `$/` is undefined; each without the separator, as `chomp` removes it | none: you opened it, so you close it |
| `from_file($path)`, `from_file($path, $layers)` | a file's records, as `$/` divides them: its lines, unless `$/` is changed, or the whole file as one record if `$/` is undefined, and none if it's empty; read through the I/O layers given, such as `':raw'` or `':encoding(UTF-8)'`; each without the separator, as `chomp` removes it | closes the file, however the run ends |
| `counter($start, $step)` | `$start`, then on by `$step`, without end, 1 and 1 by default: give it a `take` | none |

```perl
my $next = Ekorn::Pipeline->new(take(2))->iterator(from_file('tracks.txt'));
# reads two lines, then closes the file
```

`from_fh` and `from_file` read with `$/` as it is at each read, as
`readline` does, so a caller can read a file's paragraphs, or records
of their own, by setting it while they pull:

```perl
local $/ = '';    # paragraph mode
my $next = Ekorn::Pipeline->new(take(3))->iterator(from_file('lyrics.txt'));
while (my($verse) = $next->()) { say "$verse\n" }    # the first three verses
```

With `$/` undefined, both slurp: what's left is one record, and an
empty file gives none, though Perl's `readline` gives one empty
string. A binary file is read with `':raw'` and records of a fixed
size, `local $/ = \4096`, which `chomp` leaves whole.

`from_file` opens its file as the run starts, and croaks "Can't read
%s: %s" there if it can't. Without layers, Perl opens it as it does by
default, which on Windows translates line endings, and so corrupts a
binary file. `from_fh` croaks "Expected an open filehandle" given
anything else, and `counter` "Expected a number to start from, and one
to step by". A hash's pairs are
`from_array(map { [$_, $hash{$_}] } keys %hash)`.

## Sinks: Ekorn::Pipeline::Sinks

```perl
use Ekorn::Pipeline::Sinks qw(keep_all count_items keep_first);
use Ekorn::Pipeline::Sinks qw(:all);
```

Ready-made sinks, usually given last in a pipeline, so that a sink's
result is what the run gives (see [Sinks](#sinks-ekornpipelinesink)).
Each is made afresh for each run. Nothing is exported by default. Each
is new in v0.3.0.

They come in two families. Those named for what they give, an item
being a value, have names that can't clash with Perl's built-ins or
List::Util's, which is why they're `keep_first` and `keep_all`, not
`first` and `all`. The containers, named for where the items go, are
the `to_` sinks, each the counterpart of a `from_` source: what one
reads, the other writes.

| Sink | Gives | Stops the pull early? |
|---|---|---|
| `keep_all` | every item, as a list | no |
| `keep_first` | the first item, or `undef` if none | yes |
| `keep_single` | the one item, or `undef` if none; at a second, a warning, and the first, for when you meant one and forgot to limit it | at a second |
| `keep_last` | the last item, reading every one to find it, or `undef` if none | no |
| `keep($n)` | the first `$n` items, as a list, as `take($n)` would pass on; it croaks "Expected a count of 0 or more" as `take` does | yes, at `$n` |
| `count_items` | how many items there were | no |
| `to_fh($fh)` | prints each item to your filehandle, followed by `$/`, and gives how many | no; you opened it, so you close it |
| `to_file($path)`, `to_file($path, $layers)` | writes each item to the file, followed by `$/`, through the I/O layers given, if any, and gives how many | no; it closes the file, however the run ends |

Asked for one value, in scalar context, a sink giving a list gives it
as an array reference; for how many, use `count_items`:

```perl
my $p = Ekorn::Pipeline->new(
    sub { $_->{title} },
    keep_all,
);
my @titles = $p->(@tracks);    # every title
my $titles = $p->(@tracks);    # every title, as an array reference
```

An array reference is true even when it's empty, so test for no items
with `@$titles`, or use `count_items`.

`from_fh` and `from_file` remove `$/` from each record, and `to_fh` and
`to_file` add it back, so a file read with one is written unchanged by
the other. With `$/` undefined, or a reference to a record size, they
add nothing; with it empty, for paragraphs, a blank line:

```perl
my $copied = Ekorn::Pipeline->new(to_file('copy.txt'))->iterator(from_file('original.txt'))->();
```

There's no sink for an array or a hash: `keep_all` gives every item,
and `push @mine, @{ $p->(@values) }` adds them to your array. A hash
is assigned from a list of keys and values, so to key values by
something of their own, give each one's key and value from a stage:

```perl
my %by_title = Ekorn::Pipeline->new(sub { ($_->{title}, $_) })->(@tracks);
```

A sink that stops the pull early is told `done`: it decided the run
had enough. The source and the stages before it are told `stopped`.

```perl
say scalar Ekorn::Pipeline->new(count_items)->(1 .. 10);    # 10
say scalar Ekorn::Pipeline->new(keep_first)->iterator(counter(1, 1))->();    # 1, then stops
```

`to_fh` croaks "Expected an open filehandle" given anything else.
`to_file` opens its file, emptied, as the run starts, and croaks "Can't
write %s: %s" if it can't, as both do if they can't write, and
`to_file` if it can't close the file. Each sink taking no arguments has
an empty prototype, so `count_items + 0` reads as `count_items() + 0`.

## JSON: Ekorn::Pipeline::JSON

```perl
use Ekorn::Pipeline::JSON qw(from_json from_jsonl to_json to_jsonl);
use Ekorn::Pipeline::Tooling qw(:json);    # the same
```

Four functions, one for each direction and format, each making a
different part by its options: given a `file` or an `fh`, a `from_`
function makes a source and a `to_` function a sink; given neither,
each makes a stage. Each part is made afresh for each run. Nothing is
exported by default. All four are new in v0.3.0.

| Function | Given a `file` or an `fh` | Given neither, a stage |
|---|---|---|
| `from_json` | a source of one document: an array's elements, or the document itself; none from an empty input | decoding each value, one document, the same way |
| `from_jsonl` | a source of JSON Lines, a document a line, each as it is, read a block at a time as values are pulled | decoding each value, a text of one or more lines, into each line's document |
| `to_json` | a sink writing every value as one array, as they come, and giving how many | gathering every value, and passing on one text, the array, once they've all come |
| `to_jsonl` | a sink writing each value as a line, and giving how many | passing on each value as its line, without its newline, ready for `to_file` |

The `json` functions read and write one JSON document; the `jsonl`
functions JSON Lines, also called NDJSON. A stage passes on what a file
of its format would hold, so each `to_` function's stage is undone by
its `from_` function's:

```perl
my @lines = Ekorn::Pipeline->new(to_jsonl(json => {canonical => 1}))->({b => 1, a => 2}, [3]);
say for @lines;    # {"a":2,"b":1} then [3]
my @back  = Ekorn::Pipeline->new(from_jsonl())->(@lines);    # {b => 1, a => 2}, [3]
```

`from_json` reads its input whole, and croaks if it holds more than
one document, pointing to `from_jsonl`. `from_jsonl` keeps an array as
one value, and reads documents simply written one after another, on a
line or not, as it reads lines.

The encoder is JSON::MaybeXS's: Cpanel::JSON::XS where it's installed,
JSON::PP otherwise. Text is UTF-8 bytes, as `encode_json` and
`decode_json` have it, and files are opened `:raw`.

| Option | Is |
|---|---|
| `file` | the path of a file to read or write; opened as the run starts, emptied if it's written, and closed once the run ends, however it ended |
| `fh` | an open filehandle, which is left open; `:raw`, as the text is bytes |
| `json` | a hash reference of options for `JSON::MaybeXS->new`, over the defaults `utf8` and `allow_nonref`, such as `{canonical => 1}`; or an encoder object of your own, used as it is |

An encoder that indents, such as with `pretty`, has each value indented
in `to_json`'s array; `to_jsonl` croaks given one, as JSON Lines can't
be indented.

```perl
my $count = Ekorn::Pipeline->new(
    sub { {title => $_->{title}} },
    to_json(file => 'titles.json'),
)->(@tracks);    # 6, written as one array
my @titles = Ekorn::Pipeline->new(sub { $_->{title} })->iterator(from_json(file => 'titles.json'))->all;
```

An encoder object reading a source, or decoding in `from_jsonl`'s
stage, has its incremental parser reset for each run, so mustn't serve
two at once. JSON.pm exports a `from_json` and a `to_json` of its own
by default: a module using both imports one under another name, or
calls it by its full name.

## Operators: Ekorn::Pipeline::Operators

```perl
use Ekorn::Pipeline::Operators;
```

It puts `|`, `|=` and `@{}` in force for Ekorn's sources, stages,
gathers and chains, for the rest of the scope it's used in;
`no Ekorn::Pipeline::Operators` takes them out again. Written where
they're not in force, they croak: "Expected use
Ekorn::Pipeline::Operators in scope". They're new in v0.3.0, and a
shorthand for the commonest shapes, not the whole of Ekorn: a pipeline
made with `new` can have stages after a sink, give a list as a list,
and, pulled with `iterator`, be a source that gives a sink's result,
none of which a chain can.

| Written | Gives |
|---|---|
| `$stage \| $stage` | a chain of both stages: a pipeline, which `\|` can extend, and which goes wherever a pipeline does |
| `$source \| $stage` | a source: the source's values, through the stage |
| `$source \| ... \| $sink` | the sink's result, at once, not a source; for a source of the result, use `iterator` |
| `$chain \|= $stage` | a new chain with the stage added, put in the variable |
| `@{ $source }` | every value the source gives, read through anew each time (see [`@{}`](#-reads-a-source-through)) |

**A chain starts with one of the types,** a source or a stage made
with a word, or ready-made. What follows can be anything that goes
where a stage goes, a plain code reference or a package's own part.
Started with a plain code reference, `sub { ... } | sub { ... }` is
Perl's bitwise OR of two addresses: a meaningless number, with no
error. So start a chain with `stage { uc }`, never `sub { uc }`. A
pipeline made with `new` has no operators.

A package's own source class chains as Ekorn's do by overloading `|`
with `Ekorn::Pipeline::Operators::chain`, and `@{}` with
`Ekorn::Pipeline::Operators::drain` (see [Delivering parts for
Ekorn](#delivering-parts-for-ekorn)).

`|` binds more loosely than `.` and `+`, so put a chain inside a larger
expression in parentheses.

An operator gives one scalar, so a chain ending in a sink gives one
value: the result of a sink of one, such as `count_items`, or the list
of a sink of many, such as `keep_all`, as an array reference. Nothing
can be chained after a sink: a chain ending in one has already run,
and gives its result.

```perl
my $n      = $source | count_items;          # a number
my $titles = $source | keep_all;             # an array reference
my @titles = @{ $source | keep_all };        # a list
```

As `|` gives one value, a list assignment from a chain gets one
element: `my @titles = $source | keep_all` is the array reference
alone. Dereference it, as above.

Keep a chain's result, even one run for what its sink does:
`my $copied = $source | to_file($path)`. Written as a statement of its
own, the chain runs, but Perl warns "Useless use of numeric bitwise or
(|) in void context", as it compiles the line, which Ekorn can't stop.

### `@{}` reads a source through

`@{ $source }` gives every value a source gives, with no sink. It looks
like a dereference, but a source holds no array. Perl lets a class say
what `@{ $object }` means, with a function returning an array
reference, which Perl then dereferences. Ekorn's runs the source from
its start, collects every value into a new array, and returns a
reference to it. So:

- **Each use is a run of its own,** reading the source to its end.
  `$source->[0]`, `scalar @$source` and `$#$source` read every value,
  to give one value, a count or an index; two uses read it twice.
- **`for (@$source)` reads every value before the loop starts.** Pull
  from an iterator to take each as it comes.
- **An iterator is one run,** so it's read through once, and croaks
  the second time: "Expected a source with values still to give".
- **Only a source has it.** On a stage, or a chain of stages, Perl
  says "Not an ARRAY reference"; a chain ending in a sink is already
  its result, so `@{ $source | count_items }` dereferences a number.
- **`@{ $source | keep_all }` is Perl's own dereference,** of the
  array reference the sink gave.

What to write, by what's wanted:

| Wanted | Write | Rather than |
|---|---|---|
| every value, as a reference | `my $all = $source \| keep_all` | `my @all = $source \| keep_all`, one element |
| every value, as a list | `my @all = @{ $source \| keep_all }`, or `@{$source}` | |
| the first value | `$source \| keep_first`, reading one | `$source->[0]`, reading them all |
| how many | `$source \| count_items` | `scalar @$source`, keeping every value to count them |
| the first few | `$source \| take(5) \| keep_all` | `(@$source)[0 .. 4]`, reading them all |
| every value, added to your array | `push @mine, @{ $source \| keep_all }` | |
| each, as it comes | `my $next = Ekorn::Pipeline->new->iterator($source)`, then `while (my ($value) = $next->()) {...}` | `for (@$source) {...}`, reading them all first |

```perl
my @all   = @{$source};               # every value
my $first = $source | keep_first;     # the first, reading only one
my $next  = Ekorn::Pipeline->new->iterator($source);
while (my ($value) = $next->()) {     # each, as it comes
    say $value;
}
```

## Errors: Ekorn::Pipeline::Errors

### When a stage dies

A stage, or a flush, that dies with a message is named by its
position, counting from 1 (`#2.3` for one inside a pipeline given as a
stage). It's reported at the line that ran the pipeline: the call of
the pipeline, or of the iterator that asked for the result. The
message it died with follows, indented by four spaces:

```text
Pipeline stage #2 failed at app.pl line 12:
    No name for user 7 at app.pl line 9.
```

A stage within a named pipeline, or of the named pipeline run, is
named with it too: after its position, the innermost named pipeline
it's in, by its [name](#name), and its position there. The second
stage of the pipeline named `clean`, given as the first stage, is:

```text
Pipeline stage #1.2 (main::clean#2) failed at app.pl line 12:
```

It's the name the pipeline has when the stage dies. An end that dies
is named the same way, as "Pipeline end of stage #1.2 (main::clean#2)
failed at ...". Before v0.3.0, a stage was named by its position
alone.

An exception object, such as a stop or an object of a class of your
own, is thrown again unchanged, so code that catches it can tell it by
its class.

Either way, the run has ended. Every end is called, told `died`, and
then the error is thrown again. A pushed run returns nothing. An
iterator returns an empty list on every call after, without calling
its source or any flush again (see [iterator](#iterator)).

An end that dies is named the same way, as the end of `the source` or
of a stage, in "Pipeline end of stage #2 failed at ...". In a run
already dying, it's a warning instead, and the run's own error is
thrown (see [Flushes and ends](#flushes-and-ends)).

A mistake in making a pipeline, such as a stage that's neither a code
reference nor a pipeline, or in making a canned stage, such as
`take(-1)`, is reported at the line that made it, before any value goes
through.

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
- **Give up held values in a flush.** It's called even when there were
  no values, with no arguments and `$_` undefined.
- **Close what you open in an end,** which is told how the run ended,
  however it ended, rather than in a flush, which isn't called when
  the run stops before the stage, or dies.
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
  no values, to show what its flush gives. And run it through an
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
- **Find the stages with `is_stage`,** if the function takes a list
  of values of its own before them, so that callers can pass a
  pipeline as a stage, as they can to `new`. The values mustn't be
  code references or pipelines themselves, or the last of them would
  be taken for stages.
- **Test `is_stage` before `is_hashref`,** if the function takes a
  hash reference of options before its stages. A pipeline is a blessed
  hash, so `is_hashref` (or `reftype($x) eq 'HASH'`) is true of it
  too, and a pipeline would be taken for the options:
  `is_hashref($x) && !is_stage($x)`. Ref::Util's `is_plain_hashref`,
  false for any blessed hash, avoids it too.
- **Take a pipeline given last as the stages,** if the function's
  values can be code references, so that `is_stage` can't tell them
  from stages. A pipeline is never taken for a value by this rule, and
  the caller makes one with `pipeline`. Without one, there are no
  stages.

```perl
use Ekorn::Pipeline v0.1.3 qw(is_stage);

# The values given, up to the stages at the end, through those stages.
sub only (@args) {
    my @stages;
    unshift @stages, pop @args while @args && is_stage($args[-1]);
    return Ekorn::Pipeline->new(@stages)->(@args);
}

my $evens = Ekorn::Pipeline->new(sub { $_ % 2 ? () : $_ });
say join ' ', only(
    1 .. 10,
    $evens,
    take(3),
);
# 2 4 6
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

```perl
use Ekorn::Pipeline::Factories qw(pipeline);

# What each callback returns, through the stages given last, as a pipeline.
sub call_all (@callbacks) {
    my $stages = @callbacks && $callbacks[-1] isa 'Ekorn::Pipeline' ? pop @callbacks : pipeline();
    return $stages->(map { $_->() } @callbacks);
}

say join ' ', call_all(sub {1}, sub {2}, sub {3}, pipeline(
    sub { $_ * 10 },
    take(2),
));
# 10 20
```

## Delivering parts for Ekorn

For the author of a package that hands out values, such as
DBIx::Squirrel, or a module reading CSV or JSON. Use Ekorn as it is:
deliver sources, sinks and stages that keep its protocols, and let your
users run them in Ekorn's pipelines, with Ekorn's parts and their own.
Don't subclass Ekorn's classes, or wrap them. [Making each kind of
part](#making-each-kind-of-part) has what each piece is called with
and returns, with a worked example of each kind of part.

### The protocols

A part of yours says what it can be by its methods. Each is called at
the start of a run, and returns closures sharing that run's state:

| Method | Makes it | Returns |
|---|---|---|
| `EKORN_SOURCE` | a source, given to `iterator` | its step, called with nothing for the next value, or an empty list at the end; optionally its end, told how the run ended; and optionally a context, anything its stages may want to know about this run |
| `EKORN_STAGE` | a stage with state for the run | its step, called with each value, returning a list; optionally its flush, called when its input runs out; and optionally its end |
| `EKORN_SINK_ONE`, `EKORN_SINK_MANY` | a sink, giving one value or a list | its step, called with each value, its return ignored; its flush, giving the result; and optionally its end |

Each returns its parts as a list, in the order the table gives, or by
name, as a hash reference with the keys `step`, `flush`, `end` and
`context`, as a set-up does (see [Made for a run](#made-for-a-run)).

The methods are named for Ekorn, so an object of yours with a method
of its own such as `as_list` is never taken for a part. One object can
offer `EKORN_SOURCE` and one of the others, as a table can be read from
and written to; offering more than one of `EKORN_STAGE`,
`EKORN_SINK_ONE` and `EKORN_SINK_MANY` croaks where it's given as a
stage. A plain code reference is a source or a stage, wherever it's
given, with no end. None of these needs your package to load Ekorn.

```perl
package My::Rows;

sub EKORN_SOURCE ($self) {
    my $sth = $self->{sth};
    $sth->execute;    # this run's
    return {
        step    => sub ()     { $sth->fetchrow_arrayref // () },
        end     => sub ($how) { $sth->finish },
        context => {columns => $sth->{NAME}},    # what stages may ask
    };
}
```

### Stages that ask about their run

A stage that needs to know about the values' source asks
[`run_context`](#run_context) for the context its run's source gave.
Each run has its own, and an iterator used as a source passes on the
context of the run inside it. A pushed run has none.

```perl
sub pluck ($name) {
    return sub ($row) {
        my $columns = Ekorn::Pipeline::run_context()->{columns};
        my($at) = grep { $columns->[$_] eq $name } 0 .. $#$columns;
        return $row->[$at];
    };
}
```

### `|` for your sources

To let your users start a chain with your source, overload `|`, and
`@{}`, with Ekorn's own functions. Load Operators with an empty import
list, which defines them without putting the operators in force in
your own scope; without loading it, `|` dies with "Undefined
subroutine" until something else does:

```perl
use Ekorn::Pipeline::Operators ();
use overload
    '|'   => \&Ekorn::Pipeline::Operators::chain,
    '@{}' => \&Ekorn::Pipeline::Operators::drain;
```

### Functions that take stages

A function of yours that runs its own values through its caller's
stages finds them with `is_stage`, or takes a pipeline given last, and
runs them with `new`, as any user of Ekorn does (see [Writing
functions that take stages](#writing-functions-that-take-stages)):

```perl
sub each_row ($rows, @stages) {
    return Ekorn::Pipeline->new(@stages)->iterator($rows);
}
```

### Ekorn's functions, for your users

You can export Ekorn's functions to your users, such as `Stop` or
`take`, as they are, with Exporter, so they needn't `use` two
packages. They're the same functions, so your users can mix yours and
Ekorn's freely.

### Your errors

Put `@Ekorn::Pipeline::Errors::INTERNAL` in your modules' `@CARP_NOT`,
so a mistake is reported at your users' lines.

## Making each kind of part

This section is for developers making parts for others: what each
part of a run is called with, what it must return, and a worked
example of each kind, made with a word and as a class of your own.
Each example runs as it stands, given
`use Ekorn::Pipeline; use Ekorn::Pipeline::Tooling qw(:all);`, and its
comments say what it prints.

### What each piece is called with, and returns

A part made for a run, whether by a word or by a role method, is a
set of pieces. The set-up makes them at the start of each run, and the
run calls them:

| Piece | When it's called | What it's given | What it returns | Can it stop the run? |
|---|---|---|---|---|
| **set-up** (a word's block, or a role method) | once, at the start of each run, before any value | nothing; a role method, its object | the part's pieces, as a list or by name | no: it croaks "Expected no stop in a set-up, as the run has nothing yet to stop" |
| a source's **step** | each time the run wants more values | nothing | the next value, or several; an empty list when there are no more | yes: the values its stop carries are its last, and its end is told `done` |
| a stage's **step** | once for each value | the value, in `$_` and as its only argument | a list: none drops the value, one passes it on, several go on one at a time | yes |
| a sink's **step** | once for each value | the value, in `$_` and as its only argument | nothing that's used: what it returns is ignored | yes: the sink still gives its result, and its end is told `done` |
| a gather's **flush** | once, when its input runs out: not if a stop at or after its stage cut its input short, or the run died | nothing, with `$_` undefined | values to go on through the stages after it, as a step's do | yes |
| a sink's **flush** | the same | nothing, with `$_` undefined | the result: one value for a sink of one, a list for a sink of many | no need: its input has run out |
| an **end** | once, when the run has ended, however it ended | how it ended, from where the part stands: `done`, `stopped` or `died` | nothing that's used | no: it croaks "Expected no stop in an end, as the run has ended" |
| a source's **context** | read by stages, while the run lasts | | any value: stages ask for it with `Ekorn::Pipeline::run_context()` | |

What each part's set-up returns, as a list in this order, or as a
hash reference with these keys:

| Part | Made with | Its pieces, in order | Required |
|---|---|---|---|
| a source | `source {...}`, or `EKORN_SOURCE` | `step`, `end`, `context` | the step |
| a stage | `gather {...}`, or `EKORN_STAGE` | `step`, `flush`, `end` | the step |
| a sink | `sink_one {...}` or `sink_many {...}`, or `EKORN_SINK_ONE` or `EKORN_SINK_MANY` | `step`, `flush`, `end` | the step and the flush |

Six rules hold for every part:

- **What a run needs goes in the set-up,** declared with `my`, and
  the pieces are closures sharing it. Never keep a run's state in the
  object, or in the closure around the set-up: a part may be in two
  runs at once, as when two iterators of one pipeline are read in turn.
- **By name, give only the pieces you have.** As a list, leave out
  pieces from the end, and give `undef` for one you leave out before
  one you give: `return ($step, undef, $end)`.
- **Ends run in order,** the source's first, then each stage's, first
  stage first, and each is told how the run ended from where it
  stands: the source and the stages up to the one that stopped the
  run, itself included, are told `stopped`, if they still had values
  to come, and the stages after it, `done`.
- **An end can't undo the run, but it can choose what to keep.** A
  sink that writes somewhere commits in its end only when told `done`,
  and throws away what it wrote otherwise.
- **A piece that dies ends the run.** Every end is still called, told
  `died`, and then the error is thrown, naming the part, as in
  "Pipeline stage #2 failed at ...". An end that dies in a run that
  hadn't died ends it with its error; in a run already dying, it's a
  warning.
- **Only a `gather` block may return a pipeline,** in place of its
  step, so that its stages are made for the run. A role method returns
  code references.

### A stage, with the word `gather`

A stage that numbers each value, says how many there were once the
values run out, and notes in a log of your choosing how each run
ended:

```perl
sub numbered ($log) {
    return gather {
        my $n = 0;    # this run's
        return {
            step  => sub ($value) { ++$n . ". $value" },
            flush => sub ()       { "($n in all)" },
            end   => sub ($how)   { push @$log, "numbered: $how" },
        };
    };
}

my @log;
say for Ekorn::Pipeline->new(numbered(\@log))->(qw(a b));
# 1. a
# 2. b
# (2 in all)

say for Ekorn::Pipeline->new(
    numbered(\@log),
    take(1),
)->(qw(a b));
# 1. a

say for Ekorn::Pipeline->new(
    take(1),
    numbered(\@log),
)->(qw(a b));
# 1. a
# (1 in all)

say "@log";    # numbered: done numbered: stopped numbered: done
```

In the second run, `take(1)`, after the numbering stage, stopped the
run while `b` was still to come, so the numbering stage's input was
cut short: its flush wasn't called, and its end was told `stopped`. In
the third, `take(1)` comes first, so the numbering stage got all the
values it was going to get: its flush was called, and its end was told
`done`.

### The same stage, as a class

A class of your own can be the same stage, with no word and nothing of
Ekorn's loaded, by offering `EKORN_STAGE`. It's called at the start of
each run, with the object, and returns the pieces, as the set-up did:

```perl
package My::Numbered {
    sub new ($class, %options) { bless {from => $options{from} // 1}, $class }

    sub EKORN_STAGE ($self) {
        my $n = $self->{from};    # this run's, starting where the object says
        return {step => sub ($value) { $n++ . ". $value" }};
    }
}

my $numbered = My::Numbered->new(from => 10);
my $p        = Ekorn::Pipeline->new($numbered);
say join ', ', $p->(qw(a b));    # 10. a, 11. b
say join ', ', $p->(qw(c));      # 10. c
```

The object keeps its settings, such as where to count from, and each
run keeps its own count, as `$n` is declared in the method.

### A source, with the word `source`

A source of the lines of a text, which closes what it opened however
the run ends, and tells its stages the text's name, as the run's
context:

```perl
sub lines_in ($name, $text) {
    return source {
        open my $fh, '<', \$text or die "Can't read $name: $!\n";    # this run's
        return {
            step    => sub () { my $line = readline $fh; defined $line ? $line =~ s( \n \z )()xr : () },
            end     => sub ($how) { close $fh },
            context => {name => $name},
        };
    };
}

my $where = sub ($line) { Ekorn::Pipeline::run_context()->{name} . ": $line" };
my $next  = Ekorn::Pipeline->new($where)->iterator(lines_in('verse', "one\ntwo\n"));
say for $next->all;
# verse: one
# verse: two
say $next->ended;    # done
```

Its step is called with nothing, and returns the next line, or an
empty list once there are none. Returning an empty list is the only
way a source says it has finished: `undef`, 0 and the empty string are
values.

### A sink of one and a sink of many, with the words

`sink_one` makes a sink giving one value, and `sink_many` one giving a
list. The step is given each value, and what it returns is ignored;
the flush gives the result:

```perl
my $longest = sink_one {
    my $longest = '';
    return {
        step  => sub ($word) { $longest = $word if length $word > length $longest },
        flush => sub ()      { $longest },
    };
};

my $distinct = sink_many {
    my(%seen, @order);
    return {
        step  => sub ($word) { push @order, $word unless $seen{$word}++ },
        flush => sub ()      { @order },
    };
};

my @words = qw(the cat sat on the mat);
say scalar Ekorn::Pipeline->new($longest)->(@words);     # the
say join ' ', Ekorn::Pipeline->new($distinct)->(@words);    # the cat sat on mat
my $list = Ekorn::Pipeline->new($distinct)->(@words);
say scalar @$list;    # 5
```

Asked for one value, a pipeline ending in a sink of many gives its
list as an array reference, so it can never be mistaken for a count.
`$longest` gives the first of the longest, as it keeps a word only if
it's longer than the one it has.

### A class that's both a source and a sink

One object can offer `EKORN_SOURCE` and a sink's method, as a shelf of
books can be read from and added to. This one adds what it's given
only if the whole run went through, so a run that dies, or is cut
short, leaves the shelf as it was:

```perl
package My::Shelf {
    sub new ($class, @books) { bless {books => [@books]}, $class }

    sub books ($self) { @{ $self->{books} } }

    # Read: each book on the shelf, in order.
    sub EKORN_SOURCE ($self) {
        my $i = 0;    # this run's place
        return {step => sub () { $i < @{ $self->{books} } ? $self->{books}[$i++] : () }};
    }

    # Write: the books given, put on the shelf only once the run is done.
    sub EKORN_SINK_ONE ($self) {
        my @pending;
        return {
            step  => sub ($book) { push @pending, $book },
            flush => sub ()      { scalar @pending },
            end   => sub ($how)  { push @{ $self->{books} }, @pending if $how eq 'done' },
        };
    }
}

my $shelf = My::Shelf->new('Emma');
say scalar Ekorn::Pipeline->new($shelf)->('Dune', 'Ulysses');    # 2
say join ', ', $shelf->books;    # Emma, Dune, Ulysses

eval {
    Ekorn::Pipeline->new(
        sub { die "Torn\n" if $_ eq 'Torn'; $_ },
        $shelf,
    )->('Ivanhoe', 'Torn');
};
say join ', ', $shelf->books;    # Emma, Dune, Ulysses

say join ', ', Ekorn::Pipeline->new(sub { uc })->iterator($shelf)->all;
# EMMA, DUNE, ULYSSES
```

The second run died at its second book, so the sink's end was told
`died`, and `Ivanhoe` was never put on the shelf.

### Your source, chained with `|`

To let your users start a chain with your source, overload `|` and
`@{}` with Operators' `chain` and `drain`. Load Operators with an empty
import list, so that it doesn't put the operators in force in your
package:

```perl
package My::Chained::Shelf {
    our @ISA = ('My::Shelf');
    use Ekorn::Pipeline::Operators ();
    use overload
        '|'   => \&Ekorn::Pipeline::Operators::chain,
        '@{}' => \&Ekorn::Pipeline::Operators::drain;
}

use Ekorn::Pipeline::Operators;

my $shelf  = My::Chained::Shelf->new('Emma', 'Dune', 'Ulysses');
my $titles = $shelf
    | take_if { length > 4 }
    | stage { uc }
    | keep_all;
say "@$titles";    # ULYSSES
say scalar @{$shelf};    # 3
```

This uses `My::Shelf`, from the example before. Your users need `use
Ekorn::Pipeline::Operators` in their own scope, as for any chain.

## Diagnostics

Every message Ekorn::Pipeline writes, by module. Each is reported at
the line of the caller's code that caused it.

### Ekorn::Pipeline

- **Expected stage #%d to be a code reference or a pipeline:** a stage
  given to `new` wasn't a code reference or a pipeline. It's also
  raised for a pipeline whose overridden `stages` method returned
  something that isn't a code reference.
- **Expected stage #%d to be a code reference, a pipeline or the name
  of one:** a stage given to `pipeline_in`, and so to the word
  `pipeline`, or to `named` after the name, was none of them. For
  `named`, stages are counted from the first after the name.
- **No pipeline named %s:** a name given to `pipeline_in`, and so to
  the word `pipeline`, or to `named`, isn't defined in that package. The
  name is given qualified, so it says which package it was looked up
  in. It may be defined in another package, which a qualified name
  reaches (see [Named pipelines](#named-pipelines)).
- **A pipeline named %s is already defined:** `named` was given a name
  already defined for another pipeline.
- **Expected a name, made of words joined by ::** (from `named`): it
  was given something other than a name.
- **Expected only a name, naming a pipeline you have:** `named`, on a
  pipeline, was given stages after the name.
- **Expected stage #%d to be a stage, not a source:** a source,
  offering `EKORN_SOURCE` and none of a stage's role methods, was given
  to `new` as a stage. Give it to `iterator` instead.
- **Expected stage #%d to offer one of EKORN_STAGE, EKORN_SINK_ONE and
  EKORN_SINK_MANY, not %s:** a stage offered more than one of the role
  methods, so it couldn't say which it is.
- **Expected a code reference:** the source given to `iterator` wasn't
  a code reference, or anything offering `EKORN_SOURCE`.
- **Expected the source to return a code reference, and optionally an
  end and a context:** a source's `EKORN_SOURCE` returned something
  else. Reported when the run starts.
- **Expected stage #%s to return a code reference, and optionally a
  flush and an end:** a stage's `EKORN_STAGE` returned something else.
  Reported when the run starts.
- **Expected sink #%s to return a code reference, a flush, and
  optionally an end:** a sink's `EKORN_SINK_ONE` or `EKORN_SINK_MANY`
  returned something else. Reported when the run starts.
- **Expected no stop in a set-up, as the run has nothing yet to
  stop:** a set-up, or a role method, threw a stop. The ends of the
  parts already made are told `died`.
- **Expected stage #%s, made with gather, to return a code reference
  or a pipeline, and optionally a flush and an end:** the block given
  to `gather` for that stage returned something else. Reported when the
  run starts.
- **Pipeline stage #%s failed at %s line %d:** a stage, or its flush,
  died with a message, which follows, indented. An exception object is
  thrown again unchanged.
- **Pipeline end of %s failed at %s line %d:** an end died, in a run
  that hadn't died. The message follows, indented, and the end is
  named: `the source`, or a stage, as `stage #2`. An exception object
  is thrown again unchanged.
- **Expected no stop in an end, as the run has ended:** an end threw
  a stop, which is an error like any other there, reported as the
  message above.
- **The end of %s died while the run was already dying: %s:** a
  warning: an end died in a run that had died. The run's own error is
  thrown, once every end has run.

In these, a stage is named by its position: `#2` for the second
stage, or `#2.3` for the third stage of a pipeline given as the second
stage. Within a named pipeline, the innermost one's name and the
stage's position there follow, as `#1.2 (main::clean#2)` (see
[When a stage dies](#when-a-stage-dies)).

### Ekorn::Pipeline::Factories

- **Expected a code reference:** a word was given something other
  than a block or code reference.
- **Expected yield to be called inside a generator:** `yield` was
  called with no generator's block running.

### Ekorn::Pipeline::Operators

- **Expected use Ekorn::Pipeline::Operators in scope, for %s:** `|` or
  `@{}` was used on Ekorn's types where Operators isn't in force.
- **Expected a source, or a stage made with a word, on the left of
  |:** a chain started with something else, such as a pipeline made
  with `new`, or an object of another class.
- **Expected a stage or a sink on the right of |:** what followed `|`
  can't go where a stage goes.

### Ekorn::Pipeline::Sinks

- **Expected a count of 0 or more:** `keep` was given something other
  than a whole number.
- **Expected only one item, but there were more:** a warning:
  `keep_single` was given a second item, and stopped the run, giving
  the first.
- **Expected an open filehandle:** `to_fh` was given something other
  than an open filehandle.
- **Can't write %s: %s:** `to_fh` or `to_file` couldn't write, or
  `to_file` couldn't open or close its file; the second part says why.
  The first is the file's path, or "the filehandle".

### Ekorn::Pipeline::JSON

- **Expected options as name => value pairs:** a function was given
  an odd number of arguments.
- **Expected the options file, fh and json, not %s:** an option it
  doesn't know, named after "not".
- **Expected a file or a filehandle, not both:** it was given both
  `file` and `fh`.
- **Expected an open filehandle:** `fh` was something else.
- **Expected json to be a hash reference of options, or an encoder
  object:** `json` was something else.
- **Expected json options the encoder knows: %s:** `json`'s options
  included one the encoder doesn't have; the rest is the encoder's
  message.
- **Expected an encoder that doesn't indent, to write JSON Lines:**
  `to_jsonl` was given an encoder that indents.
- **Can't decode JSON from %s: %s:** what was read wasn't JSON; the
  first part is the file's path, "the filehandle", or "a value", for a
  stage, and the second the decoder's reason, "it ends inside a
  document" if it ended part way through one, or "it holds more than
  one document; read JSON Lines with from_jsonl" from `from_json`.
- **Can't encode a value as JSON: %s:** a value couldn't be encoded,
  such as an object, by default.
- **Can't read %s: %s** and **Can't write %s: %s:** a file couldn't be
  opened, read, written or closed, or a filehandle read or written.

### Ekorn::Pipeline::Sources

- **Expected an open filehandle:** `from_fh` was given something other
  than an open filehandle.
- **Can't read %s: %s:** `from_file` couldn't open its file, as a run
  started; the second part says why.
- **Expected a number to start from, and one to step by:** `counter`
  was given something other than numbers.

### Ekorn::Pipeline::Source

- **Expected a code reference:** `new` was given something other than
  a code reference.
- **Expected a source to be read through iterator:** a source was
  called as a code reference.

### Ekorn::Pipeline::Sink

- **Expected a code reference:** `new_sink_one` or `new_sink_many` was
  given something other than a code reference.

### Ekorn::Pipeline::Stage

- **Expected a code reference:** `new` was given something other than
  a code reference, or one of Ekorn's own types.

### Ekorn::Pipeline::Iterator

- **Expected only one item, but there were more:** a warning: `single`
  found more than one value to come.
- **Expected a source with values still to give: an iterator is one
  run, and this one is spent:** an iterator was given as a source after
  it had handed out everything it will, been finished, or died.

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
- **Expected a code reference:** `take_if`, `drop_if`, `take_while`,
  `drop_while`, `collect` or `peek` was given something other than a
  block or code reference.
- **Expected only one item, but there were more:** a warning, not an
  error: `take_single` was given a second value, and stopped the
  pipeline, passing on only the first.
- **Expected a reference to a scalar:** `count_into` was given
  something other than a reference to a scalar.
- **Expected an open filehandle:** `dump_to` was given something other
  than an open filehandle.

## Exports

| Module | By default | On request | Tags |
|---|---|---|---|
| `Ekorn::Pipeline` | nothing | `is_stage`, `is_sink` | |
| `Ekorn::Pipeline::Tooling` | nothing | every name below but `is_stage`, `is_sink`, `chain`, `drain` and `croakf` | `:core`, `:flow`, `:batch`, `:taps`, `:stages`, `:sources`, `:sinks`, `:json`, `:words`, `:all` |
| `Ekorn::Pipeline::Factories` | nothing | `pipeline`, `stage`, `gather`, `source`, `generator`, `yield`, `sink_one`, `sink_many` | `:all` |
| `Ekorn::Pipeline::Sources` | nothing | `from_array`, `from_fh`, `from_file`, `counter` | `:all` |
| `Ekorn::Pipeline::Operators` | nothing: loading it puts the operators in force | `chain` and `drain`, by their full names, for your own overloads | |
| `Ekorn::Pipeline::Sinks` | nothing | `keep_all`, `keep`, `keep_first`, `keep_single`, `keep_last`, `count_items`, `to_fh`, `to_file` | `:all` |
| `Ekorn::Pipeline::JSON` | nothing | `from_json`, `from_jsonl`, `to_json`, `to_jsonl` | `:all` |
| `Ekorn::Pipeline::Stop` | `Stop` | | |
| `Ekorn::Pipeline::Gather` | `gather` | | |
| `Ekorn::Pipeline::Pipes` | nothing: a parent class | | |
| `Ekorn::Pipeline::Source`, `::Sink`, `::Stage`, `::Iterator`, `::Element` | nothing: classes | | |
| `Ekorn::Pipeline::Errors` | nothing | `croakf` | |
| `Ekorn::Pipeline::Stages::Flow` | `take`, `drop` | `take_first`, `take_last`, `take_single`, `take_if`, `drop_if`, `take_while`, `drop_while` | `:all` |
| `Ekorn::Pipeline::Stages::Batch` | `batch`, `collect` | | `:all` |
| `Ekorn::Pipeline::Stages::Taps` | `peek`, `count_into` | `dump_to` | `:all` |

To import nothing from a module that exports by default, give it an
empty list: `use Ekorn::Pipeline::Stop ();`.

## The modules

| Module | What it is |
|---|---|
| `Ekorn::Pipeline` | Runs values through a list of stages: `new`, `pipeline_in`, `named`, `iterator`, `stages`, `is_stage`, `is_sink`, `ending` and `run_context`. |
| `Ekorn::Pipeline::Tooling` | Exports what callers use to do work, from one place, by tags: see [Importing](#importing-ekornpipelinetooling). |
| `Ekorn::Pipeline::Operators` | `\|`, `\|=` and `@{}` for Ekorn's types, in force lexically: `chain` and `drain`. |
| `Ekorn::Pipeline::Sinks` | Ready-made sinks: `keep_all`, `keep`, `keep_first`, `keep_single`, `keep_last`, `count_items`, `to_fh`, `to_file`. |
| `Ekorn::Pipeline::Sources` | Ready-made sources: `from_array`, `from_fh`, `from_file`, `counter`. |
| `Ekorn::Pipeline::JSON` | Reads and writes JSON and JSON Lines, as sources, stages or sinks: `from_json`, `from_jsonl`, `to_json`, `to_jsonl`. |
| `Ekorn::Pipeline::Factories` | The words that make Ekorn's types: `pipeline`, `stage`, `gather`, `source`, `generator` and `yield`, `sink_one`, `sink_many`. |
| `Ekorn::Pipeline::Stop` | Ends a pipeline early: `Stop` and `throw`. |
| `Ekorn::Pipeline::Gather` | Makes a stage afresh for each run, with a flush called when its values run out, and an end: `gather`. |
| `Ekorn::Pipeline::Source` | A source made afresh for each run, told how it ended: `new`. |
| `Ekorn::Pipeline::Sink` | A sink made afresh for each run, giving one value or a list: `new_sink_one` and `new_sink_many`. |
| `Ekorn::Pipeline::Iterator` | One run, handing out its values: `all`, `first`, `single`, `finish` and `ended`. |
| `Ekorn::Pipeline::Stage` | A code reference kept as a stage: `new` and `code`. |
| `Ekorn::Pipeline::Element` | What each of Ekorn's types is: `call`. |
| `Ekorn::Pipeline::Pipes` | A parent class giving `pipe` and `tap` methods. |
| `Ekorn::Pipeline::Errors` | Reports errors at the caller's line: `croakf` and `@INTERNAL`. |
| `Ekorn::Pipeline::Stages::Flow` | Canned stages taking or dropping values: `take`, `drop`, `take_first`, `take_last`, `take_single`, `take_if`, `drop_if`, `take_while`, `drop_while`. |
| `Ekorn::Pipeline::Stages::Batch` | Canned stages gathering values: `batch`, `collect`. |
| `Ekorn::Pipeline::Stages::Taps` | Canned stages run for their side effects: `peek`, `count_into`, `dump_to`. |
