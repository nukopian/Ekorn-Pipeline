# Ekorn::Pipeline reference: draft sections

**Status:** a draft for review, roadmap 2026-0022, with
[DESIGN.md](DESIGN.md). These are the sections `docs/REFERENCE.md`
would gain or change, written as they'd read there. None of the code
in them runs yet: it shows what's proposed. Where a section depends on
an open question, a note in brackets says which, such as **[Q3]**;
those notes go before anything is merged.

What changes in the reference as a whole:

- **Terms** gains Source, Sink, Run's end, Word and Ready-made part.
- **A new section, Runs and how they end,** after How values go
  through stages.
- **A new section, Words: Ekorn::Pipeline::Factories,** after
  Pipelines, holding `pipeline` (moved from Pipelines) and the block
  words.
- **Pipelines** loses `pipeline`, and gains `pipeline_in`.
- **New sections for Sources, Sinks, Operators and Sugar,** after the
  canned stages.
- **A new section, Building on Ekorn,** for authors of distributions
  such as DBIx::Squirrel, after Writing functions that take stages.
- **Diagnostics, Exports and The modules** gain the new entries.

Named pipelines, Named pipelines and subclasses, and `named` stay as
they are now, except that `pipeline` comes from Factories.

## Terms (additions)

- **Source:** something that gives values when it's pulled, called
  with nothing until it gives an empty list. A code reference, or one
  made with `source`.
- **Sink:** the last stage of a pipeline, which consumes every value
  and gives one result, such as a count. Made with `sink`, or
  ready-made, such as `count`.
- **How a run ended:** `done`, `stopped` or `died`, as each part of
  the run sees it from where it stands. An end is told which.
- **Word:** a short function that makes one of the types, such as
  `pipeline` or `source {...}`, from Ekorn::Pipeline::Factories.
- **Ready-made part:** a stage, source or sink with a job of its own,
  such as `take(5)`, `file_lines($path)` or `count`.

## Runs and how they end

A run is one call of a pipeline with values, or one iterator made from
it. Each run has its own state. A part of the pipeline that needs
state, such as a running total or an open file, is made afresh for
each run, and can have an end, called once when the run ends.

### Made for a run

A stage or source made with `gather`, `source` or `sink`, with a
`step` after its block, has three parts:

- **the set-up,** its first block, called at the start of each run.
  What it returns is the run's state: a filehandle, a total, or a
  hash reference holding several things;
- **the step,** called for each value (a gather or a sink) or each
  pull (a source), given the state as `$_[0]`. In a gather's or a
  sink's step, the value is `$_[1]`, and also `$_`, as in any stage;
  in a source's step, which has no value, `$_` is the state **[Q23]**;
- **the end,** called once, when the run ends, given the state as
  `$_` and `$_[0]`, and how the run ended as `$_[1]`.

```perl
my $lines = source { open my $fh, '<', $path or die "Can't read $path: $!\n"; $fh }
            step   { my $line = readline $_; defined $line ? $line : () }
            end    { close $_ };
```

Two iterators of the same pipeline each get their own state, from
their own call of the set-up.

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

the source, `$lines`, is told `stopped` and closes its file; `take(5)`,
which stopped, is told `stopped`; and `count`, after it, is told
`done`, and gives 5.

### What an end does

- **It always runs, once,** however the run ended.
- **What it returns counts only when it's told `done`:** a gather's
  end lets out its last values, and a sink's gives the result. Told
  `stopped` or `died`, what it returns is dropped; it runs only to
  clean up, such as closing a file. **[Q4]**
- **The ends run in order,** the first stage's first, and the
  source's last, once every stage has finished with what it gave.
  **[Q5]**
- **After a stage dies,** every end still runs, told `died`, and then
  the error is thrown again, as it would have been. An end that dies
  then is reported as a warning, naming its stage, and the first error
  is kept. **[Q6]**
