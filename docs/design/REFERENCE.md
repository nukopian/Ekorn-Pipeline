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
- **A new section, Delivering parts for Ekorn,** for authors of
  packages such as DBIx::Squirrel, after Writing functions that take
  stages.
- **Diagnostics, Exports and The modules** gain the new entries.

Named pipelines and `named` go back to names per package, as
2026-0011 had them, with `pipeline` imported from Factories in their
examples. Named pipelines and subclasses, and pipeline through a
subclass, go, as does Pipes' `pipeline_class`.

## Terms (additions)

- **Source:** something that gives values when it's pulled, called
  with nothing until it gives an empty list. Any code reference, or
  one made with `source`.
- **Sink:** a stage that consumes every value and, at its end, gives
  its result, one value, such as a count, or a list, such as every
  value. Usually the last stage, when its result is what the run
  gives; anywhere else, its result goes on through the stages after
  it. Made with `sink`, or ready-made, such as `count`.
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

Returns a Sink, a stage made for each run, usually the last in a
pipeline. Its set-up returns its step, called with each value, whose
return is ignored; and its end, told how the run ended, which, when
`done`, gives the result: one value or a list. Last, the result is all
the run gives; anywhere else, it goes on through the stages after it
**[Q8]**.

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
`$package`, as [Named pipelines](#named-pipelines) explains. It's the only method that reads names, and it's what every
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
| `from_fh($fh)` | a filehandle's records, as `$/` divides them: its lines, unless `$/` is changed; each without the separator, as `chomp` removes it | none: you opened it, so you close it |
| `from_file($path)` | a file's records, as `$/` divides them: its lines, unless `$/` is changed; each without the separator, as `chomp` removes it | closes the file, however the run ends |
| `from_hash(%hash)` | the keys and values given, as pairs: two-element arrays, `[$key, $value]` | none |
| `from_hashref(\%hash)` | a hash's keys and values, as pairs, read as they're asked for, not copied | none |
| `counter($start, $step)` | `$start`, then on by `$step`, without end: give it a `take` | none |
| `unfold($seed, sub {...})` | the sub, applied again and again from the seed, until it gives nothing | none |
| `cycle(@values)` | the values, round and round, without end | none |
| `concat(@sources)` | each source in turn | ends each source it read |
| `interleave(@sources)` | one value from each source in turn | ends each source it read |

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

## Sinks: Ekorn::Pipeline::Sinks

```perl
use Ekorn::Pipeline::Sinks qw(count to_array first_value);
```

Ready-made sinks, usually given last in a pipeline. Nothing is
exported by default. Each `to_` sink is the counterpart of a `from_` source: what
one reads, the other writes. The rest have names that can't clash with
Perl's built-ins or List::Util's, which is why they're `first_value`
and `joined`, not `first` and `join`.

| Sink | Gives | Stops the pull early? |
|---|---|---|
| `to_array` | every value, as a list | no |
| `to_arrayref(\@array)` | pushes each value onto your array, and gives how many | no |
| `to_fh($fh)` | prints each value to your filehandle, followed by `$/`, and gives how many | no; you opened it, so you close it |
| `to_file($path)` | writes each value to the file, followed by `$/`, and gives how many | no; it closes the file, however the run ends |
| `to_hash` | every pair's key and value, as a list to assign to a hash | no |
| `to_hashref(\%hash)` | puts every pair into your hash, and gives how many | no |
| `group_by(sub {...})` | a hash reference of arrays, grouped by what the sub gives | no |
| `count` | how many values there were | no |
| `first_value` | the first value | yes |
| `last_value` | the last value | no |
| `any_value(sub {...})` | true at the first value the sub is true of, or false | yes, when true |
| `every_value(sub {...})` | false at the first value the sub is false of, or true | yes, when false |
| `fold($init, sub {...})` | a running total of any kind, from `$init` | no |
| `joined($separator)` | the values joined into one string | no |
| `for_each(sub {...})` | calls the sub with each value, and gives how many | no |

`from_fh` and `from_file` remove `$/` from each record, and `to_fh` and
`to_file` add it back, so a file read with one is written unchanged by
the other:

```perl
my $copied = Ekorn::Pipeline->new(to_file('copy.txt'))->iterator(from_file('original.txt'))->();
```

`from_hash` and `from_hashref` give pairs, and `to_hash` and
`to_hashref` take them. To key values by something of their own, make
the pairs first:

```perl
my %by_title = Ekorn::Pipeline->new(sub { [$_->{title}, $_] }, to_hash)->(@tracks);
```

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

Loading it gives the types `|`, `|=` and `@{}`. They're a shorthand
for the commonest shapes, not the whole of Ekorn: a pipeline made with
`new` can have stages after a sink, give a list as a list, take plain
code references as stages, and, pulled with `iterator`, be a source
that gives a sink's result, none of which a chain can.

| Written | Gives |
|---|---|
| `$stage \| $stage` | a pipeline of both |
| `$source \| $stage` | a source: the source's values, through the stage |
| `$source \| ... \| $sink` | the sink's result, at once, not a source; for a source of the result, use `iterator` |
| `$pipeline \|= $stage` | adds a stage, in place |
| `@{ $source }` | every value the source gives |

A part from another package, such as a DBIx::Squirrel source, chains
with Ekorn's like any other, if it's one of the types.

**Every part of a chain must be one of the types:** a Stage, Source,
Sink or Gather, made with a word or ready-made. Between two plain
code references, `|` is Perl's bitwise OR of their addresses: it gives
a meaningless number, with no error. So write `stage { uc }` in a
chain, never `sub { uc }`. A pipeline made with `new` has no operators.

An operator gives one scalar. A sink that gives one value, such as
`count`, gives it from a chain as it is. A sink that gives a list,
such as `to_array` or `to_hash`, gives it from a chain as a reference,
to an array or a hash; or `@{}` drains a chain without a sink.
Nothing can be chained after a sink: a chain ending in one has already
run, and gives its result.

```perl
my $n      = $source | count;       # a number
my $titles = $source | to_array;    # an array reference
my @titles = @{ $source };          # a list
```

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
- The names are Ekorn's, as `named`'s are, so they can be used
  wherever stages go, a DBIx::Squirrel statement's included.

## Delivering parts for Ekorn

For the author of a package that hands out values, such as
DBIx::Squirrel, or a module reading CSV or JSON. Use Ekorn as it is:
deliver sources, sinks and stages, and let your users run them in
Ekorn's pipelines, with Ekorn's parts and their own. Don't subclass
Ekorn's classes, or wrap its words.

### What you deliver

Each is one of Ekorn's protocols, and that's all it has to keep:

- **A source,** for whatever your package reads: a code reference
  called with nothing, giving the next value or an empty list, or, if
  it opens something, made with `source`, so its end closes it however
  the run ends.
- **A sink,** for whatever it writes, made with `sink`, its end told
  how the run ended, to commit or roll back.
- **Stages,** for what only your package knows how to do with its
  values: code references, or made with `stage` or `gather`.

```perl
package My::Rows;
use Ekorn::Pipeline::Factories qw(source);

sub rows ($sth) {
    return source {
        $sth->execute;
        return (sub () { $sth->fetchrow_hashref // () }, sub ($how) { $sth->finish });
    };
}
```

### Functions that take stages

A function of yours that runs its own values through its caller's
stages finds them with `is_stage`, or takes a pipeline given last, and
runs them with `new`, as any user of Ekorn does:

```perl
sub each_row ($sth, @stages) {
    return Ekorn::Pipeline->new(@stages)->iterator(rows($sth));
}
```

`new` reads no names: your caller turns them into pipelines with
`pipeline`, where they wrote them.

### Ekorn's functions, for your users

You can export Ekorn's functions to your users, such as `Stop` or
`take`, as they are, with Exporter, so they needn't `use` two
packages. They're the same functions, so your users can mix yours and
Ekorn's freely.

### Your errors

Put `@Ekorn::Pipeline::Errors::INTERNAL` in your modules' `@CARP_NOT`,
so a mistake is reported at your users' lines.

## Diagnostics (additions)

Wording to be settled when the code is written. One for each:

- a word given something other than a block;
- a set-up that doesn't return a code reference for its step, and
  optionally one for its end;
- an end that died while the run was already dying (a warning)
  **[Q6]**;
- `|` given something that isn't one of the types.

## Exports (revised rows)

| Module | By default | On request | Tags |
|---|---|---|---|
| `Ekorn::Pipeline` | nothing | `is_stage` (and `is_source` **[Q13]**) | |
| `Ekorn::Pipeline::Factories` | nothing | `pipeline`, `stage`, `gather`, `source`, `sink` | `:all` |
| `Ekorn::Pipeline::Sources` | nothing | each source | `:all` |
| `Ekorn::Pipeline::Sinks` | nothing | each sink | `:all` |
| `Ekorn::Pipeline::Operators` | nothing: loading it is enough | | |
| `Ekorn::Pipeline::Sugar` | its import list | | |
