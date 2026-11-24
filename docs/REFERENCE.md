# Ekorn::Pipeline reference

<!-- stopwords: 21st bitwise dereferences fh setlist -->

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
- [Named at compile time: Ekorn::Pipeline::Sugar](#named-at-compile-time-ekornpipelinesugar)
- [How values go through stages](#how-values-go-through-stages)
- [Runs and how they end](#runs-and-how-they-end)
- [Stopping a pipeline: Ekorn::Pipeline::Stop](#stopping-a-pipeline-ekornpipelinestop)
- [Gathering: Ekorn::Pipeline::Gather](#gathering-ekornpipelinegather)
- [pipe and tap: Ekorn::Pipeline::Pipes](#pipe-and-tap-ekornpipelinepipes)
- [Canned stages](#canned-stages)
- [Sources: Ekorn::Pipeline::Sources](#sources-ekornpipelinesources)
- [Sinks: Ekorn::Pipeline::Sinks](#sinks-ekornpipelinesinks)
- [JSON: Ekorn::Pipeline::JSON](#json-ekornpipelinejson)
- [CSV: Ekorn::Pipeline::CSV](#csv-ekornpipelinecsv)
- [Operators: Ekorn::Pipeline::Operators](#operators-ekornpipelineoperators)
- [Errors: Ekorn::Pipeline::Errors](#errors-ekornpipelineerrors)
- [Which result: Ekorn::Pipeline::Context](#which-result-ekornpipelinecontext)
- [Writing stages](#writing-stages)
- [Writing functions that take stages](#writing-functions-that-take-stages)
- [Delivering parts for Ekorn](#delivering-parts-for-ekorn)
- [Making each kind of part](#making-each-kind-of-part)
- [Diagnostics](#diagnostics)
- [Index](#index)

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

# Fed: given values as they arrive, a push at a time, it returns what
# comes out of each; close gives what's held back, and ends the run.
my $feed = Ekorn::Pipeline->new(batch(2))->feed;
my @batches = map { $feed->push($_) } 1 .. 3;
push @batches, $feed->close;
say join ' ', map { "[@$_]" } @batches;    # [1 2] [3]

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
| `:flow` | `take`, `take_first`, `take_last`, `take_single`, `take_if`, `take_while`, `drop`, `drop_if`, `drop_while` | [Stages::Flow](#taking-and-dropping-ekornpipelinestagesflow) |
| `:batch` | `batch`, `collect` | [Stages::Batch](#batching-and-collecting-ekornpipelinestagesbatch) |
| `:taps` | `peek`, `count_into`, `dump_to`, `tee` | [Stages::Taps](#taps-ekornpipelinestagestaps) |
| `:stages` | `:flow`, `:batch` and `:taps` | |
| `:sources` | `from_array`, `from_fh`, `from_file`, `counter` | [Sources](#sources-ekornpipelinesources) |
| `:sinks` | `count_items`, `keep`, `keep_all`, `keep_first`, `keep_last`, `keep_single`, `to_fh`, `to_file` | [Sinks](#sinks-ekornpipelinesinks) |
| `:json` | `from_json`, `from_jsonl`, `to_json`, `to_jsonl` | [JSON](#json-ekornpipelinejson) |
| `:csv` | `from_csv`, `to_csv` | [CSV](#csv-ekornpipelinecsv) |
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
- **Run:** one call of a pipeline with values, or one iterator or feed
  made from it. Gathers, sources and sinks are made afresh for each
  run.
- **Feed:** a run you give values to as they arrive, with `push`, and
  end with `close` (see [Feeds](#feeds-ekornpipelinefeed)).
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

### Making and calling a pipeline

A pipeline is made once, from its stages, and called as often as it's
needed, each call a run of its own. Any code reference will do for a
stage: an anonymous `sub`, a reference to a named one such as
`\&trim`, or a stage made by a function such as `take(10)`. So will a
stage made with `gather`, and a sink, usually last (see
[Sinks](#sinks-ekornpipelinesink)).

The examples from here on use a small catalogue of tracks, each a hash
with a `title`, an `artist` and how many `plays` it has had:

```perl
my @tracks = (
    {title => 'Dancing Queen',           artist => 'ABBA',  plays => 9100},
    {title => 'Knowing Me, Knowing You', artist => 'ABBA',  plays => 4200},
    {title => 'Girls & Boys',            artist => 'Blur',  plays => 6100},
    {title => 'Parklife',                artist => 'Blur',  plays => 5800},
    {title => 'Sunshine of Your Love',   artist => 'Cream', plays => 7700},
    {title => 'Country House',           artist => 'Blur',  plays => 3900},
);
```

```perl
my $hits = Ekorn::Pipeline->new(
    sub { $_->{plays} > 6000 ? $_ : () },
    sub { $_->{title} },
);
my @hits  = $hits->(@tracks);
my $count = $hits->(@tracks);
say "$count hits: ", join ', ', @hits;    # 3 hits: Dancing Queen, Girls & Boys, Sunshine of Your Love
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

You can call a pipeline even from inside one of its own stages. With
no stages, it returns its values unchanged, so a function that takes
stages from its caller needs nothing special for a caller who gives
none.

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

### iterator

Pull values through a pipeline, rather than push them, when they're
made one at a time, from a file, a socket or a database, or without
end: the source is asked for more only as results are wanted, so a
stage that stops, such as `take`, saves the work of making the rest.

```perl
my $n    = 0;
my $next = Ekorn::Pipeline->new(
    sub { $_ * $_ },
    take_if { $_ % 2 },
    take(3),
)->iterator(sub { ++$n });
while (my($square) = $next->()) { say $square }    # 1, 9, 25
say "$n numbers read";    # 5 numbers read
```

The source here counts without end, and is read five times: once for
each number up to the fifth, whose square is the third odd one, where
`take(3)` stops the run.

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

### feed

Use a feed where the values don't come from you, all at once, and
can't be pulled, but arrive a value at a time: from a library calling
back for each row, record or file it finds, from an event loop, or
from a stage that runs its values through another pipeline, as a
`tee` does. Between pushes, the run's `gather` stages keep their
state, so `take(5)` takes five values from all that are pushed, and
`batch(3)` fills its batches across pushes:

```perl
my $feed = Ekorn::Pipeline->new(sub { $_->{title} }, batch(2))->feed;
my @pages;
for my $track (@tracks) {    # as if each arrived on its own
    push @pages, $feed->push($track);
}
push @pages, $feed->close;
say for map { join ' / ', @$_ } @pages;
# Dancing Queen / Knowing Me, Knowing You
# Girls & Boys / Parklife
# Sunshine of Your Love / Country House
```

Fed the same values, a feed gives what a call gives, in the same
order, a push at a time. The run is made when `feed` is called, so a
`gather`'s block is called then, and an error in it is thrown then.
[Feeds](#feeds-ekornpipelinefeed) says more of its methods, and how
its run ends.

### stages

A pipeline's stages are for splicing into another pipeline, or giving
to a function that takes stages, where a pipeline itself won't do.
The list can go anywhere stages go. Each is one of Ekorn's types, an object called as a code
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

### pipeline_in

Call `pipeline_in` from code the user calls directly, passing the
user's package, as the word [pipeline](#named-pipelines) does with
`scalar caller`: for a word of your own, say, making a pipeline of
your subclass from stages and names the user writes.

```perl
package My::Playlist {
    use parent -norequire, 'Ekorn::Pipeline';

    sub playlist (@stages) { My::Playlist->pipeline_in(scalar caller, @stages) }
}

Ekorn::Pipeline->named(loud => sub { uc $_->{title} });
my $set = My::Playlist::playlist('loud', take(2));
say ref $set, ': ', join ', ', $set->(@tracks);    # My::Playlist: DANCING QUEEN, KNOWING ME, KNOWING YOU
```

Code that passes stages through, such as a function taking stages
from its caller, gives them to `new`, which reads no names: the user
has already turned any names into pipelines with `pipeline`, where
they wrote them. If `new` read names, it would look them up in the
package of whatever called it, which, for a function passing its
caller's stages on, isn't the caller's.

### Named pipelines

Name a pipeline that's used in several places, or that another module
should be able to use, and give its name wherever `pipeline` and
`named` take a stage, as a stage in its own right. A named pipeline is
kept for the life of the program, in a package, which says whose name
it is:

```perl
use Ekorn::Pipeline::Factories qw(pipeline);

Ekorn::Pipeline->named(hits   => sub { $_->{plays} > 6000 ? $_ : () });
Ekorn::Pipeline->named(titles => sub { $_->{title} });
Ekorn::Pipeline->named(hit_titles =>
    'hits',
    'titles',
);

say join ', ', pipeline('hit_titles', take(2))->(@tracks);    # Dancing Queen, Girls & Boys
say pipeline('hit_titles')->name;    # main::hit_titles
```

A pipeline already made is named in place, and returned, so it can be
named as it's made: `my $clean = Ekorn::Pipeline->new(...)->named('clean')`.
Its first name is the one errors in its stages give (see [When a stage
dies](#when-a-stage-dies)).

These rules say which pipeline a name means:

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

### ending

`ending` is for a stage that treats what a flush gives apart from the
values that went into it, as a total or a last batch isn't one of
them, and for code that tells its stages more about each value, such
as where it came from: a value from a flush has no such origin.
DBIx::Squirrel, for instance, tells its stages which row a value was
made from, and has no row to give while `ending` is true. Here the
last stage sets out the titles and their total differently:

```perl
my @lines = Ekorn::Pipeline->new(
    gather {
        my $plays = 0;    # this run's
        return (
            sub ($track) { $plays += $track->{plays}; $track->{title} },
            sub ()       { $plays },
        );
    },
    sub { Ekorn::Pipeline::ending() ? "Total plays: $_" : "  $_" },
)->(@tracks[0 .. 2]);
say for @lines;
#   Dancing Queen
#   Knowing Me, Knowing You
#   Girls & Boys
# Total plays: 19400
```

A pipeline run inside a stage has its own `ending`. In a pipeline
called from a stage while `ending` is true, `ending` is false until
one of the inner pipeline's own flushes is called.

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
[gather](#gather)). `pipeline` is `new` that reads the names of
pipelines, and is described with them (see [Named
pipelines](#named-pipelines)).

### stage

A plain `sub` is a stage already, and needs no word. Use `stage` where
a stage must be one of Ekorn's types as it's written: at the start of
a chain, where `sub {...} | sub {...}` would be Perl's bitwise OR of
two addresses (see [Operators](#operators-ekornpipelineoperators)):

```perl
use Ekorn::Pipeline::Operators;

my $shout = stage { uc $_->{title} } | stage { "$_!" };
say join ' ', $shout->(@tracks[0, 2]);    # DANCING QUEEN! GIRLS & BOYS!
```

To give it a signature, give it a sub: `stage sub ($track) {...}`. A
Stage keeps what it's given, so `stage(\&trim)` never changes `trim`
itself.

### source

A source with something to set up for each run, such as a count to
start from the beginning, or a file to open and close, is made with
`source`: its set-up runs as each run starts. A source with nothing to
set up or end needs no word, as any code reference is a source.

```perl
sub up_to ($last) {
    return source {
        my $n = 0;    # this run's
        return sub () { $n < $last ? ++$n : () };
    };
}

my $discs = Ekorn::Pipeline->new(sub { "Disc $_" });
say join ', ', $discs->iterator(up_to(3))->all;    # Disc 1, Disc 2, Disc 3
say join ', ', $discs->iterator(up_to(2))->all;    # Disc 1, Disc 2
```

Each run counts from 1 again, as the set-up runs at its start. The
source in [Made for a run](#made-for-a-run) has an end, closing its
file, and the one in [A source, with the word
`source`](#a-source-with-the-word-source) gives its stages a context
too. With a context but no end, give `undef` for the end.

### generator and yield

Where values are easiest to make in loops, as the pairs of nested
loops are, write a generator, and `yield` each value where the loop
makes it:

```perl
my @artists  = qw(ABBA Blur Cream);
my $pairings = generator {
    for my $i (0 .. $#artists) {
        yield "$artists[$i] & $_" for @artists[$i + 1 .. $#artists];
    }
};
say join ', ', Ekorn::Pipeline->new->iterator($pairings)->all;    # ABBA & Blur, ABBA & Cream, Blur & Cream
```

Perl can't pause a sub at `yield`, as a Python generator does, so each
run calls the block once, to its end, and gives every value it yielded
in one step: the block mustn't loop without end, and runs to its end
even when a stage after it takes only some. For a producer without
end, write a `source {...}` whose step gives a value each call. A
generator read inside another's block keeps its own `yield`s.

An empty block, `generator {}`, reads as an empty hash: write
`generator { return }`.

### sink_one and sink_many

Write a sink with these words when a run's result is something no
[ready-made sink](#sinks-ekornpipelinesinks) gives, such as the most
played track, or the artists, each once. Choose the word by the
result: `sink_one` for one value, and `sink_many` for a list, which a
pipeline asked for one value gives as an array reference, so it's
never taken for a count.

```perl
my $most_played = sink_one {
    my $top;    # this run's
    return (
        sub ($track) { $top = $track if !$top || $track->{plays} > $top->{plays} },
        sub ()       { $top && $top->{title} },
    );
};
my $artists = sink_many {
    my %seen;    # this run's
    return (
        sub ($track) { $seen{ $track->{artist} }++ },
        sub ()       { sort keys %seen },
    );
};

say Ekorn::Pipeline->new($most_played)->(@tracks);    # Dancing Queen
say join ', ', Ekorn::Pipeline->new($artists)->(@tracks);    # ABBA, Blur, Cream
```

## Named at compile time: Ekorn::Pipeline::Sugar

```perl
use Ekorn::Pipeline::Sugar pipeline => {
    titles => [sub { $_->{title} }],
    top    => ['titles', take(3)],
};

my @top  = top(@tracks);                         # the first three titles
my @loud = top(@tracks, pipeline(sub { uc }));    # and more stages
my $next = pipeline('top')->iterator($source);    # pulled
```

`use Ekorn::Pipeline::Sugar` takes `pipeline` and the definitions after
it, each a name and an array of stages: a hash, `{...}`, or an array of
pairs, `[...]`, to read in order. Each pipeline is named in the package
that uses the module, as `named` names one, so `pipeline('name')` finds
it, and the package gets a function of each name. New in v0.3.0.

- **The function** runs the values it's given through the pipeline, and
  returns what comes out, in the caller's context, as calling the
  pipeline does: a list in list context; in scalar context, a sink's
  result, or how many came out. Given a pipeline last, it runs them
  through that too, after its own. Only a pipeline last is taken for
  stages; any other value, a code reference included, is a value. The
  two are joined once for the pipeline given, and joined again only
  when another is given, so a pipeline kept in a variable and given
  again, as in a loop, costs less than one made in each call. The
  function holds the last one given until it's given another.
- **A string where a stage goes names a pipeline,** as in `pipeline`
  and `named`: one from the same `use`, or one defined before it. A
  definition can name any other in the same `use`, in either order:
  each is defined once those it names are.
- **A name** is a word, of letters, digits and underscores, not starting
  with a digit, as a function's must be.
- **Mistakes croak as the `use` compiles,** at its line: a name that
  can't be a function's, one given twice, one the package has a
  function of already, its own or one it inherits, one a pipeline has
  already, a definition that isn't an array, pipelines that name each
  other in a circle, and a name defined nowhere. A pipeline's stages
  are checked as `pipeline` checks them.

A sub covers what it doesn't: a pipeline that makes its own values
is `sub recent (@stages) { pipeline('top', @stages)->(load_recent()) }`.

### Sugar of your own

A module whose own `use` line takes pipelines, and hands them on to
the package using it, does so with `import_into`, so they're named in,
and their functions given to, that package, not the module. This one
puts a stage of its own before each pipeline it's given, so its users
write only what follows the titles:

```perl
package My::Titles {
    use Ekorn::Pipeline::Sugar ();

    sub import ($class, %pipelines) {
        Ekorn::Pipeline::Sugar->import_into(
            scalar caller,
            pipeline => {map { ($_ => [sub { $_->{title} }, @{ $pipelines{$_} }]) } keys %pipelines},
        );
    }
}

BEGIN { My::Titles->import(opening => [take(2)], shouted => [sub { uc }]) }

say join ', ', opening(@tracks);    # Dancing Queen, Knowing Me, Knowing You
say join ', ', shouted(@tracks[4, 5]);    # SUNSHINE OF YOUR LOVE, COUNTRY HOUSE
```

The `BEGIN` block stands for `use My::Titles ...` in a program of its
own. `import_into` checks the names, and the package's functions,
before it defines anything, but finds a bad stage, or a name another
pipeline has, only as it makes that definition, so those before it
stay defined: no matter for `use`, as the program stops, but worth
knowing for an `eval`.

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
or feed made from it. At the start of each run, the set-up of every
gather, source and sink is called, so what they keep starts afresh
(see [Made for a run](#made-for-a-run)). An iterator's run starts when
the iterator is made, not when it's first read, and a feed's when it's
made, not at its first push.

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
[A pipeline as a stage](#a-pipeline-as-a-stage)). To run them beside
the outer run, as one run of their own over every value the stage is
given, have a `gather` make a feed of the pipeline for each run, push
each value into it, close it in the flush and finish it in the end
(see [Feeds](#feeds-ekornpipelinefeed)).

## Runs and how they end

A run is one call of a pipeline with values, or one iterator or feed
made from it. Each run has its own state. A part of the pipeline that needs
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
  may ask for with [`run_context`](#stages-that-ask-about-their-run).

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

A source is made for each run so that what it opens is that run's,
and is closed as that run ends, however it ends. Its step can also
stop the run, with `Stop`, when it's had enough: the values its stop
carries are its last, and it's told `done`. This one reads a setlist
up to its encore:

```perl
use Ekorn::Pipeline::Source;

my @setlist  = ('Intro', 'Parklife', 'Song 2', 'encore', 'Tender');
my $main_set = Ekorn::Pipeline::Source->new(sub {
    my $i = 0;    # this run's
    return sub () {
        return if $i > $#setlist;
        my $song = $setlist[$i++];
        Stop() if $song eq 'encore';
        return $song;
    };
});
say join ', ', Ekorn::Pipeline->new->iterator($main_set)->all;    # Intro, Parklife, Song 2
```

The word [source](#source) makes one from a block. A source goes to
[iterator](#iterator). It isn't a stage, and given to `new` as one, it
croaks. Called directly, as a code reference, it croaks "Expected a
source to be read through iterator": a run of its own would never be
ended, so what it opened would stay open.

### Sinks: Ekorn::Pipeline::Sink

A sink is usually a pipeline's last stage, so that its result is what
a run gives (see [Making and calling a
pipeline](#making-and-calling-a-pipeline)). Anywhere else, its result
goes on through the stages after it. Its step can stop the run, with
`Stop`, once it has all it wants: it still gives its result, and is
told `done`.

```perl
use Ekorn::Pipeline::Sink;

my $total_plays = Ekorn::Pipeline::Sink->new_sink_one(sub {
    my $sum = 0;    # this run's
    return (sub ($track) { $sum += $track->{plays} }, sub () { $sum });
});

my $blur = Ekorn::Pipeline->new(
    take_if { $_->{artist} eq 'Blur' },
    $total_plays,
);
say scalar $blur->(@tracks);           # 15800
say scalar $total_plays->(@tracks);    # 36800
```

A sink can be called as a code reference with values, as the second
call does, as a pipeline of the one sink would be, and gives its
result, from a fresh sink of its set-up each time. The words
[sink_one and sink_many](#sink_one-and-sink_many) make sinks from a
block.

### Iterators: Ekorn::Pipeline::Iterator

An iterator, made by [iterator](#iterator), is one run. Called as a
code reference, `$next->()`, it hands out the next value. Its methods
read the rest at once, or only what's wanted, end the run early, and
say how it ended. A setlist, read up to its encore:

```perl
use Ekorn::Pipeline::Sources qw(from_array);

my @setlist = ('Intro', 'Parklife', 'Song 2', 'encore', 'Tender');
my $next    = Ekorn::Pipeline->new(take_while { $_ ne 'encore' })->iterator(from_array(@setlist));
my($opener) = $next->();
my @rest    = $next->all;
say "$opener, then @rest: ", $next->ended;    # Intro, then Parklife Song 2: stopped
```

`ended` says `stopped`, as `take_while` cut the reading short, with
`Tender` still to come.

`first` and `single` read a value and end the run, so nothing more is
read, and a source holding a resource, such as a file or a statement's
lock, lets it go. `single` reads one more, to warn if there's another:
for when one value is meant, and a mistake could give more.

```perl
my $numbered = Ekorn::Pipeline->new(take_if { m( \d )x });
say $numbered->iterator(from_array(@setlist))->single;    # Song 2
```

Stopping reading isn't ending the run. `finish` ends it where you
stop, rather than when the iterator goes, so a file is closed then:

```perl
my $next = Ekorn::Pipeline->new->iterator(from_file('setlist.txt'));
while (my($song) = $next->()) {
    last if $song eq 'encore';
    say $song;
}
$next->finish;    # the file is closed now
```

An iterator that's dropped before its values run out ends its run when
the last reference to it goes, as `finish` does:

```perl
my($first) = Ekorn::Pipeline->new(sub { uc })->iterator(from_file('setlist.txt'))->();
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
gives nothing. Over 300,000 values, this saves about 0.02 s.

An iterator is a source too, so it can be given to another pipeline's
`iterator`. Its values go through the second pipeline's stages, its
run ends when the second run ends, and the second run's stages see its
run's context. It's one run, so it can be a source only once, before
it has handed out everything it will; after, it croaks "Expected a
source with values still to give: an iterator is one run, and this one
is spent".

### Feeds: Ekorn::Pipeline::Feed

A feed, made by [feed](#feed), is one run, which you give values as
they arrive, with `push`, and end with `close`. A caller feeding
values asks `ended` after each push, and stops once it's defined, so
it can tell whoever is sending the values to stop too:

```perl
my $feed = Ekorn::Pipeline->new(
    take_if { $_->{plays} > 6000 },
    sub { $_->{title} },
    take(2),
)->feed;
my @hits;
for my $track (@tracks) {    # as if each arrived on its own
    push @hits, $feed->push($track);
    last if defined $feed->ended;
}
say join(', ', @hits), ': ', $feed->ended;    # Dancing Queen, Girls & Boys: stopped
```

A stop, from a stage, a flush or a sink, such as `take`'s, ends the run
in the push that meets it, as it ends any run. The values it carries
go on, the flushes of the stages after it are called, then every end,
and that push returns all of it. The values after the one that met the
stop are dropped. A stage that dies kills the run, and the push dies
with it, named as a run names it.

Once the run has ended, however it ended, `push` and `close` croak
"Expected a feed still open, but its run has ended", with the reason,
so values can't go nowhere unnoticed. A feed let go before it's closed
is finished as the last reference to it goes, as an iterator let go
is.

A feed has no context of its own. Its stages and ends see the context
of the code pushing into it, through `run_context`: none, pushed from
outside any run, or, pushed from a stage, that stage's run's, such as
a statement's columns. So a stage that feeds a branch passes its run's
context on to it. A `push`, `close` or `finish` from inside the feed's
own run, such as from one of its stages, croaks: a stage can push into
another pipeline's feed, but not its own. Each feed is a run of its
own, so a stage can keep feeds of several pipelines, or several feeds
of one, as the user guide's tee and its run for each key do.

### Stages and elements

You needn't think about these classes to use Ekorn, but they're what
you see when you look at a pipeline's parts. `new` keeps each code
reference it's given as an **Ekorn::Pipeline::Stage**, so that every
part of a pipeline is one of Ekorn's types, and each of those called
as code, a pipeline, a stage, a gather, a source, a sink and an
iterator, is an **Ekorn::Pipeline::Element**: an object called as a
code reference, which holds the closure it's called as, so it's freed
as soon as nothing else holds it. A feed is used only by its methods,
so it isn't one.

```perl
my($shout) = Ekorn::Pipeline->new(sub ($title) { uc "$title!" })->stages;
say ref $shout;                    # Ekorn::Pipeline::Stage
say $shout->call('Parklife');      # PARKLIFE!
say $shout->code->('Song 2');      # SONG 2!
```

Called directly, a stage calls its code with what it's given, but
doesn't set `$_`: only a run does, so the stage here names its value.

## Stopping a pipeline: Ekorn::Pipeline::Stop

```perl
use Ekorn::Pipeline::Stop;       # Stop
use Ekorn::Pipeline::Stop ();    # nothing: call Ekorn::Pipeline::Stop->throw
```

A stop is the exception that ends a run early and quietly.

### What a stop does

A stage stops the run when no more values are wanted: it has found
what it was looking for, or passed on as many as it was asked to. A
stop ends the run quietly, as an error doesn't, and saves the work of
making more. This stage passes on titles until it comes to the first
by Cream, which it passes on with the stop:

```perl
my @titles = Ekorn::Pipeline->new(
    sub { $_->{artist} eq 'Cream' ? Stop($_->{title}) : $_->{title} },
    sub { "* $_" },
)->(@tracks);
say for @titles;
# * Dancing Queen
# * Knowing Me, Knowing You
# * Girls & Boys
# * Parklife
# * Sunshine of Your Love
```

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

A flush can stop the pipeline too. The values its stop carries go on
through the stages after it, and the flushes after it are still
called. An end can't: the run has ended, and a stop there is an error,
"Expected no stop in an end, as the run has ended".

A module of stages, which mustn't put `Stop` among its own functions,
loads Ekorn::Pipeline::Stop with an empty list, and calls
`Ekorn::Pipeline::Stop->throw`, as the stage in [Writing
stages](#writing-stages) does. `throw` throws a stop of the class it's
called on, so a subclass's stops are its own (see
[Subclasses](#subclasses)).

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

The block is a set-up: it's called as each run starts, when the
pipeline is called with values, or an iterator or a feed is made from
it, not when `gather` is called. So whatever it declares is that
run's, as a running total starting from nothing on every run is:

```perl
sub running_total () {
    return gather {
        my $total = 0;    # this run's
        return sub ($track) { $total += $track->{plays} };
    };
}

my $p = Ekorn::Pipeline->new(running_total());
say join ' ', $p->(@tracks[0 .. 2]);    # 9100 13300 19400
say join ' ', $p->(@tracks[3 .. 5]);    # 5800 13500 17400
```

The block returns the stage's step, and, optionally, its flush and its
end (see [Made for a run](#made-for-a-run)), or a pipeline in place of
the step (see [A pipeline as the stage](#a-pipeline-as-the-stage)). A
block that returns anything else is reported as the run starts:
"Expected stage #%s, made with gather, to return a code reference or a
pipeline, and optionally a flush and an end".

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

A parent class that gives its children two methods, `pipe` and `tap`,
so that a caller can run one of its objects through stages of their
own, in the middle of a chain of method calls: `pipe` to take
something from the object and go on with that, and `tap` to do
something on the side and go on with the object. The first stage is
given the object, in `$_` and as its argument. DBIx::Squirrel's
database and statement handles have the same two methods.

```perl
package Playlist {
    use parent 'Ekorn::Pipeline::Pipes';

    sub new ($class, @tracks) { bless {tracks => [@tracks]}, $class }
    sub add ($self, @tracks) { push @{ $self->{tracks} }, @tracks; $self }
    sub tracks ($self) { @{ $self->{tracks} } }
}

my $list = Playlist->new(@tracks[0, 1])
    ->tap(sub { say 'Starting with ', scalar $_->tracks, ' tracks' })    # Starting with 2 tracks
    ->add($tracks[4]);
say join ', ', $list->pipe(sub { $_->tracks }, sub { $_->{artist} });    # ABBA, ABBA, Cream
say scalar $list->pipe(sub { $_->tracks }, take_if { $_->{plays} < 5000 }, sub { $_->{title} });    # Knowing Me, Knowing You
```

In scalar context, `pipe` gives the first result, not how many, as a
pipeline called would, so a pipeline that finds one thing reads
naturally after it.

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

Each module exports its defaults with a plain `use`, and every stage
it has with `:all`. To get the defaults and one more, name `:DEFAULT`
too:

```perl
use Ekorn::Pipeline::Stages::Flow qw(:DEFAULT take_while);
```

### Taking and dropping: Ekorn::Pipeline::Stages::Flow

Flow's stages decide which values go on, by their place or by a test.
A stage that stops the run stops the reading too, so an iterator asks
its source for no more values than are wanted.

**By place.** `take` and `drop` give a page: `drop(20), take(10)`
passes on the 21st to the 30th. `take` passes its last value on with
its stop, so the source isn't asked for one more than is wanted:

```perl
my $page = Ekorn::Pipeline->new(sub { $_->{title} }, drop(2), take(2));
say join ', ', $page->(@tracks);    # Girls & Boys, Parklife

my $read  = 0;
my @three = Ekorn::Pipeline->new(take(3))->iterator(sub { $read++ < @tracks ? $tracks[$read - 1] : () })->all;
say scalar @three, " tracks, $read read";    # 3 tracks, 3 read
```

`take_first`, `take_last` and `take_single` each pass on one value,
and are the stages of the sinks `keep_first`, `keep_last` and
`keep_single`, so a pipeline can go on after them. `take_last` reads
every value to find the last. `take_single` is for when one value is
meant: at a second, it warns and stops, so a forgotten limit is found.

```perl
my $last_quiet = Ekorn::Pipeline->new(
    take_if { $_->{plays} < 5000 },
    take_last,
    sub { "$_->{title} ($_->{plays})" },
);
say $last_quiet->(@tracks);    # Country House (3900)

sub only_by ($artist) {
    return Ekorn::Pipeline->new(take_if { $_->{artist} eq $artist }, take_single, sub { $_->{title} });
}
say only_by('Cream')->(@tracks);    # Sunshine of Your Love
say only_by('ABBA')->(@tracks);     # Dancing Queen, with a warning
```

**By a test.** `take_if` and `drop_if` test every value, as `grep`
does, and never stop the run. A plain stage ending in a test passes on
what the test returns, true or false; `take_if` passes on the value:

```perl
my $hits  = Ekorn::Pipeline->new(take_if { $_->{plays} > 6000 }, sub { $_->{title} });
my $quiet = Ekorn::Pipeline->new(drop_if { $_->{plays} > 6000 }, sub { $_->{title} });
say join ', ', $hits->(@tracks);     # Dancing Queen, Girls & Boys, Sunshine of Your Love
say join ', ', $quiet->(@tracks);    # Knowing Me, Knowing You, Parklife, Country House
```

`take_while` and `drop_while` test values only until the first that
fails, so they suit values in the order the test reads. `take_while`
stops the run there, and reads no further, where `take_if` would read
every value; `drop_while` passes on everything from there, without
testing again:

```perl
my @by_plays = sort { $b->{plays} <=> $a->{plays} } @tracks;
my $top  = Ekorn::Pipeline->new(take_while { $_->{plays} > 6000 }, sub { $_->{title} });
my $rest = Ekorn::Pipeline->new(drop_while { $_->{plays} > 6000 }, sub { $_->{title} });
say join ', ', $top->(@by_plays);     # Dancing Queen, Sunshine of Your Love, Girls & Boys
say join ', ', $rest->(@by_plays);    # Parklife, Knowing Me, Knowing You, Country House
```

### Batching and collecting: Ekorn::Pipeline::Stages::Batch

`batch` and `collect` hold values and pass them on together: `batch`
a few at a time, as for pages, or inserts of a hundred rows each, and
`collect` all of them once they've all come, for what needs them all,
such as a sort or a total. Both give up what they hold in their flush,
once the values run out, so none is lost.

```perl
my $pages = Ekorn::Pipeline->new(sub { $_->{title} }, batch(4));
say join ' / ', @$_ for $pages->(@tracks);
# Dancing Queen / Knowing Me, Knowing You / Girls & Boys / Parklife
# Sunshine of Your Love / Country House

my $most_played = Ekorn::Pipeline->new(
    collect { sort { $b->{plays} <=> $a->{plays} } @_ },
    sub { $_->{title} },
    take(2),
);
say join ', ', $most_played->(@tracks);    # Dancing Queen, Sunshine of Your Love
```

`collect` holds every value until the end, so the whole result is in
memory at once; `batch` holds no more than one batch.

### Taps: Ekorn::Pipeline::Stages::Taps

Taps look at each value as it goes by, and pass it on unchanged, for
logging, counting or debugging. `peek` and `count_into` each do one
thing; `dump_to` writes each value out, its secrets redacted; and
`tee` takes stages, so a tap can be anything a pipeline can do.

```perl
my $count;
my @titles = Ekorn::Pipeline->new(
    take_if { $_->{artist} eq 'Blur' },
    count_into(\$count),
    peek { say "  queued $_->{title}" },
    sub { $_->{title} },
)->(@tracks);
say "$count by Blur";
#   queued Girls & Boys
#   queued Parklife
#   queued Country House
# 3 by Blur
```

`count_into` sets its count to 0 as each run starts, so after a run it
holds how many values went by in that run, even if none did.

#### dump_to

`dump_to` is for seeing values as they are, while debugging. It
writes each with Data::Dumper, keys sorted and indented by two.

When [Text::Redact::Secrets](https://metacpan.org/pod/Text::Redact::Secrets)
is installed, a v1.x, each secret it finds in what's written, such as
a password, a token or the password in a DSN, is written as
`*REDACTED*`:

```perl
my $dsn = join '', 'postgres://app:', 'Zq8vR2mX', 'kP4wL9nT', '@db/app';
Ekorn::Pipeline->new(dump_to)->({dsn => $dsn});
# {
#   'dsn' => 'postgres://app:*REDACTED*@db/app'
# }
```

Only the dump is redacted: the value passed on is as it came. Without
the module, values are written as they are, and it isn't a dependency:
`cpanfile` recommends it, so installers that take recommendations
install it.

The module is looked for once, at the first dump, and tested then: it
must load, be a v1.x, the versions whose `redact` `dump_to` knows, and
redact a few made-up secrets in a dump, a password, a DSN's password
and an AWS access key id. The answer is kept for the process. If the
module is there but fails any of these, `dump_to` croaks, on that dump
and each after, rather than write a dump that may hold secrets, saying
why, and how to dump without redacting. A broken redactor would
otherwise let secrets through as if they were safe.

To write secrets as they are, set
`$Ekorn::Pipeline::Stages::Taps::DumpSecrets` true, with `local`, for
as long as you need it:

```perl
{
    local $Ekorn::Pipeline::Stages::Taps::DumpSecrets = 1;
    $pipeline->(@rows);
}
```

It's read as each value is dumped, not when the stage is made, so a
`local` around a run, or set in a stage before `dump_to`, takes effect.
While it's true, the module is neither loaded nor tested. It's
`dump_to`'s alone.

It's for debugging. Text::Redact::Secrets finds the secrets its rules
know, not every secret, so a dump can still hold some. It doesn't
escape control characters in strings, so a value from outside can send
escape sequences to a terminal.

#### tee

Where `peek` does one thing with each value, a tee's branch can look
only at some values, or the first few, batch them, total them when the
values run out, or write them through a sink:

```perl
my @hits;
my @titles = Ekorn::Pipeline->new(
    tee(take_if { $_ > 6000 }, take(2), sub { push @hits, $_; () }),
    sub { "$_ plays" },
)->(9100, 4200, 6100, 5800, 7700);
say scalar @titles, ' titles; first hits: ', join ', ', @hits;    # 5 titles; first hits: 9100, 6100
```

The branch is one run of its own, beside the main run, fed a value at
a time by a [feed](#feed) the tee makes for each main run. So the
branch's stages see every value the tee does, in order, and keep
their state across them; each main run gets a fresh branch.

- **A stop** in the branch, such as `take(2)`'s, ends only the branch.
  The tee passes the values after it on, without running them through
  the branch.
- **A death** in the branch kills the main run, as any stage's error
  does. Its message names the tee's stage, then, within it, the
  branch's, as below.
- **The branch's flushes** are called in the tee's flush, which closes
  the branch: once the main run's values have run out, before the
  stages after the tee are flushed. A total, a last batch or a sink's
  result is given then, as below. If a stop after the tee ends the
  main run first, such as `take`'s or an iterator's `first`, the tee's
  flush isn't called, so the tee closes the branch in its end: a stop
  ends the branch's input as much as running out would, so a writer in
  the branch keeps what it holds. That's new in v0.3.10; before, the
  branch's flushes weren't called, and what they held was lost. A
  branch's flush that dies there kills the run, as an end that dies
  does.
- **The branch's ends** are called as its run ends, each told how it
  ended from where it stands: in the push that met a stop or a death
  in the branch; or as the tee closes it, in its flush or its end. If
  the main run died, the tee's end doesn't close the branch, but
  finishes it, its flushes not called, and its ends told `stopped`, as
  the branch's input was cut short, as they are for an iterator read
  as a source by a run that dies.
- **The value itself** goes into the branch, not a copy, as it goes to
  `peek`'s block. A branch that changes a hash changes it for the main
  run too.
- **The main run's context** is the branch's: in the branch,
  `run_context` gives what it gives in the main run, such as a
  statement's columns.

A death in the branch, its stage #2, of a tee given as stage #1:

```text
Pipeline stage #1 failed at app.pl line 12:
    Pipeline stage #2 failed at app.pl line 12:
        bad value
```

A branch totalling what it saw, in its flush:

```perl
my $total = 0;
my @values = Ekorn::Pipeline->new(
    tee(collect { $total += $_ for @_; () }),
    sub { $_ * 2 },
)->(1 .. 4);
say "@values; total $total";    # 2 4 6 8; total 10
```

Each value costs a push into the branch: about 1.3 microseconds a
value through a branch of one plain stage, against `peek`'s 0.4, on
Perl 5.36. A tee has a flush and an end only if its branch needs
them, so a branch of plain stages leaves the main run on the plain
loop. A branch with a flush, such as `batch`'s, puts the main run on
the full path, and costs about 2.2 microseconds a value. It's for
logging, debugging and side jobs, not a hot loop.

## Sources: Ekorn::Pipeline::Sources

Ready-made sources, needing nothing beyond Perl, for
[iterator](#iterator): the values you give, numbers counting on
without end, and the records of a file or a filehandle. Each is made
afresh for each run, so each run reads from the start. Nothing is
exported by default. Each is new in v0.3.0.

```perl
use Ekorn::Pipeline::Sources qw(from_array from_fh from_file counter);
use Ekorn::Pipeline::Sources qw(:all);
```

A file is read only as far as the stages want, and closed as the run
ends, however it ends; `counter` needs a stage that stops, such as
`take`, as it never runs out:

```perl
my $next = Ekorn::Pipeline->new(take(2))->iterator(from_file('setlist.txt'));
# reads two lines, then closes the file

my @offsets = Ekorn::Pipeline->new(take(3))->iterator(counter(0, 20))->all;
say "@offsets";    # 0 20 40
```

`from_array` makes a source of values you already have, for code that
wants one, such as a chain (see
[Operators](#operators-ekornpipelineoperators)). A hash's pairs are
`from_array(map { [$_, $hash{$_}] } keys %hash)`.

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
to step by".

## Sinks: Ekorn::Pipeline::Sinks

Ready-made sinks, usually given last in a pipeline, so that a sink's
result is what the run gives (see [Sinks](#sinks-ekornpipelinesink)).
Each is made afresh for each run. Nothing is exported by default. Each
is new in v0.3.0.

```perl
use Ekorn::Pipeline::Sinks qw(keep_all count_items keep_first);
use Ekorn::Pipeline::Sinks qw(:all);
```

They come in two families. Those named for what they give, an item
being a value, have names that can't clash with Perl's built-ins or
List::Util's, which is why they're `keep_first` and `keep_all`, not
`first` and `all`. The containers, named for where the items go, are
the `to_` sinks, each the counterpart of a `from_` source: what one
reads, the other writes.

The first family keeps what's wanted, or counts it. One that needs no
more items, as `keep_first` and `keep($n)` don't once they have
theirs, stops the pull, so the source is read no further, and is told
`done`: it decided the run had enough. The source and the stages
before it are told `stopped`.

```perl
my $blur = Ekorn::Pipeline->new(take_if { $_->{artist} eq 'Blur' }, sub { $_->{title} });
say scalar pipeline($blur, keep_first)->(@tracks);     # Girls & Boys
say scalar pipeline($blur, keep_last)->(@tracks);      # Country House
say scalar pipeline($blur, count_items)->(@tracks);    # 3
say join ', ', pipeline($blur, keep(2))->(@tracks);    # Girls & Boys, Parklife
```

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

`to_fh` croaks "Expected an open filehandle" given anything else.
`to_file` opens its file, emptied, as the run starts, and croaks "Can't
write %s: %s" if it can't, as both do if they can't write, and
`to_file` if it can't close the file. Each sink taking no arguments has
an empty prototype, so `count_items + 0` reads as `count_items() + 0`.

## JSON: Ekorn::Pipeline::JSON

Four functions, one for each direction and format, each making a
different part by its options: given a `file` or an `fh`, a `from_`
function makes a source and a `to_` function a sink; given neither,
each makes a stage. Each part is made afresh for each run. Nothing is
exported by default. All four are new in v0.3.0.

```perl
use Ekorn::Pipeline::JSON qw(from_json from_jsonl to_json to_jsonl);
use Ekorn::Pipeline::Tooling qw(:json);    # the same
```

The `json` functions read and write one JSON document; the `jsonl`
functions JSON Lines, also called NDJSON. A stage passes on what a file
of its format would hold, so each `to_` function's stage is undone by
its `from_` function's:

```perl
my @lines = Ekorn::Pipeline->new(
    sub { {title => $_->{title}, plays => $_->{plays}} },
    to_jsonl(json => {canonical => 1}),
)->(@tracks[0, 1]);
say for @lines;
# {"plays":9100,"title":"Dancing Queen"}
# {"plays":4200,"title":"Knowing Me, Knowing You"}

my @titles = Ekorn::Pipeline->new(from_jsonl(), sub { $_->{title} })->(@lines);
say join ', ', @titles;    # Dancing Queen, Knowing Me, Knowing You
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

## CSV: Ekorn::Pipeline::CSV

Two functions, one for each direction, each making a different part by
its options, as JSON's do: given a `file` or an `fh`, `from_csv` makes
a source and `to_csv` a sink; given neither, each makes a stage. Each
part is made afresh for each run, so a source read twice reads its
header twice. Nothing is exported by default. Both are new in v0.3.10.

```perl
use Ekorn::Pipeline::CSV qw(from_csv to_csv);
use Ekorn::Pipeline::Tooling qw(:csv);    # the same
```

Rows are array references of their fields, or, with a `header`, hash
references keyed by its names. A header read from a file gives the
run's context its `columns`, as DBIx::Squirrel's statements do, and
`to_csv`'s `header => 1` writes them back, in their order:

```perl
my $written = Ekorn::Pipeline->new(
    to_csv(file => 'tracks.csv', header => [qw(title artist plays)]),
)->(@tracks);    # 6

my @blur = Ekorn::Pipeline->new(sub { $_->{artist} eq 'Blur' ? $_->{title} : () })
    ->iterator(from_csv(file => 'tracks.csv', header => 1))->all;
say join ', ', @blur;    # Girls & Boys, Parklife, Country House

my($copied) = Ekorn::Pipeline->new(
    take_if { $_->{plays} > 6000 },
    to_csv(file => 'hits.csv', header => 1),
)->iterator(from_csv(file => 'tracks.csv', header => 1))->all;    # 3, under title,artist,plays
```

Given no file, `to_csv`'s stage passes on each row's line, without its
end of line, and `from_csv`'s parses each value, a text of any number
of rows, as a quoted field may hold a newline. Fields are quoted as
Text::CSV quotes them, those with a space among them:

```perl
my @lines = Ekorn::Pipeline->new(to_csv(header => [qw(title plays)]))->(@tracks[0, 1]);
say for @lines;
# title,plays
# "Dancing Queen",9100
# "Knowing Me, Knowing You",4200
```

The parser is Text::CSV's: Text::CSV_XS where it's installed,
Text::CSV_PP otherwise. Ekorn only recommends Text::CSV, so the module
loads without it, and `from_csv` and `to_csv` croak when called if it
isn't installed. A file's text is UTF-8 unless `encoding` says, so its
fields are characters; text that won't decode, a character the
encoding can't hold, and a row that won't parse each croak at its row,
saying where. A byte order mark that starts the input is dropped.

| Option | Is |
|---|---|
| `file` | the path of a file to read or write; opened as the run starts, emptied if it's written, and closed once the run ends, however it ended |
| `fh` | an open filehandle, read or written with its own layers, and left open |
| `csv` | a hash reference of options for `Text::CSV->new`, over the defaults `binary` on and `auto_diag` off, such as `{sep_char => "\t"}` for TSV; or a parser object of your own, used as it is |
| `header` | reading: false, every row data, as arrays; true, the first row names each row's fields, as hashes; `'skip'`, the first row dropped, rows as arrays. Writing: false, no header, rows as arrays; an array reference of names, written first, ordering a hash's fields; true, the names from the run's context's `columns` |
| `munge` | reading, with a header: `none`, the default, `lc`, `uc`, or `db`, which makes `Track Name` `track_name`; a hash reference mapping names; or a code reference given each name, as `$_` too, as Text::CSV's `munge_column_names` |
| `encoding` | a file's encoding, as Encode names it, `UTF-8` by default, or `raw`, for bytes as they are |

A header naming a column twice croaks, when rows are hashes, as one
field's value would be lost; `munge` can name columns apart, and runs
first. A short row's missing fields are `undef`, and a long row's extra
fields are dropped.

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
it's in, by its [name](#named-pipelines), and its position there. The second
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

`croakf` is for modules of stages outside Ekorn::Pipeline too. Called
from a function that makes a stage, it reports a mistake at the line
that called the function, where the mistake was made, with nothing
more to set up:

```perl
package My::Stages::Text {
    use Ekorn::Pipeline::Errors qw(croakf);

    # Pass on each title cut to $length characters.
    sub shortened ($length) {
        croakf 'Expected a length of 1 or more, not %s', $length // 'undef'
            unless defined $length && $length =~ m( \A [1-9] \d* \z )xa;
        return sub ($title) { substr $title, 0, $length };
    }
}

say join ', ', Ekorn::Pipeline->new(sub { $_->{title} }, My::Stages::Text::shortened(8))->(@tracks[0 .. 2]);
# Dancing , Knowing , Girls & 
my $p = Ekorn::Pipeline->new(My::Stages::Text::shortened(0));
# Expected a length of 1 or more, not 0 at app.pl line 14.
```

A `%` in the message is written `%%`. Write the format as a literal in
the code. Values go in as arguments,
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

## Which result: Ekorn::Pipeline::Context

Each run counts the results it makes, and keeps the value each is
being made from, so a stage can ask which result it's making, and
from what. A *result* is a value that leaves the last stage, or that
reaches a sink. `result_number` is the run's results so far, plus one,
and `result_original` the value the run's source gave, or that was
pushed, before any stage changed it:

```perl
use Ekorn::Pipeline::Context qw(result_number result_original);    # not in Tooling

my @hits = Ekorn::Pipeline->new(
    sub { $_->{plays} > 6000 ? $_ : () },
    sub { result_number . ". $_->{title}" },
)->(@tracks);    # 1. Dancing Queen, 2. Girls & Boys, 3. Sunshine of Your Love

my @titles = Ekorn::Pipeline->new(
    sub { $_->{plays} },
    sub { $_ > 6000 ? result_original->{title} : () },
)->(@tracks);    # Dancing Queen, Girls & Boys, Sunshine of Your Love
```

- **A bare call is a term,** as a constant is: each takes no
  arguments, and has an empty prototype, so `result_number + 1` adds
  one, and `result_original // 'none'` gives `'none'` where there's
  none. In v0.3.11, `result_number + 1` died with "Too many
  arguments".
- **A value dropped makes no result,** so the number stays the same
  while a stage drops values.
- **Each value a stage returns in place of one is a result of its
  own,** numbered one after another, each with the original of the
  value it was made from. So is each value a stop carries.
- **A flush's values have no original.** In a flush, `result_number`
  is the number of the first value it returns, and `result_original`
  is undef there and in the stages after it, for the values it gives,
  as below.
- **Each run counts its own,** from 1: a pipeline run inside a stage, a
  tee's branch, and an iterator read as a source each count theirs,
  and leave the count of the run around them as it was. For a run
  reading an iterator, the original is the value the iterator handed
  out, unless its source says otherwise, as below.
- **A source can give the original itself,** with an `original` part,
  a code reference returning the original of the value it gave last,
  such as the row a statement fetched. `result_original` then gives
  what that says, calling it only when asked, and a run reading an
  iterator of that source's run gets it too, so it reaches every
  pipeline in a chain. A flush's values have none, whatever it says.
  The part answers for the value the source gave last, which is the
  one the stages are working from, as values a stage returns several
  of go through the stages before the next is pulled; but a source
  whose step returns several values at once has it answer for the
  last of them. New in v0.3.13.
- **They're for stages,** their flushes and sinks. Outside a run, and
  in an end, both give undef. In a source's step, they give where the
  run reading it has got to, which isn't promised.
- **Every run counts,** whether its stages ask or not. It costs a
  value about 15 to 75 nanoseconds, measured on Perl 5.36 and 5.44
  through one stage that does nothing: 1 to 3% for `all`, 3 to 12% for
  a pushed run, and 6 to 8% for an iterator's `next`, which counts once
  a call. Less through stages that do work. Roadmap 2026-0046's record
  has the measurements.

A batch filled by a value has that value's original; the last, given
by `batch`'s flush, has none:

```perl
my @lines = Ekorn::Pipeline->new(
    batch(4),
    sub {
        my $last = result_original ? result_original->{title} : 'from the flush';
        result_number . ': ' . @$_ . " tracks, the last $last";
    },
)->(@tracks);    # 1: 4 tracks, the last Parklife; 2: 2 tracks, the last from the flush
```

The run's context is asked with
[`run_context`](#stages-that-ask-about-their-run), and whether a
value came from a flush with [`ending`](#ending). DBIx::Squirrel has
functions of the same names, built on these, which carry its rows
through chains. So that a program importing both Toolings gets one of
each name, Ekorn::Pipeline::Tooling leaves these out in v0.3.x:
import them from Ekorn::Pipeline::Context.

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
- **Give a sink's result where the caller's stages end in a sink,** if
  the function would otherwise return an iterator. `is_sink` says
  whether a pipeline ends in one, and which kind, so the function can
  read the run itself, and return what the sink gave.

```perl
use Ekorn::Pipeline v0.1.3 qw(is_stage);

# The values given, up to the stages at the end, through those stages.
sub only (@args) {
    my @stages;
    unshift @stages, pop @args while @args && is_stage($args[-1]);
    return Ekorn::Pipeline->new(@stages)->(@args);
}

my $hits = Ekorn::Pipeline->new(take_if { $_->{plays} > 6000 }, sub { $_->{title} });
say join ', ', only(
    @tracks,
    $hits,
    take(2),
);
# Dancing Queen, Girls & Boys
```

`is_stage` is false for a string, even the name of a pipeline, so a
value such as `'clean'` is never taken for a stage.

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

```perl
use Ekorn::Pipeline v0.3.0 qw(is_sink);

# The tracks by an artist, through the caller's stages: an iterator, or,
# if the stages end in a sink, what the sink gives.
sub tracks_by ($artist, @stages) {
    my $p    = Ekorn::Pipeline->new(take_if { $_->{artist} eq $artist }, @stages);
    my $next = $p->iterator(from_array(@tracks));
    my $sink = is_sink($p) or return $next;
    return $sink eq 'one' ? $next->first : $next->all;
}

say join ', ', tracks_by('ABBA', sub { $_->{title} })->all;    # Dancing Queen, Knowing Me, Knowing You
say scalar tracks_by('Blur', count_items);    # 3
say join ', ', tracks_by('Blur', sub { $_->{title} }, keep(2));    # Girls & Boys, Parklife
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

A stage that needs to know about the values' source, such as the
names of the columns its rows have, asks `run_context` for the
context its run's source gave, here `My::Rows`'s, above. So a stage
can take a column by its name, wherever it is in the row:

```perl
sub pluck ($name) {
    return sub ($row) {
        my $columns = Ekorn::Pipeline::run_context()->{columns};
        my($at) = grep { $columns->[$_] eq $name } 0 .. $#$columns;
        return $row->[$at];
    };
}

my $titles = Ekorn::Pipeline->new(pluck('title'))->iterator(bless {sth => $sth}, 'My::Rows');
```

Each run has its own context, and an iterator used as a source passes
on the context of the run inside it. A pushed run has none, and a feed
none of its own: its stages see the context of the code pushing into
it. Which result a stage is making, and from what, it asks
[Ekorn::Pipeline::Context](#which-result-ekornpipelinecontext).

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
| a source's **original** | when a stage asks `result_original` | nothing | the original of the value the source gave last | no |

What each part's set-up returns, as a list in this order, or as a
hash reference with these keys:

| Part | Made with | Its pieces, in order | Required |
|---|---|---|---|
| a source | `source {...}`, or `EKORN_SOURCE` | `step`, `end`, `context`, `original` | the step |
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

- **Expected stage #%d to be a stage: a code reference, a pipeline, or
  an object offering a stage's role method:** a stage given to `new`
  was something else, such as a string.
- **Expected stage #%d, a pipeline, to give only stages from its stages
  method:** a stage given to `new` was a pipeline whose overridden
  `stages` method returned something that isn't a stage.
- **Expected stage #%d to be a stage: a code reference, a pipeline or
  its name, or an object offering a stage's role method:** a stage
  given to `pipeline_in`, and so to the word
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
- **Expected a source: a code reference, or an object offering
  EKORN_SOURCE:** the source given to `iterator` was something else,
  such as a stage, or a string.
- **Expected the source to return a code reference, and optionally an
  end and a context:** a source's `EKORN_SOURCE` returned something
  else. Reported when the run starts.
- **Expected the source's original to be a code reference:** a
  source's `EKORN_SOURCE` returned an original that's something else.
  Reported when the run starts.
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

### Ekorn::Pipeline::Sugar

- **Expected pipeline, not %s:** `use` was given something other than
  `pipeline` and its definitions.
- **Expected the pipelines after pipeline in a HASH or an ARRAY of
  pairs:** `pipeline` was followed by something else.
- **Expected the pipelines after pipeline in pairs of a name and an
  ARRAY:** an array of definitions had an odd number of items.
- **Expected a name for a pipeline (%s):** a name can't be a
  function's.
- **Expected a pipeline defined once (%s):** an array of definitions
  gave the name twice.
- **Expected the pipeline %s in an ARRAY:** a definition wasn't an
  array reference of stages.
- **Expected no function of the name in %s already (%s):** the package
  has a function of that name, its own or one it inherits.
- **Expected pipelines that don't name each other in a circle (%s):**
  the definitions named, those left undefined, name each other,
  through others or not.

Ekorn::Pipeline's messages for stages and names are raised for a
definition as for `pipeline`, such as "No pipeline named %s" and "A
pipeline named %s is already defined".

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
- **Expected file to be a path:** `file` was undefined.
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

### Ekorn::Pipeline::CSV

- **Can't find Text::CSV, which %s needs; install it from CPAN:**
  `from_csv` or `to_csv` was called without Text::CSV installed.
- **Can't load Text::CSV, which %s needs: %s:** it's installed, but
  failed to load; the second part says why.
- **Expected options as name => value pairs:** a function was given
  an odd number of arguments.
- **Expected the options %s, not %s:** an option it doesn't know,
  named after "not"; the first part lists those it does.
- **Expected file to be a path:** `file` was undefined.
- **Expected a file or a filehandle, not both:** it was given both
  `file` and `fh`.
- **Expected an open filehandle:** `fh` was something else.
- **Expected encoding only with a file:** `encoding` was given with a
  filehandle, or for a stage.
- **Expected an encoding Perl knows, not %s:** `encoding` wasn't `raw`
  or an encoding Encode knows.
- **Expected header to be true, false or 'skip':** `from_csv`'s
  `header` was something else.
- **Expected header to be true, false or an array reference of
  names:** `to_csv`'s `header` was something else.
- **Expected munge only with a header:** `munge` was given without a
  `header`.
- **Expected munge to be lc, uc, db, none, a hash reference or a code
  reference:** `munge` was something else.
- **Expected csv to be a hash reference of options, or a parser
  object:** `csv` was something else.
- **Expected csv options the parser knows: %s:** `csv`'s options
  included one Text::CSV doesn't have; the rest is its message.
- **Expected a header naming each column once, not "%s" twice:**
  `from_csv`, with `header` true, read a header naming a column twice,
  after munging.
- **Can't parse CSV from %s, record %d, field %d: %s:** a row wasn't
  CSV: the file's path, "the filehandle", or "a value", for a stage;
  the record, counting the header as the first; the field; and
  Text::CSV's reason.
- **Can't read %s: %s** and **Can't write %s: %s:** a file couldn't be
  opened, read, written or closed, or a filehandle written; or its
  text wouldn't decode, or a character encode, as its encoding says.
- **Expected a row as an array or a hash reference:** `to_csv` was
  given something else as a row.
- **Expected a header naming the columns, to write a hash:** `to_csv`
  was given a hash without a `header`.
- **Expected the run's context to name its columns, for to_csv's
  header:** `header` was true, but the run's context had no `columns`.
- **Can't write a row as CSV: %s:** a field was a reference, a field
  written `raw` held a character that isn't a byte, or the parser
  wouldn't combine the fields.

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

- **Expected a code reference:** `new` was given something that can't
  be called as code, such as a string.
- **Expected a code reference, not one of Ekorn's types:** `new` was
  given one of Ekorn's own types, which is already what it is.

### Ekorn::Pipeline::Iterator

- **Expected only one item, but there were more:** a warning: `single`
  found more than one value to come.
- **Expected a source with values still to give: an iterator is one
  run, and this one is spent:** an iterator was given as a source after
  it had handed out everything it will, been finished, or died.

### Ekorn::Pipeline::Feed

- **Expected a feed still open, but its run has ended: %s:** a `push`
  or `close` came after the feed's run had ended, for the reason
  given: it was closed; it was finished; a stage stopped it; or it
  died. Ask `ended` after each push, and stop pushing once it's
  defined.
- **Expected no %s of a feed from inside its own run:** a `push`,
  `close` or `finish` was called from one of the feed's own stages,
  flushes or ends. It's reported as that stage's error.

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
- **Text::Redact::Secrets %s, so dump_to won't write a dump that may
  hold secrets; local $Ekorn::Pipeline::Stages::Taps::DumpSecrets = 1
  dumps them without redacting:** `dump_to` found
  Text::Redact::Secrets installed, but can't redact with it: it failed
  to load, with the first line of its error; it isn't a v1.x; it has
  no `redact`; or it failed the self-test, leaving a made-up secret in
  a dump. Install a v1.x that works, or set `$DumpSecrets` true to
  write dumps without redacting them.

## Index

Every module, A to Z, and each of its functions and methods, A to Z,
with a synopsis of all its forms, what it does, and how it's exported.
Each ends with a link to the section that shows it in use.

### Ekorn::Pipeline

Runs values through a list of stages: its class methods make a
pipeline, and its methods run one, or tell of it. Nothing is exported
by default; `is_stage` and `is_sink` are exported upon request.

#### ending

```perl
my $flushing = Ekorn::Pipeline::ending();
```

True while a flush runs, and while the values it gave go through the
stages after it, rather than values from the source or the caller. A
pipeline run inside a stage has its own. Not exported: call it by its
full name.

See [ending](#ending).

#### feed

```perl
my $feed = $p->feed;
```

Returns a feed, an Ekorn::Pipeline::Feed: one run of the stages, given
values as they arrive, with its `push`, and ended with its `close`.
The run is made when `feed` is called, so a `gather`'s block is called
then. It takes no arguments.

See [feed](#feed).

#### is_sink

```perl
use Ekorn::Pipeline v0.3.0 qw(is_sink);

my $kind = is_sink($thing);
```

Returns `one` if `$thing` is a sink of one, giving one value, and
`many` if it's a sink of many, giving a list; for a pipeline, the kind
of sink it ends in, if any. Both are true. It's false for anything
else. A sink is anything offering `EKORN_SINK_ONE` or
`EKORN_SINK_MANY`. New in v0.3.0. Exported upon request.

See [Writing functions that take
stages](#writing-functions-that-take-stages).

#### is_stage

```perl
use Ekorn::Pipeline v0.1.3 qw(is_stage);

my $ok = is_stage($thing);
```

True if `$thing` can be used as a stage: a code reference; a pipeline
of Ekorn::Pipeline or a subclass; or an object offering one of
`EKORN_STAGE`, `EKORN_SINK_ONE` and `EKORN_SINK_MANY`, such as a
gather or a sink. It's the test `new` uses. It's false for a string,
even the name of a pipeline, and for a source.

New in v0.1.3: ask for that version on the `use` line, as above, as
v0.1.2 compiles the line, and fails only when `is_stage` is called.
Exported upon request.

See [Writing functions that take
stages](#writing-functions-that-take-stages).

#### iterator

```perl
my $next = $p->iterator($source);
while (my($result) = $next->()) {...}
```

Returns an iterator, an Ekorn::Pipeline::Iterator: one run of the
stages, handing out the results one per call, and pulling values from
`$source` only as they're needed. `$source` is a code reference,
called with nothing, returning the next value or values, or an empty
list when there are no more; or anything offering `EKORN_SOURCE`, such
as a source made for each run, or another iterator. Anything else
croaks "Expected a code reference".

Read it in list context, as above, so that a result of `undef`, 0 or
`''` isn't taken for the end. Once the results run out, it returns an
empty list, on every call.

See [iterator](#iterator).

#### name

```perl
my $name = $p->name;
```

Returns the first name the pipeline was given with `named`, qualified
by its package, as `main::clean`, or `undef` if it has none. Errors in
its stages name it. New in v0.3.0.

See [Named pipelines](#named-pipelines).

#### named

```perl
my $p = Ekorn::Pipeline->named($name => @stages);
my $p = Ekorn::Pipeline->new(@stages)->named($name);
```

Names a pipeline, keeping it under `$name` in the caller's package,
or in the package a qualified name gives, and returns it. On the
class, it makes the pipeline first, of the class, from the stages
after the name, which may be names themselves, looked up as `pipeline`
looks them up; on a pipeline, it names that one, and croaks if it's
given stages after the name.

A name is identifiers, as Perl's, joined by `::`, such as `clean` or
`My::Module::clean`; anything else croaks "Expected a name, made of
words joined by ::". A name can't be defined twice, or removed:
defining it again croaks "A pipeline named main::clean is already
defined". New in v0.3.0.

See [Named pipelines](#named-pipelines).

#### new

```perl
my $p       = Ekorn::Pipeline->new(@stages);
my @results = $p->(@values);
my $count   = $p->(@values);
```

Returns a pipeline that runs values through `@stages`, in order. Each
stage is something `is_stage` is true for: a code reference; a
pipeline, whose stages are spliced in where it stands; or a part
offering a stage's or a sink's role method, such as a gather or a
sink. Called with values, the pipeline runs each through the stages,
and returns the results, or, in scalar context, how many there are;
ending in a sink, it gives the sink's result.

Anything else given as a stage croaks, naming its position: "Expected
stage #2 to be a stage: a code reference, a pipeline, or an object
offering a stage's role method"; a source, "Expected stage #2 to be a
stage, not a source".

See [Making and calling a pipeline](#making-and-calling-a-pipeline).

#### pipeline_in

```perl
my $p = Ekorn::Pipeline->pipeline_in($package, @stages);
```

Returns a new pipeline of its invocant's class, of `@stages`, each a
code reference, a pipeline, or the name of one, looked up in
`$package` unless it's qualified. Given one name alone, it returns the
pipeline named, itself, if it's of the invocant's class or a subclass.
It's the only method that reads names, and what the word `pipeline`
calls, with its caller's package. New in v0.3.0.

See [pipeline_in](#pipeline_in).

#### run_context

```perl
my $context = Ekorn::Pipeline::run_context();
```

Returns the context the run's source gave, if any: its `context`, or
the third part its `EKORN_SOURCE` returned as a list, such as a
statement's column names. A stage calls it as it runs. New in v0.3.0.
Not exported: call it by its full name.

See [Stages that ask about their
run](#stages-that-ask-about-their-run).

#### stages

```perl
my @stages = $p->stages;
my $count  = $p->stages;
```

Returns a copy of the pipeline's stages, in order, so changing it
changes nothing in the pipeline; in scalar context, how many there
are. A pipeline given as a stage appears as the stages it was made of,
and a code reference given to `new` as an Ekorn::Pipeline::Stage of
it.

See [stages](#stages).

### Ekorn::Pipeline::Context

What a stage can ask about the result it's making. Nothing is exported
by default; each is exported upon request. Not in Tooling in v0.3.x,
as DBIx::Squirrel::Tooling exports functions of the same names. New in
v0.3.11.

#### result_number

```perl
my $n = result_number;
```

Returns the number of the result being made, from 1: the run's
results so far, plus one, a result being a value that leaves the last
stage or reaches a sink. In a flush, the number of the first value it
returns. Each run counts its own. Undef outside a run, and in an end.
Exported upon request.

See [Which result](#which-result-ekornpipelinecontext).

#### result_original

```perl
my $original = result_original;
```

Returns the value the result is being made from, as the run's source
gave it, or as it was pushed, before any stage changed it: the value
itself, not a copy. Undef in a flush and the stages after it, for the
values it gives, outside a run, and in an end. If the run's source
gave an `original` part, directly or through an iterator read as a
source, what that returns instead, called only now. Exported upon
request.

See [Which result](#which-result-ekornpipelinecontext).

### Ekorn::Pipeline::CSV

Reads and writes CSV and TSV, as sources, stages or sinks, with
Text::CSV, which is loaded when either is first called. Nothing is
exported by default; each is exported upon request, and is in
Tooling's `:csv`. Each takes the options `file`, `fh`, `csv`, `header`
and `encoding`, and `from_csv` `munge` too, which the
[CSV](#csv-ekornpipelinecsv) section describes, and is new in v0.3.10.

#### from_csv

```perl
my $source = from_csv(file => $path);
my $source = from_csv(file => $path, header => 1, munge => 'db');
my $source = from_csv(fh => $fh, header => 'skip', csv => {sep_char => "\t"});
my $stage  = from_csv();
```

Given a `file` or an `fh`, returns a source of its rows, read a row at
a time as values are pulled: array references, or, with `header`
true, hash references keyed by the header's names, which are the
run's context's `columns` whenever a header is read. Given neither,
returns a stage parsing each value, a text of any number of rows,
into its rows. Exported upon request.

See [CSV: Ekorn::Pipeline::CSV](#csv-ekornpipelinecsv).

#### to_csv

```perl
my $sink  = to_csv(file => $path);
my $sink  = to_csv(file => $path, header => [qw(title plays)]);
my $sink  = to_csv(fh => $fh, header => 1, csv => {eol => "\r\n"});
my $stage = to_csv();
```

Given a `file` or an `fh`, returns a sink writing each row, an array
or a hash reference, as a line, after the header's, and giving how
many rows it wrote. Given neither, returns a stage passing on each
row's line, without its end of line, ready for `to_file`, after the
header's. A header's names are given, or, with `header` true, the run's
context's `columns`. Exported upon request.

See [CSV: Ekorn::Pipeline::CSV](#csv-ekornpipelinecsv).

### Ekorn::Pipeline::Element

What each of Ekorn's types called as code is: an object called as a
code reference. Exports nothing.

#### call

```perl
my @results = $element->call(@arguments);
```

Does what calling the element as a code reference does, with the same
arguments.

See [Stages and elements](#stages-and-elements).

### Ekorn::Pipeline::Errors

Reports errors at the caller's line. Nothing is exported by default;
`croakf` is exported upon request. `@Ekorn::Pipeline::Errors::INTERNAL`
lists Ekorn's packages, for a module's `@CARP_NOT` (see [@INTERNAL and
@CARP_NOT](#internal-and-carp_not)).

#### croakf

```perl
use Ekorn::Pipeline::Errors qw(croakf);

croakf $format, @arguments;
```

Croaks with a message made by `sprintf` from `$format` and its
arguments, at the line Carp's `croak` would report: the line that
called the function that called `croakf`. Write `$format` as a
literal, and pass values as arguments: a format made from data does
whatever its `%` directives say. Exported upon request.

See [croakf](#croakf).

### Ekorn::Pipeline::Factories

The words that make Ekorn's types from what you write. Nothing is
exported by default; each is exported upon request, and is in
Tooling's `:words`. Each is new in v0.3.0.

#### gather

```perl
my $stage = gather { ...; return ($step, $flush, $end) };
```

The same `gather` that Ekorn::Pipeline::Gather exports by default: a
stage made afresh for each run by its block. Exported upon request.

See [gather](#gather).

#### generator

```perl
my $source = generator { ...; yield @values; ... };
```

Returns a Source giving every value its block passes to `yield`, in
order. Each run calls the block once, to its end, so the block mustn't
loop without end. An empty block, `generator {}`, reads as an empty
hash: write `generator { return }`. It croaks "Expected a code
reference" if it's given something other than a block or code
reference. Exported upon request.

See [generator and yield](#generator-and-yield).

#### pipeline

```perl
my $p = pipeline(@stages);
my $p = pipeline($name);
my $p = pipeline($name, @stages);
```

Returns a new pipeline of `@stages`, each a code reference, a
pipeline, or the name of one, looked up now, in the caller's package
unless it's qualified, as `My::Module::clean`; given one name alone,
the pipeline it names, itself. It's
`Ekorn::Pipeline->pipeline_in(scalar caller, @stages)`.

A name not defined croaks "No pipeline named main::clean"; anything
else that isn't a stage, "Expected stage #2 to be a code reference, a
pipeline or the name of one". Exported upon request.

See [Named pipelines](#named-pipelines).

#### sink_many

```perl
my $sink = sink_many { ...; return ($step, $flush, $end) };
my $sink = sink_many { ...; return ($step, $flush) };
my $sink = sink_many { ...; return {step => $step, flush => $flush} };
```

Returns a sink of many, made for each run by its block, a set-up
returning its step, called with each value, its return ignored; its
flush, giving the result, a list; and, optionally, its end, told how
the run ended. Asked for one value, a pipeline ending in it gives its
list as an array reference. It croaks "Expected a code reference" if
it's given something other than a block or code reference. Exported
upon request.

See [sink_one and sink_many](#sink_one-and-sink_many).

#### sink_one

```perl
my $sink = sink_one { ...; return ($step, $flush, $end) };
my $sink = sink_one { ...; return ($step, $flush) };
my $sink = sink_one { ...; return {step => $step, flush => $flush} };
```

Returns a sink of one, made for each run by its block, a set-up
returning its step, called with each value, its return ignored; its
flush, giving the result, one value; and, optionally, its end, told
how the run ended. It croaks "Expected a code reference" if it's given
something other than a block or code reference. Exported upon request.

See [sink_one and sink_many](#sink_one-and-sink_many).

#### source

```perl
my $source = source { ...; return ($step, $end, $context) };
my $source = source { ...; return ($step, $end) };
my $source = source { ...; return $step };
my $source = source { ...; return {step => $step, context => $context} };
```

Returns a Source, made for each run by its block, a set-up returning
its step, called with nothing, giving the next value or values, or an
empty list when there are no more; optionally, its end, told how the
run ended; and, optionally, a context, which its stages ask for with
`run_context`. It croaks "Expected a code reference" if it's given
something other than a block or code reference. Exported upon request.

See [source](#source).

#### stage

```perl
my $stage = stage { ... };
my $stage = stage sub ($value) { ... };
my $stage = stage(\&code);
```

Returns a Stage of the block, called with each value, in `$_` and as
its argument, as any stage is, but one of Ekorn's types from the
start. Give it a sub for a signature. It croaks "Expected a code
reference" if it's given something other than a block or code
reference. Exported upon request.

See [stage](#stage).

#### yield

```perl
yield @values;
```

In a generator's block, gives `@values`, in order, as the generator's
next values. It croaks "Expected yield to be called inside a
generator" when it's called outside one. Exported upon request.

See [generator and yield](#generator-and-yield).

### Ekorn::Pipeline::Feed

One run, given values as they arrive; made by `feed`, not by its
`new`. Exports nothing.

#### close

```perl
my @rest = $feed->close;
my $rest = $feed->close;
```

Ends the input, as a source running out does: calls the flushes, in
order, and returns what they give, through the stages after them, and
a sink's result; in scalar context, as an array reference. Then it
calls the ends. On a feed whose run has ended, it croaks "Expected a
feed still open, but its run has ended".

See [Feeds: Ekorn::Pipeline::Feed](#feeds-ekornpipelinefeed).

#### ended

```perl
my $how = $feed->ended;
```

Returns nothing while the run is open; then `done`, once it's closed,
`stopped`, once a stop or `finish` has ended it, and `died`, if
anything in it died.

See [Feeds: Ekorn::Pipeline::Feed](#feeds-ekornpipelinefeed).

#### finish

```perl
$feed->finish;
```

Ends the run now, as from outside, if it hasn't ended: nothing waiting
goes on, no flush is called, and each end is told `stopped`, if its
input hadn't run out. A feed let go before it's closed is finished so.

See [Feeds: Ekorn::Pipeline::Feed](#feeds-ekornpipelinefeed).

#### push

```perl
my @results = $feed->push(@values);
my $results = $feed->push(@values);
```

Runs `@values` through the stages, each through every stage before
the next, and returns what came out of them; in scalar context, as an
array reference. A value held back, as `batch` holds values, comes out
of a later push, or of `close`, as a sink's result does. On a feed
whose run has ended, it croaks "Expected a feed still open, but its
run has ended".

See [Feeds: Ekorn::Pipeline::Feed](#feeds-ekornpipelinefeed).

### Ekorn::Pipeline::Gather

A stage made afresh for each run, with a flush, called as its input
runs out, and an end. `gather` is exported by default.

#### EKORN_STAGE

```perl
my @parts = $gather->EKORN_STAGE;
```

Calls the block for a new run, and returns what it returns: the step,
and, optionally, the flush and the end. A run calls it as it starts;
you needn't.

See [gather](#gather).

#### gather

```perl
my $stage = gather { ...; return ($step, $flush, $end) };
my $stage = gather { ...; return ($step, $flush) };
my $stage = gather { ...; return ($step, undef, $end) };
my $stage = gather { ...; return $step };
my $stage = gather { ...; return {step => $step, flush => $flush, end => $end} };
my $stage = gather { ...; return $pipeline };
```

Returns a stage, an Ekorn::Pipeline::Gather, that a pipeline makes
afresh as each run starts, by calling the block, so whatever the block
declares is that run's. The block returns the step, called with each
value, or a pipeline in its place; optionally, the flush, called with
nothing once its input runs out, what it returns going on through the
stages after it; and, optionally, the end, told how the run ended.

It croaks "Expected a code reference" if it's given something other
than a block or code reference. Exported by default.

See [gather](#gather).

#### new

```perl
my $stage = Ekorn::Pipeline::Gather->new($block);
```

Makes a gather of `$block`, a code reference, as `gather` does.

See [gather](#gather).

### Ekorn::Pipeline::Iterator

One run, handing out its values, a value each `$next->()`; made by
`iterator`, not by its `new`, and a source too. Exports nothing.

#### all

```perl
my @rest = $next->all;
my $rest = $next->all;
```

Reads the run to its end, and returns every value still to come; in
scalar context, as an array reference. Values already waiting at the
end of the stages, such as a sink of many's result, it takes at once.

See [Iterators: Ekorn::Pipeline::Iterator](#iterators-ekornpipelineiterator).

#### EKORN_SOURCE

```perl
my $then = $p->iterator($next);    # a run calls $next->EKORN_SOURCE
```

Makes the iterator a source, for another pipeline's `iterator`: its
values go through the second pipeline's stages, its run ends when the
second's does, and the second's stages see its context, and its
source's original, if it gave one. It's one run,
so it can be a source only once, before it has handed out everything
it will; after, it croaks "Expected a source with values still to
give: an iterator is one run, and this one is spent". A run calls it
as it starts; you needn't.

See [Iterators: Ekorn::Pipeline::Iterator](#iterators-ekornpipelineiterator).

#### ended

```perl
my $how = $next->ended;
```

Returns nothing until the iterator has given all it will, been
finished, or died; then `done`, if the source was read to its end,
`stopped`, if a stop anywhere, such as `take`'s, or `finish`, cut the
reading short, or `finish` dropped values still to be handed out, and
`died`, if anything died.

See [Iterators: Ekorn::Pipeline::Iterator](#iterators-ekornpipelineiterator).

#### finish

```perl
$next->finish;
```

Ends the run now, if it hasn't ended: nothing more is read, and
nothing waiting is handed out. Each end is told how from where it
stands: `stopped`, if its input hadn't run out. Every call after
returns an empty list. An iterator let go before its values run out is
finished so.

See [Iterators: Ekorn::Pipeline::Iterator](#iterators-ekornpipelineiterator).

#### first

```perl
my $value = $next->first;
```

Returns the next value, or `undef` if there's none, and ends the run,
as `finish` does, so nothing more is read.

See [Iterators: Ekorn::Pipeline::Iterator](#iterators-ekornpipelineiterator).

#### single

```perl
my $value = $next->single;
```

Returns the next value, or `undef` if there's none, as `first` does,
but pulls one value more first, and warns "Expected only one item, but
there were more" if there's another. Then it ends the run.

See [Iterators: Ekorn::Pipeline::Iterator](#iterators-ekornpipelineiterator).

### Ekorn::Pipeline::JSON

Reads and writes JSON and JSON Lines, as sources, stages or sinks.
Nothing is exported by default; each is exported upon request, and is
in Tooling's `:json`. Each takes the options `file`, `fh` and `json`,
which the [JSON](#json-ekornpipelinejson) section describes, and is
new in v0.3.0.

#### from_json

```perl
my $source = from_json(file => $path);
my $source = from_json(fh => $fh, json => \%settings);
my $stage  = from_json();
my $stage  = from_json(json => $encoder);
```

Given a `file` or an `fh`, returns a source of one JSON document, read
whole: an array's elements, or the document itself, and none from an
empty input. Given neither, returns a stage decoding each value, a
document, the same way. Either croaks if it finds more than one
document, pointing to `from_jsonl`. Exported upon request.

See [JSON: Ekorn::Pipeline::JSON](#json-ekornpipelinejson).

#### from_jsonl

```perl
my $source = from_jsonl(file => $path);
my $source = from_jsonl(fh => $fh, json => \%settings);
my $stage  = from_jsonl();
my $stage  = from_jsonl(json => $encoder);
```

Given a `file` or an `fh`, returns a source of JSON Lines, a document
a line, each as it is, an array kept as one value, read a block at a
time as values are pulled. Given neither, returns a stage decoding
each value, a text of one or more lines, into each line's document.
Exported upon request.

See [JSON: Ekorn::Pipeline::JSON](#json-ekornpipelinejson).

#### to_json

```perl
my $sink  = to_json(file => $path);
my $sink  = to_json(fh => $fh, json => \%settings);
my $stage = to_json();
my $stage = to_json(json => $encoder);
```

Given a `file` or an `fh`, returns a sink writing every value, as it
comes, into one JSON array, and giving how many it wrote. Given
neither, returns a stage gathering every value, and passing on one
text, the array, once they've all come. An encoder that indents
indents each value in the array. Exported upon request.

See [JSON: Ekorn::Pipeline::JSON](#json-ekornpipelinejson).

#### to_jsonl

```perl
my $sink  = to_jsonl(file => $path);
my $sink  = to_jsonl(fh => $fh, json => \%settings);
my $stage = to_jsonl();
my $stage = to_jsonl(json => $encoder);
```

Given a `file` or an `fh`, returns a sink writing each value as a line
of JSON, and giving how many it wrote. Given neither, returns a stage
passing on each value as its line, without its newline, ready for
`to_file`. It croaks if it's given an encoder that indents, as JSON
Lines can't be indented. Exported upon request.

See [JSON: Ekorn::Pipeline::JSON](#json-ekornpipelinejson).

### Ekorn::Pipeline::Manual::HowTo

The user guide, a tour of the package from the bottom up, with
recipes, as POD made from `docs/HOWTO.md`, for reading on MetaCPAN.

### Ekorn::Pipeline::Manual::Reference

This reference, as POD made from `docs/REFERENCE.md`, for reading on
MetaCPAN.

### Ekorn::Pipeline::Operators

Puts `|`, `|=` and `@{}` in force for Ekorn's types:
`use Ekorn::Pipeline::Operators` for the rest of the scope, and
`no Ekorn::Pipeline::Operators` takes them out again (see
[Operators](#operators-ekornpipelineoperators)). Exports nothing.

#### chain

```perl
use Ekorn::Pipeline::Operators ();
use overload '|' => \&Ekorn::Pipeline::Operators::chain;
```

What `|` calls, for a class of your own whose objects start a chain,
as Ekorn's sources do. Load the module with an empty list, so it
doesn't put the operators in force in your package. Not exported: name
it in full.

See [Your source, chained with `|`](#your-source-chained-with-).

#### drain

```perl
use Ekorn::Pipeline::Operators ();
use overload '@{}' => \&Ekorn::Pipeline::Operators::drain;
```

What `@{}` calls, for a source class of your own: it reads the source
through, as a run of its own, and returns every value it gave, as an
array reference. Not exported: name it in full.

See [Your source, chained with `|`](#your-source-chained-with-).

### Ekorn::Pipeline::Pipes

A parent class giving its children two methods, `pipe` and `tap`.
Exports nothing.

#### pipe

```perl
my @results = $object->pipe(@stages);
my $first   = $object->pipe(@stages);
```

Runs the object through a pipeline of `@stages`, the first given the
object, and returns what comes out of the last; in scalar context, the
first result, or `undef` if there's none, not how many. The stages are
what `new` takes, not names: pass `pipeline('clean')` for a named one.
With no stages, it returns the object.

See [pipe and tap: Ekorn::Pipeline::Pipes](#pipe-and-tap-ekornpipelinepipes).

#### tap

```perl
$object = $object->tap(@stages);
```

Runs the object through a pipeline of `@stages`, for what they do on
the side, and returns the object, whatever the stages return, so a
chain of method calls can carry on after it.

See [pipe and tap: Ekorn::Pipeline::Pipes](#pipe-and-tap-ekornpipelinepipes).

### Ekorn::Pipeline::Sink

A sink made afresh for each run, giving one value or a list. Exports
nothing.

#### EKORN_SINK_MANY

```perl
my @parts = $sink->EKORN_SINK_MANY;
```

On a sink of many, calls its set-up for a new run, and returns what it
returns: the step, the flush and, optionally, the end. A run calls it
as it starts; you needn't.

See [Sinks: Ekorn::Pipeline::Sink](#sinks-ekornpipelinesink).

#### EKORN_SINK_ONE

```perl
my @parts = $sink->EKORN_SINK_ONE;
```

On a sink of one, calls its set-up for a new run, and returns what it
returns: the step, the flush and, optionally, the end. A run calls it
as it starts; you needn't.

See [Sinks: Ekorn::Pipeline::Sink](#sinks-ekornpipelinesink).

#### new_sink_many

```perl
my $sink = Ekorn::Pipeline::Sink->new_sink_many($setup);
```

Returns a sink of many, made for each run by `$setup`, a code
reference returning its step, called with each value, its return
ignored; its flush, giving the result, a list; and, optionally, its
end, as a list or by name. Called on a subclass with an
`EKORN_SINK_MANY` of its own, it makes the subclass; otherwise, an
Ekorn::Pipeline::Sink::Many. It croaks "Expected a code reference" if
it's given anything else.

See [Sinks: Ekorn::Pipeline::Sink](#sinks-ekornpipelinesink).

#### new_sink_one

```perl
my $sink = Ekorn::Pipeline::Sink->new_sink_one($setup);
```

Returns a sink of one, made for each run by `$setup`, a code reference
returning its step, called with each value, its return ignored; its
flush, giving the result, one value; and, optionally, its end, as a
list or by name. Called on a subclass with an `EKORN_SINK_ONE` of its
own, it makes the subclass; otherwise, an Ekorn::Pipeline::Sink::One.
It croaks "Expected a code reference" if it's given anything else.

See [Sinks: Ekorn::Pipeline::Sink](#sinks-ekornpipelinesink).

### Ekorn::Pipeline::Sinks

Ready-made sinks. Nothing is exported by default; each is exported
upon request, and is in Tooling's `:sinks`. Each is new in v0.3.0.

#### count_items

```perl
count_items
```

A sink of one, giving how many items there were. It has an empty
prototype, so `count_items + 0` reads as `count_items() + 0`. Exported
upon request.

See [Sinks: Ekorn::Pipeline::Sinks](#sinks-ekornpipelinesinks).

#### keep

```perl
keep($n)
```

A sink of many, giving the first `$n` items, as `take($n)` would pass
on, and stopping the pull once it has them. It croaks "Expected a
count of 0 or more" if `$n` isn't a whole number. Exported upon
request.

See [Sinks: Ekorn::Pipeline::Sinks](#sinks-ekornpipelinesinks).

#### keep_all

```perl
keep_all
```

A sink of many, giving every item. Asked for one value, a pipeline
ending in it gives them as an array reference, which is true even when
it's empty. Exported upon request.

See [Sinks: Ekorn::Pipeline::Sinks](#sinks-ekornpipelinesinks).

#### keep_first

```perl
keep_first
```

A sink of one, giving the first item, or `undef` if there's none, and
stopping the pull once it has it. Exported upon request.

See [Sinks: Ekorn::Pipeline::Sinks](#sinks-ekornpipelinesinks).

#### keep_last

```perl
keep_last
```

A sink of one, giving the last item, reading every one to find it, or
`undef` if there's none. Exported upon request.

See [Sinks: Ekorn::Pipeline::Sinks](#sinks-ekornpipelinesinks).

#### keep_single

```perl
keep_single
```

A sink of one, giving the one item, or `undef` if there's none. At a
second, it warns "Expected only one item, but there were more", and
stops the pull, giving the first: for when one item is meant, and a
limit was forgotten. Exported upon request.

See [Sinks: Ekorn::Pipeline::Sinks](#sinks-ekornpipelinesinks).

#### to_fh

```perl
to_fh($fh)
```

A sink of one, printing each item to `$fh`, followed by `$/`, and
giving how many it printed. It leaves `$fh` open: you opened it, so
you close it. It croaks "Expected an open filehandle" if it's given
anything else, and "Can't write %s: %s" if it can't write. Exported
upon request.

See [Sinks: Ekorn::Pipeline::Sinks](#sinks-ekornpipelinesinks).

#### to_file

```perl
to_file($path)
to_file($path, $layers)
```

A sink of one, writing each item to the file at `$path`, followed by
`$/`, through the I/O layers given, such as `':encoding(UTF-8)'`, and
giving how many it wrote. It opens the file, emptied, as the run
starts, and closes it however the run ends. It croaks "Can't write %s:
%s" if it can't open, write or close it. Exported upon request.

See [Sinks: Ekorn::Pipeline::Sinks](#sinks-ekornpipelinesinks).

### Ekorn::Pipeline::Source

A source made afresh for each run. Exports nothing.

#### EKORN_SOURCE

```perl
my @parts = $source->EKORN_SOURCE;
```

Calls the set-up for a new run, and returns what it returns: the step,
and, optionally, the end, a context and an original. A run calls it as it starts;
you needn't.

See [Sources: Ekorn::Pipeline::Source](#sources-ekornpipelinesource).

#### new

```perl
my $source = Ekorn::Pipeline::Source->new($setup);
```

Returns a source made afresh for each run by `$setup`, a code
reference returning its step, called with nothing, giving the next
value or values, or an empty list at the end; optionally, its end,
told how the run ended; and, optionally, a context, as a list or by
name. It croaks "Expected a code reference" if it's given anything
else. A source goes to `iterator`: given to `new` as a stage, or
called directly, it croaks.

See [Sources: Ekorn::Pipeline::Source](#sources-ekornpipelinesource).

### Ekorn::Pipeline::Sources

Ready-made sources, needing nothing beyond Perl. Nothing is exported
by default; each is exported upon request, and is in Tooling's
`:sources`. Each is new in v0.3.0.

#### counter

```perl
counter()
counter($start)
counter($start, $step)
```

A source of `$start`, then on by `$step`, without end, 1 and 1 by
default: give it a stage that stops, such as `take`. It croaks
"Expected a number to start from, and one to step by" if it's given
anything else. Exported upon request.

See [Sources: Ekorn::Pipeline::Sources](#sources-ekornpipelinesources).

#### from_array

```perl
from_array(@values)
```

A source of the values given, in order. Exported upon request.

See [Sources: Ekorn::Pipeline::Sources](#sources-ekornpipelinesources).

#### from_fh

```perl
from_fh($fh)
```

A source of a filehandle's records, as `$/` divides them at each read:
its lines, unless `$/` is changed, each without the separator, as
`chomp` removes it. It leaves `$fh` open. It croaks "Expected an open
filehandle" if it's given anything else. Exported upon request.

See [Sources: Ekorn::Pipeline::Sources](#sources-ekornpipelinesources).

#### from_file

```perl
from_file($path)
from_file($path, $layers)
```

A source of a file's records, as `$/` divides them at each read: its
lines, unless `$/` is changed, each without the separator, read
through the I/O layers given, such as `':raw'` or
`':encoding(UTF-8)'`. It opens the file as the run starts, croaking
"Can't read %s: %s" if it can't, and closes it however the run ends.
Exported upon request.

See [Sources: Ekorn::Pipeline::Sources](#sources-ekornpipelinesources).

### Ekorn::Pipeline::Stage

A code reference kept as a stage, one of Ekorn's types. Exports
nothing.

#### code

```perl
my $code = $stage->code;
```

Returns what the stage was made of: a code reference, or an object
called as one.

See [Stages and elements](#stages-and-elements).

#### EKORN_STAGE

```perl
my $step = $stage->EKORN_STAGE;
```

Returns the stage's step for a new run: its code, as a code reference.
A run calls it as it starts; you needn't.

See [Stages and elements](#stages-and-elements).

#### new

```perl
my $stage = Ekorn::Pipeline::Stage->new($code);
```

Returns a stage of `$code`, a code reference or an object called as
one, as `new` keeps each code reference it's given. Called directly,
the stage calls its code with what it's given, but doesn't set `$_`:
only a run does.

See [Stages and elements](#stages-and-elements).

### Ekorn::Pipeline::Stages::Batch

Canned stages gathering values. Both are exported by default, and are
in Tooling's `:batch`.

#### batch

```perl
batch($size)
```

Passes values on in batches of `$size`, each a new array reference,
holding no more than one batch at a time. Once the values run out, the
last batch goes on, which may be shorter; with no values, there's no
batch at all. It croaks "Expected a batch size of 1 or more" if
`$size` isn't a whole number above 0. Exported by default.

See [Batching and collecting:
Ekorn::Pipeline::Stages::Batch](#batching-and-collecting-ekornpipelinestagesbatch).

#### collect

```perl
collect
collect { ... }
collect(\&code)
```

Holds every value, and, once they run out, passes on an array
reference of them. Given a block, it calls the block once, with the
values as its arguments, and passes on what it returns: nothing, one
value or several, as a stage's. It gives a result even of no values:
an empty array, or what the block makes of none. It croaks "Expected a
code reference" if it's given something other than a block or code
reference. Exported by default.

See [Batching and collecting:
Ekorn::Pipeline::Stages::Batch](#batching-and-collecting-ekornpipelinestagesbatch).

### Ekorn::Pipeline::Stages::Flow

Canned stages taking or dropping values. `take` and `drop` are
exported by default, the rest upon request; all are in Tooling's
`:flow`.

#### drop

```perl
drop($n)
```

Drops the first `$n` values, and passes on the rest. It croaks
"Expected a count of 0 or more" if `$n` isn't a whole number. Exported
by default.

See [Taking and dropping:
Ekorn::Pipeline::Stages::Flow](#taking-and-dropping-ekornpipelinestagesflow).

#### drop_if

```perl
drop_if { ... }
drop_if(\&code)
```

Drops each value the block is true of, and passes on the rest, testing
every one: `take_if`'s opposite. The block gets each value in `$_` and
as its argument. It croaks "Expected a code reference" if it isn't
given a block or code reference. New in v0.3.0. Exported upon request.

See [Taking and dropping:
Ekorn::Pipeline::Stages::Flow](#taking-and-dropping-ekornpipelinestagesflow).

#### drop_while

```perl
drop_while { ... }
drop_while(\&code)
```

Drops values while the block is true of them, then passes on the rest,
starting with the first it's false of, without calling the block again
that run. The block gets each value in `$_` and as its argument. It
croaks "Expected a code reference" if it isn't given a block or code
reference. Exported upon request.

See [Taking and dropping:
Ekorn::Pipeline::Stages::Flow](#taking-and-dropping-ekornpipelinestagesflow).

#### take

```perl
take($n)
```

Passes on the first `$n` values, then stops the run, the last going
with the stop, so a source isn't asked for one more than is wanted. If
there are fewer, it passes them all on. `take(0)` passes on none, but
sees one value first, as a stage isn't called until there is one. It
croaks "Expected a count of 0 or more" if `$n` isn't a whole number.
Exported by default.

See [Taking and dropping:
Ekorn::Pipeline::Stages::Flow](#taking-and-dropping-ekornpipelinestagesflow).

#### take_first

```perl
take_first
```

Passes on the first value, then stops the run: `take(1)`, named as the
stage of the sink `keep_first`. Exported upon request.

See [Taking and dropping:
Ekorn::Pipeline::Stages::Flow](#taking-and-dropping-ekornpipelinestagesflow).

#### take_if

```perl
take_if { ... }
take_if(\&code)
```

Passes on each value the block is true of, and drops the rest,
testing every one, as `grep` does; it never stops the run. The block
gets each value in `$_` and as its argument. It croaks "Expected a
code reference" if it isn't given a block or code reference. New in
v0.3.0. Exported upon request.

See [Taking and dropping:
Ekorn::Pipeline::Stages::Flow](#taking-and-dropping-ekornpipelinestagesflow).

#### take_last

```perl
take_last
```

Passes on the last value, once there are no more, reading every one to
find it; nothing if there were none. If a stage before it stops the
run, it passes on the last value to reach it. Exported upon request.

See [Taking and dropping:
Ekorn::Pipeline::Stages::Flow](#taking-and-dropping-ekornpipelinestagesflow).

#### take_single

```perl
take_single
```

Passes on the one value. At a second, it warns "Expected only one
item, but there were more", and stops the run, so only the first goes
on. Exported upon request.

See [Taking and dropping:
Ekorn::Pipeline::Stages::Flow](#taking-and-dropping-ekornpipelinestagesflow).

#### take_while

```perl
take_while { ... }
take_while(\&code)
```

Passes on values while the block is true of them. At the first it's
false of, it stops the run, and doesn't pass that value on, so it reads
no further. The block gets each value in `$_` and as its argument. It
croaks "Expected a code reference" if it isn't given a block or code
reference. Exported upon request.

See [Taking and dropping:
Ekorn::Pipeline::Stages::Flow](#taking-and-dropping-ekornpipelinestagesflow).

### Ekorn::Pipeline::Stages::Taps

Canned stages run for what they do on the side, passing each value on
unchanged. `peek` and `count_into` are exported by default, `dump_to`
and `tee` upon request; all are in Tooling's `:taps`.

#### count_into

```perl
count_into(\$count)
```

Counts the values into `$count`, setting it to 0 as each run starts,
so after a run it holds how many went by, even if none did. It croaks
"Expected a reference to a scalar" if it isn't given one. Exported by
default.

See [Taps: Ekorn::Pipeline::Stages::Taps](#taps-ekornpipelinestagestaps).

#### dump_to

```perl
dump_to
dump_to($fh)
```

Writes each value to `$fh`, or to STDERR, with Data::Dumper, and
passes it on. With Text::Redact::Secrets v1.x installed, each secret
it finds in a dump is written `*REDACTED*`; set
`$Ekorn::Pipeline::Stages::Taps::DumpSecrets` true, with `local`, to
write them as they are. It croaks "Expected an open filehandle" if
`$fh` isn't one. Exported upon request.

See [dump_to](#dump_to).

#### peek

```perl
peek { ... }
peek(\&code)
```

Calls the block with each value, in `$_` and as its argument, and
passes the value on, whatever the block returns. It croaks "Expected a
code reference" if it isn't given a block or code reference. Exported
by default.

See [Taps: Ekorn::Pipeline::Stages::Taps](#taps-ekornpipelinestagestaps).

#### tee

```perl
tee(@stages)
```

Runs each value through a branch of `@stages`, one run of its own
beside the main run, for what they do on the side, and passes the
value on unchanged; what comes out of the branch is dropped. `@stages`
are whatever `new` takes, a sink last included, made into a pipeline
when `tee` is called, so a mistake croaks then, at your line, with
`new`'s message. With no stages, it does nothing. Exported upon
request.

See [tee](#tee).

### Ekorn::Pipeline::Stop

Ends a run early, and quietly. `Stop` is exported by default.

#### Stop

```perl
Stop();
Stop(@values);
```

Throws a stop carrying `@values`, the last values of the stage that
throws it, which go on through the stages after it. It's
`Ekorn::Pipeline::Stop->throw(@values)`. Exported by default.

See [What a stop does](#what-a-stop-does).

#### throw

```perl
Ekorn::Pipeline::Stop->throw(@values);
My::Stop->throw(@values);
```

Throws a stop carrying `@values`, blessed into the class it's called
on, so a subclass's stops are its own; a pipeline knows one with
`isa`. A stop is an array reference, its first element its class, and
the rest its values.

See [What a stop does](#what-a-stop-does).

### Ekorn::Pipeline::Sugar

Names pipelines as the program compiles, each with a function of its
name, by `use Ekorn::Pipeline::Sugar pipeline => {...}` (see [Named at
compile time](#named-at-compile-time-ekornpipelinesugar)). Exports
nothing else.

#### import_into

```perl
Ekorn::Pipeline::Sugar->import_into($package, pipeline => {...});
Ekorn::Pipeline::Sugar->import_into($package, pipeline => [...]);
```

Does what `use Ekorn::Pipeline::Sugar` does, for `$package` in place
of its caller: names each pipeline in `$package`, and gives it a
function of each name. It's for a module whose own `use` line takes
pipelines, and hands them on to the package using it.

See [Sugar of your own](#sugar-of-your-own).

### Ekorn::Pipeline::Tooling

Exports what callers use to do work, from one place, by the names of
the other modules' functions, or by tags that hold them: `:core`,
`:flow`, `:batch`, `:taps`, `:stages`, `:sources`, `:sinks`, `:json`,
`:csv`, `:words` and `:all` (see [Importing](#importing-ekornpipelinetooling)).
Nothing is exported by default. It has no names of its own.