- While the values an end returns go through the stages after it,
  [`ending`](#ending) is true.

```perl
my $total = sink { \my $sum }
            step { ${ $_[0] } += $_ }
            end  { ${ $_[0] } };    # counts only when told done
```

A gather made the old way, whose block returns a stage and an end, is
unchanged: after a stop, the ends of the stage that stopped and those
before it aren't called, and an end isn't told how the run ended.

### An iterator left unfinished

An iterator that's dropped before its values run out, as in

```perl
my($first) = Ekorn::Pipeline->new(sub { uc })->iterator($lines)->();
```

ends its run when the last reference to it goes: every part is told
`stopped`, so `$lines` closes its file there and then. An iterator is
still a code reference, called as `$next->()`. **[Q7]**

Perl destroys a lexical iterator as soon as it goes out of scope. One
kept until the program ends is destroyed during global destruction,
when the order of destruction isn't guaranteed, so an end mustn't rely
on other objects then.

## Words: Ekorn::Pipeline::Factories

```perl
use Ekorn::Pipeline::Factories qw(pipeline);
use Ekorn::Pipeline::Factories qw(:blocks);    # source, stage, sink, gather, step, end
```

The words make the types, from what you write. Each is a short form of
a class method, which a class built on Ekorn can offer in a form of its
own (see [Building on Ekorn](#building-on-ekorn)). Nothing is exported
by default. `step` and `end` are exported only with `:blocks`, so a
name as short as `end` is never imported alone. **[Q11]**

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

Moved here from Ekorn::Pipeline in v0.2.1, before it was released.

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
itself. **[Q9]**

### source

```perl
source { STEP }
source { SET-UP } step { STEP } end { END }
```

Returns a Source. With one block, the block is its step: called with
nothing, again and again, it gives the next value or values, or an
empty list when there are no more. With a `step` after it, the first
block is the set-up, as [Made for a run](#made-for-a-run) describes,
and `end` is optional.

```perl
my $n     = 0;
my $count = source { ++$n <= 3 ? $n : () };    # 1, 2, 3
```

### sink

```perl
sink { SET-UP } step { STEP } end { END }
```

Returns a Sink, to go last in a pipeline. Its step is called with each
value, and returns nothing; its end, told `done`, gives the result,
which is the only value the run gives. **[Q8]**

```perl
my $longest = sink { \my $max }
              step { ${ $_[0] } = $_ if length > length(${ $_[0] } // '') }
              end  { ${ $_[0] } };

say Ekorn::Pipeline->new($longest)->(qw(a bbb cc));    # bbb
```

### gather

```perl
gather { BLOCK }                                # the old form
gather { SET-UP } step { STEP } end { END }     # the new form
```

The old form is as [gather](#gather) describes: its block returns a
stage and, optionally, an end. The new form is a stage with a set-up
and an end, made for each run: its step can return nothing (drop the
value), one value or several; its end, told `done`, lets out what it
held.

```perl
my $pairs = gather { [] }
            step   { push @{ $_[0] }, $_; @{ $_[0] } == 2 ? [splice @{ $_[0] }] : () }
            end    { @{ $_[0] } ? [@{ $_[0] }] : () };
```

`gather` is exported by Ekorn::Pipeline::Gather too, as it always has
been.

### step and end

```perl
step { BLOCK }
end  { BLOCK }
```

They carry a block to the word in front of them, and mean nothing on
their own. A block takes no signature; `step sub ($state, $value)
{...}` gives one.

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
`pipeline` word calls. **[Q10]**

Call it from code the user calls directly, passing the user's package,
as a word does with `scalar caller`. Code that passes stages through,
such as a function taking stages from its caller, gives them to `new`,
which reads no names: the user has already turned any names into
pipelines with `pipeline`, where they wrote them.

## Sources: Ekorn::Pipeline::Sources

```perl
use Ekorn::Pipeline::Sources qw(from file_lines counter);
```

Ready-made sources, needing nothing beyond Perl. Nothing is exported by
default. Each returns a Source.

| Source | Gives | Its end |
|---|---|---|
| `from(@values)` | the values given | none |
| `from_array(\@array)` | an array's values, read as they're asked for, not copied | none |
| `lines($fh)` | a filehandle's lines, without their newlines | none: you opened it, so you close it |
| `file_lines($path)` | a file's lines, without their newlines | closes the file, however the run ends |
| `counter($start, $step)` | `$start`, then on by `$step`, without end: give it a `take` | none |
| `unfold($seed, sub {...})` | the sub, applied again and again from the seed, until it gives nothing | none |
| `cycle(@values)` | the values, round and round, without end | none |
| `concat(@sources)` | each source in turn | ends each source it read |
| `interleave(@sources)` | one value from each source in turn | ends each source it read |
| `hash_pairs(\%hash)` | a hash's keys and values, as two-element arrays | none |

```perl
my $next = Ekorn::Pipeline->new(take(2))->iterator(file_lines('tracks.txt'));
# reads two lines, then closes the file
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
say Ekorn::Pipeline->new(count)->(1 .. 10);                         # 10
say Ekorn::Pipeline->new(first_value)->iterator(counter(1, 1))->(); # 1, then stops
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
one line each, as Ekorn::Pipeline::Factories does:

```perl
package My::Factories;
use Exporter qw(import);
use Ekorn::Pipeline::Factories qw(:blocks);    # words whose types you don't subclass

our @EXPORT_OK = qw(pipeline stage step end);

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

- a block word given something other than a block;
- `step` or `end` used without a word in front of it;
- a sink not given last;
- an end that died while the run was already dying (a warning)
  **[Q6]**;
- `|` given something that isn't one of the types.

## Exports (revised rows)

| Module | By default | On request | Tags |
|---|---|---|---|
| `Ekorn::Pipeline` | nothing | `is_stage` (and `is_source` **[Q16]**) | |
| `Ekorn::Pipeline::Factories` | nothing | `pipeline`, `stage`, `source`, `sink`, `gather` | `:blocks`, with `step` and `end` |
| `Ekorn::Pipeline::Sources` | nothing | each source | `:all` |
| `Ekorn::Pipeline::Sinks` | nothing | each sink | `:all` |
| `Ekorn::Pipeline::Operators` | nothing: loading it is enough | | |
| `Ekorn::Pipeline::Sugar` | its import list | | |
