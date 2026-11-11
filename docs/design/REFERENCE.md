# Ekorn::Pipeline reference: draft sections

**Status:** a draft for review, roadmap 2026-0022, with
[DESIGN.md](DESIGN.md). These are the sections `docs/REFERENCE.md`
would gain or change, written as they'd read there. None of the code
in them runs yet: it shows what's proposed. Where a section depends on
an open question in the design, a note in brackets says which, such as
**[Q3]**; those notes go before anything is merged.

What changes in the reference as a whole:

- **Terms** gains Source, Sink, Made for a run, How a run ended, Word
  and Ready-made part.
- **A new section, Runs and how they end,** after How values go
  through stages.
- **A new section, Words: Ekorn::Pipeline::Factories,** after
  Pipelines, holding `pipeline`, `stage`, `gather`, `source` and
  `sink`.
- **Pipelines** gains `pipeline_in`, the method every `pipeline` word
  calls.
- **New sections for Sources, Sinks, Operators and Sugar,** after the
  canned stages.
- **A new section, Building on Ekorn,** for authors of distributions
  such as DBIx::Squirrel, after Writing functions that take stages.
- **Diagnostics, Exports and The modules** gain the new entries.

Named pipelines, Named pipelines and subclasses, and `named` stay as
they are now, with `pipeline` imported from Factories in their
examples.

## Terms (additions)

- **Source:** something that gives values when it's pulled, called
  with nothing until it gives an empty list. Any code reference, or
  one made with `source`.
- **Sink:** the last stage of a pipeline, which consumes every value
  and gives one result, such as a count. Made with `sink`, or
  ready-made, such as `count`.
- **Made for a run:** made afresh at the start of each run, by a
  set-up block, so that each run has state of its own. Gathers,
  sources and sinks can be.
- **How a run ended:** `done`, `stopped` or `died`, as each part of
  the run sees it from where it stands. A source's or a sink's end is
  told which.
- **Word:** a short function that makes one of the types, such as
  `pipeline` or `source {...}`, from Ekorn::Pipeline::Factories.
- **Ready-made part:** a stage, source or sink with a job of its own,
  such as `take(5)`, `from_file($path)` or `count`.

## Runs and how they end

A run is one call of a pipeline with values, or one iterator made from
it. Each run has its own state. A part of the pipeline that needs
state, such as a batch it's filling or a file it has open, is made
afresh for each run.

### Made for a run

A gather, source or sink made with a word has a block that's its
**set-up**. The set-up runs at the start of each run. It declares
whatever the run needs, with `my`, and returns two code references,
closures sharing what it declared:

- **the step,** called with each value (a gather or a sink), or each
  time the source is pulled (a source);
- **the end,** called once, when the run ends. It's optional for a
  gather and a source.

```perl
my $lines = source {
    open my $fh, '<', $path or die "Can't read $path: $!\n";
    return (
        sub ()     { my $line = readline $fh; defined $line ? $line : () },
        sub ($how) { close $fh },
    );
};
```

Two iterators of the same pipeline each get their own filehandle, from
their own call of the set-up. A plain code reference is never made for
a run: it's the same code, with the same closure, in every run.

### How a run ends

A run ends in one of three ways, and each part is told which, from
where it stands **[Q3]**:

| The run | The source, and the stages up to the one that stopped | The stages after it |
|---|---|---|
| ran out of values | `done` | `done` |
| was stopped by a stage | `stopped` | `done` |
| had a stage or an end die | `died` | `died` |

A stop ends the stream early for what's before it, and normally for
what's after it. So in

```perl
my $n = Ekorn::Pipeline->new(take(5), count)->iterator($lines)->();
```

`$lines` is told `stopped`, and closes its file, and `count`, after
`take(5)`, is told `done`, and gives 5.

### What an end does

A source's or a sink's end:

- **always runs, once,** however the run ended, and is given how, as
  its argument: `done`, `stopped` or `died` **[Q4]**;
- **counts only when it's `done`.** A sink's end gives the result
  then. Told `stopped` or `died`, what it returns is dropped; it runs
  only to clean up, such as closing a file or rolling back. What a
  source's end returns is always dropped;
- **runs in order:** each stage's end, first stage first, then the
  source's, once every stage has finished with what it gave **[Q5]**.

After a stage dies, every source's and sink's end still runs, told
`died`, and then the error is thrown again, as it would have been. An
end that dies then is reported as a warning, naming its stage, and the
first error is kept **[Q6]**.

A gather's end is called only when its stream ended normally: when the
values ran out, or after a stop in a stage before it. It's given no
arguments, and what it returns goes on through the stages after it,
as [End functions](#end-functions) describes. While it does,
[`ending`](#ending) is true.

### An iterator left unfinished

An iterator that's dropped before its values run out, as in

```perl
my($first) = Ekorn::Pipeline->new(sub { uc })->iterator($lines)->();
```

ends its run when the last reference to it goes: its source and sink
are told `stopped`, so `$lines` closes its file there and then. An
iterator is still a code reference, called as `$next->()` **[Q7]**.

Perl destroys a lexical iterator as soon as it goes out of scope. One
kept until the program ends is destroyed during global destruction,
when the order of destruction isn't guaranteed, so an end mustn't rely
on other objects then.

## Words: Ekorn::Pipeline::Factories

```perl
use Ekorn::Pipeline::Factories qw(pipeline stage gather source sink);
```

The words make the types, from what you write. Each is a short form of
a class method, which a class built on Ekorn can offer in a form of its
own (see [Building on Ekorn](#building-on-ekorn)). Nothing is exported
by default.

| Word | Makes | Its block |
|---|---|---|
| `pipeline(@stages)` | a pipeline | (takes a list) |
| `stage {...}` | a Stage | the stage itself |
| `gather {...}` | a Gather | a set-up, returning the step and, optionally, the end |
| `source {...}` | a Source | a set-up, returning the step and, optionally, the end |
| `sink {...}` | a Sink | a set-up, returning the step and the end |

### pipeline

```perl
pipeline(@stages)
```

Returns a new pipeline of `@stages`, each a code reference, a pipeline,
or the name of one, looked up now, in the package that called
`pipeline`. It's `Ekorn::Pipeline->pipeline_in(scalar caller, @stages)`
(see [pipeline_in](#pipeline_in)).

```perl
pipeline(sub { uc }, take(5))                # new, from stages
pipeline('clean')                            # the pipeline named clean
pipeline('clean', take(5))                   # it, then more
pipeline('My::Module::clean', sub {...})     # another package's
```

### stage

```perl
stage { BLOCK }
```

Returns a Stage: the block, called with each value, as any stage is.
It's a code reference, so it goes wherever a stage does; it's also an
object, which [the operators](#operators-ekornpipelineoperators) work
on. To give it a signature, give it a sub:
`stage sub ($row) { $row->[1] }`.

A Stage wraps what it's given, so `stage(\&trim)` never changes `trim`
itself **[Q9]**.

### gather

```perl
gather { SET-UP }
```

Returns a Gather: a stage made for each run, whose set-up returns its
stage and, optionally, an end, as [gather](#gather) describes.

```perl
sub batches_of ($size) {
    return gather {
        my @batch;    # this run's
        return (
            sub ($x) { push @batch, $x; @batch == $size ? [splice @batch] : () },
            sub ()   { @batch ? [@batch] : () },
        );
    };
}
```

`gather` is exported by Ekorn::Pipeline::Gather too, as it always has
been.

### source

```perl
source { SET-UP }
```

Returns a Source made for each run. Its set-up returns its step,
called with nothing, again and again, giving the next value or values,
or an empty list when there are no more; and, optionally, its end,
told how the run ended.

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
file-reading source in [Made for a run](#made-for-a-run) shows an end.

A source with nothing to set up or end needs no word: any code
reference is a source, as `iterator` has always taken.

### sink

```perl
sink { SET-UP }
```

Returns a Sink, to go last in a pipeline, made for each run. Its
set-up returns its step, called with each value, whose return is
ignored; and its end, told how the run ended, which, when `done`, gives
the result, the only value the run gives **[Q8]**.

```perl
my $longest = sink {
    my $max;
    return (
        sub ($s) { $max = $s if length $s > length($max // '') },
        sub ($how) { $max },
    );
};

say Ekorn::Pipeline->new($longest)->(qw(a bbb cc));    # bbb
```

## Pipelines: pipeline_in (addition)

### pipeline_in

```perl
Ekorn::Pipeline->pipeline_in($package, @stages)
```

Returns a new pipeline of its invocant's class, of `@stages`, each a
code reference, a pipeline, or the name of one, looked up in
`$package`, for its invocant's class, as
[Named pipelines and subclasses](#named-pipelines-and-subclasses)
explains. It's the only method that reads names, and it's what every
`pipeline` word calls **[Q10]**.

Call it from code the user calls directly, passing the user's package,
as a word does with `scalar caller`. Code that passes stages through,
such as a function taking stages from its caller, gives them to `new`,
which reads no names: the user has already turned any names into
pipelines with `pipeline`, where they wrote them. If `new` read names,
it would look them up in the package of whatever called it, which,
for a function passing its caller's stages on, isn't the caller's.

## Sources: Ekorn::Pipeline::Sources

```perl
use Ekorn::Pipeline::Sources qw(from_array from_file counter);
```

Ready-made sources, needing nothing beyond Perl. Nothing is exported by
default. Each returns a Source.

| Source | Gives | Its end |
|---|---|---|
| `from_array(@values)` | the values given | none |
| `from_arrayref(\@array)` | an array's values, read as they're asked for, not copied | none |
| `from_fh($fh)` | a filehandle's lines, without their newlines | none: you opened it, so you close it |
| `from_file($path)` | a file's records, as `$/` divides them: its lines, unless `$/` is changed; each without the separator, as `chomp` removes it | closes the file, however the run ends |
| `counter($start, $step)` | `$start`, then on by `$step`, without end: give it a `take` | none |
| `unfold($seed, sub {...})` | the sub, applied again and again from the seed, until it gives nothing | none |
| `cycle(@values)` | the values, round and round, without end | none |
| `concat(@sources)` | each source in turn | ends each source it read |
| `interleave(@sources)` | one value from each source in turn | ends each source it read |
| `hash_pairs(\%hash)` | a hash's keys and values, as two-element arrays | none |

```perl
my $next = Ekorn::Pipeline->new(take(2))->iterator(from_file('tracks.txt'));
# reads two lines, then closes the file
```

`from_file` reads with `$/` as it is at each read, as `readline` does,
so a caller can read a file's paragraphs, or whole records of their
own, by setting it while they pull:

```perl
local $/ = '';    # paragraph mode
my $next = Ekorn::Pipeline->new(take(3))->iterator(from_file('lyrics.txt'));
while (my($verse) = $next->()) { say "$verse\n" }    # the first three verses
```

## Sinks: Ekorn::Pipeline::Sinks

```perl
use Ekorn::Pipeline::Sinks qw(count to_array first_value);
```

Ready-made sinks, to go last in a pipeline. Nothing is exported by
default. Their names can't clash with Perl's built-ins or List::Util's,
which is why they're `first_value` and `joined`, not `first` and
`join`.

| Sink | Gives | Stops the pull early? |
|---|---|---|
| `to_array` | an array reference of every value | no |
| `into(\@array)` | pushes each value onto your array, and gives how many | no |
| `to_hash(sub {...})` | a hash reference, each value keyed by what the sub gives | no |
| `group_by(sub {...})` | a hash reference of arrays, grouped by what the sub gives | no |
| `count` | how many values there were | no |
| `first_value` | the first value | yes |
| `last_value` | the last value | no |
| `any_value(sub {...})` | true at the first value the sub is true of, or false | yes, when true |
| `every_value(sub {...})` | false at the first value the sub is false of, or true | yes, when false |
| `fold($init, sub {...})` | a running total of any kind, from `$init` | no |
| `joined($separator)` | the values joined into one string | no |
| `to_file($path)` | writes each value as a line, and gives how many | no; it closes the file |
| `for_each(sub {...})` | calls the sub with each value, and gives how many | no |

A sink that stops the pull early is told `done`: it decided the run
had enough. The source and the stages before it are told `stopped`.

```perl
say Ekorn::Pipeline->new(count)->(1 .. 10);                          # 10
say Ekorn::Pipeline->new(first_value)->iterator(counter(1, 1))->();  # 1, then stops
```

## Operators: Ekorn::Pipeline::Operators

```perl
use Ekorn::Pipeline::Operators;
```

Loading it gives the types `|`, `|=` and `@{}`:

| Written | Gives |
|---|---|
| `$stage \| $stage` | a pipeline of both |
| `$source \| $stage` | a source: the source's values, through the stage |
| `$source \| ... \| $sink` | the sink's result, at once |
| `$pipeline \|= $stage` | adds a stage, in place |
| `@{ $source }` | every value the source gives |

A chain is of the class of its left-hand side, so a class built on
Ekorn chains as its own.

**Every part of a chain must be one of the types:** a Stage, Source,
Sink or Gather, made with a word or ready-made. Between two plain
code references, `|` is Perl's bitwise OR of their addresses: it gives
a meaningless number, with no error. So write `stage { uc }` in a
chain, never `sub { uc }`. A pipeline made with `new` has no operators.

An operator gives one scalar, so a sink at the end gives one result,
and `@{}` is how a source gives a list.

## Sugar: Ekorn::Pipeline::Sugar

```perl
use Ekorn::Pipeline::Sugar
    pipeline => {
        trimmed => [sub { s( \A \s+ | \s+ \z )()xgr }],
        clean   => ['trimmed', sub { length ? $_ : () }],
    };
```

Names pipelines as the program compiles, in the package that uses it,
as `named` would, and gives the package a function of each name, which
runs values through the pipeline, taking more stages as a pipeline
given last:

```perl
my @tidy = clean(@raw);
my @five = clean(@raw, pipeline(take(5)));
```

- A definition can name any other in the same `use`, whatever order
  they're given in; each is defined once those it names are. A cycle,
  or a name defined nowhere, croaks as the program compiles.
- Definitions can be given as a hash, or as an array of pairs, to read
  in order.
- A name, and a function of it already in the package, are checked as
  DBIx::Squirrel::Sugar checks them, with the same messages.
- It makes Ekorn::Pipelines. A distribution built on Ekorn defines its
  own, with its own class's `named`.

## Building on Ekorn

For the author of a distribution built on Ekorn::Pipeline, such as
DBIx::Squirrel, whose users get pipelines of its own class.

### Your own class

Subclass Ekorn::Pipeline where you change how your pipelines behave:

```perl
package My::Pipeline;
use parent 'Ekorn::Pipeline';
```

It inherits `new`, `pipeline_in`, `named`, `iterator` and `stages`, and
each makes or names your class. Names defined through your class are
yours: your users' `pipeline` finds yours and Ekorn's; Ekorn's own
never finds yours (see
[Named pipelines and subclasses](#named-pipelines-and-subclasses)).

### Your own words

Give your users words that make your class, in a module of your own,
one line each, as Ekorn::Pipeline::Factories does, and pass on
Ekorn's words for the types you don't subclass:

```perl
package My::Factories;
use Exporter qw(import);
use Ekorn::Pipeline::Factories qw(stage gather source sink);

our @EXPORT_OK = qw(pipeline stage gather source sink);

sub pipeline (@stages) { My::Pipeline->pipeline_in(scalar caller, @stages) }
```

`scalar caller` is the user's package, as they call your word
directly, so names are looked up where they wrote them.

### Your own pipe and tap

A class using Ekorn::Pipeline::Pipes makes Ekorn::Pipelines in `pipe`
and `tap`, unless it says otherwise:

```perl
sub pipeline_class ($self) { 'My::Pipeline' }
```

### Your own stop

`Stop` throws an Ekorn::Pipeline::Stop. To throw a subclass of yours,
give your users a `Stop` of your own: `sub Stop (@values) {
My::Stop->throw(@values) }`.

### Your errors

Put `@Ekorn::Pipeline::Errors::INTERNAL` in your modules' `@CARP_NOT`,
so a mistake is reported at your users' lines.

## Diagnostics (additions)

Wording to be settled when the code is written. One for each:

- a word given something other than a block;
- a set-up that doesn't return a code reference for its step, and
  optionally one for its end;
- a sink not given last;
- an end that died while the run was already dying (a warning)
  **[Q6]**;
- `|` given something that isn't one of the types.

## Exports (revised rows)

| Module | By default | On request | Tags |
|---|---|---|---|
| `Ekorn::Pipeline` | nothing | `is_stage` (and `is_source` **[Q15]**) | |
| `Ekorn::Pipeline::Factories` | nothing | `pipeline`, `stage`, `gather`, `source`, `sink` | `:all` |
| `Ekorn::Pipeline::Sources` | nothing | each source | `:all` |
| `Ekorn::Pipeline::Sinks` | nothing | each sink | `:all` |
| `Ekorn::Pipeline::Operators` | nothing: loading it is enough | | |
| `Ekorn::Pipeline::Sugar` | its import list | | |
