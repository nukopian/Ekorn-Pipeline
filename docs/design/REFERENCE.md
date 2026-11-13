# Ekorn::Pipeline reference: draft sections

**Status:** a draft for review, roadmap 2026-0022, with
[DESIGN.md](DESIGN.md). These are the sections `docs/REFERENCE.md`
would gain or change, written as they'd read there. The code in them
is the design's; IMPLEMENTATION.md says what the prototype on
`pipeline-experimental` runs, and where it differs.

What changes in the reference as a whole:

- **Terms** gains Source, Sink, Made for a run, How a run ended, Word
  and Ready-made part.
- **A new section, Runs and how they end,** after How values go
  through stages.
- **A new section, Words: Ekorn::Pipeline::Factories,** after
  Pipelines, holding `pipeline`, `stage`, `gather`, `source`,
  `sink_one` and `sink_many`.
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
- **Sink:** a part that consumes every value and, when they run out,
  gives its result: one value, such as a count, for a sink of one, or
  a list, such as every value, for a sink of many, which, asked for one
  value, gives its list as an array reference. Usually the last stage,
  when its result is what the run gives; anywhere else, its result
  goes on through the stages after it. Made with `sink_one` or `sink_many`, or ready-made, such as `count_items`.
- **Made for a run:** made afresh at the start of each run, by a
  set-up block, so that each run has state of its own. Gathers,
  sources and sinks can be.
- **How a run ended:** `done`, `stopped` or `died`, as each part of
  the run sees it from where it stands. Each part's end, if it has
  one, is told which.
- **Flush:** what a gather or a sink gives when its input runs out: a
  gather's held values, a sink's result.
- **Word:** a short function that makes one of the types, such as
  `pipeline` or `source {...}`, from Ekorn::Pipeline::Factories.
- **Ready-made part:** a stage, source or sink with a job of its own,
  such as `take(5)`, `from_file($path)` or `count_items`.

## Runs and how they end

A run is one call of a pipeline with values, or one iterator made from
it. Each run has its own state. A part of the pipeline that needs
state, such as a batch it's filling or a file it has open, is made
afresh for each run.

### Made for a run

A gather, source or sink made with a word has a block that's its
**set-up**. The set-up runs at the start of each run. It declares
whatever the run needs, with `my`, and returns closures sharing what
it declared:

- **the step,** called with each value (a gather or a sink), or each
  time the source is pulled (a source);
- **the flush,** for a gather or a sink, called once its input runs
  out, what it returns going on: a sink's gives its result, and is
  required;
- **the end,** called once, when the run has ended, told how. It's
  optional;
- **a context,** for a source only, and optional: anything its stages
  may ask for with `run_context()`.

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
where it stands: `died` if the run died, anywhere, before it
ended; `stopped` if its input was cut short, by a stop at or after it,
or by the run being ended from outside; and `done` if its input ran
out, and the run didn't die, which wins over the table: a part whose
input had run out before a stop is told `done`. A sink that stops the
run itself is told `done`. For the commonest runs:

| The run | The source, and the stages up to and including the one that stopped | The stages after it |
|---|---|---|
| ran out of values | `done` | `done` |
| was stopped by a stage | `stopped`, if it still had values to come | `done` |
| had a stage or an end die | `died` | `died` |

A stop ends the stream early for what's before it, and normally for
what's after it. So in

```perl
my $n = Ekorn::Pipeline->new(take(5), count_items)->iterator($lines)->();
```

`$lines` is told `stopped`, and closes its file, and `count_items`, after
`take(5)`, is told `done`, and gives 5.

### Flushes and ends

A flush, a gather's or a sink's, is called once its input runs out
normally: when the values ran out, after a stop in a stage before it,
or, for a sink, when the sink stopped the run, as `keep_first` does.
What it returns goes on through the stages after it, and while it
runs, and they do, [`ending`](#ending) is true. The flush of a sink of one
gives one value, `undef` if it has none. It isn't told how the run ended, as the
run hasn't. A gather's flush is what v0.2.0 called its end function,
as [End functions](#end-functions) describes.

An end:

- **always runs, once, when the run has ended,** however it ended, and
  is given how, as its argument: `done`, `stopped` or `died`.
  A run has ended as soon as nothing in it can still act on a value,
  so with a sink last, it ends as the sink's result is ready, and a
  sink that commits only when told `done` commits then, and never for
  a run that dies after it;
- **gives nothing:** what it returns is dropped;
- **runs in order:** the source's end first, then each stage's, first
  stage first, so a source that fails to close is known before any
  sink commits.

After a stage dies, every end still runs, told `died`, and then the
error is thrown again, as it would have been. An end that dies then is
reported as a warning, naming its stage, and the first error is kept.

### An iterator left unfinished

An iterator that's dropped before its values run out, as in

```perl
my($first) = Ekorn::Pipeline->new(sub { uc })->iterator($lines)->();
```

ends its run when the last reference to it goes: each part is told
how from where it stands, `stopped` if its input hadn't run out, so
`$lines` closes its file there and then. An iterator is called as a
code reference, `$next->()`, as before.

`$next->finish` ends its run sooner, the same way. And
`$next->ended` says whether the source was read to its end: nothing
until the iterator has given all it will, been finished or died; then
`done` if it was, `stopped` if a stop anywhere, such as `take(5)`'s or
`keep_first`'s, or `finish`, cut the reading short, or `finish`
dropped values still to be handed out, and `died` if anything died.

Three methods pull what's left in one call:

```perl
my @rest  = $next->all;       # every value still to come; read to the end
my $rest  = $next->all;       # the same, as an array reference
my $first = $next->first;     # the next value, or undef; then the run ends
my $one   = $next->single;    # the next value, or undef, warning if there's another; then the run ends
```

`all` reads the run to its end. `first` and `single` end it, as
`finish` does, so nothing more is read, and a source holding a
resource, such as a statement's lock, lets it go. `single` pulls one
value more to check there's no other, and warns "Expected only one
item, but there were more" if there is, as `keep_single` does.

An iterator is an object, so each `$next->()` goes through Perl's
overloading of `&{}` to find its code. A loop pulling many values can
take the code reference once, and call it directly:

```perl
my $pull = \&$next;    # the iterator's code, found once
while (my ($value) = $pull->()) { ... }
```

Keep `$next` while you use `$pull`: the code reference doesn't keep
the iterator, and an iterator let go ends its run, after which `$pull`
gives nothing. Over 300,000 values, this saves about 0.03 s.

Perl destroys a lexical iterator as soon as it goes out of scope. One
kept until the program ends is destroyed during global destruction,
when the order of destruction isn't guaranteed, so an end mustn't rely
on other objects then.

## Words: Ekorn::Pipeline::Factories

```perl
use Ekorn::Pipeline::Factories qw(pipeline stage gather source sink);
```

The words make the types, from what you write. Each is a short form of
a class method. A package built on Ekorn uses them as they are (see
[Delivering parts for Ekorn](#delivering-parts-for-ekorn)). Nothing is
exported by default.

| Word | Makes | Its block |
|---|---|---|
| `pipeline(@stages)` | a pipeline | (takes a list) |
| `stage {...}` | a Stage | the stage itself |
| `gather {...}` | a Gather | a set-up, returning the step, and, optionally, the flush and the end |
| `source {...}` | a Source | a set-up, returning the step, and, optionally, the end and a context |
| `sink_many {...}` | a Sink of many | a set-up, returning the step, the flush, giving the result, a list, and, optionally, the end |
| `sink_one {...}` | a Sink of one | the same, its flush giving one value |

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
It's an object called as a code reference, so it goes wherever a stage
does, and [the operators](#operators-ekornpipelineoperators) work on
it. To give it a signature, give it a sub:
`stage sub ($row) { $row->[1] }`.

A Stage wraps what it's given, so `stage(\&trim)` never changes `trim`
itself.

### gather

```perl
gather { SET-UP }
```

Returns a Gather: a stage made for each run, whose set-up returns its
step, and, optionally, its flush, and an end told how the run ended,
as [gather](#gather) describes.

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
or an empty list when there are no more; optionally, its end, told how
the run ended; and, optionally, a context for the run, anything its
stages may want to know, which they ask for with
`Ekorn::Pipeline::run_context()`. With a context but no end, give
`undef` for the end.

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
sink_many { SET-UP }
```

```perl
sink_one { SET-UP }
```

Returns a Sink, made for each run, usually the last in a pipeline.
Its set-up returns its step, called with each value, whose return is
ignored; its flush, called when its input runs out, giving its result;
and, optionally, its end, told how the run ended once it has. A sink
made with `sink_many` gives a list; one made with `sink_one` gives one
value. Asked for one value, in scalar context or at the end of a `|`
chain, a sink of many gives its list as an array reference, so write a
sink of one value with `sink_one`: one written with `sink_many` would
give its value in an array reference. Last, the result is all the run
gives; anywhere else, it goes on through the stages after it.

```perl
my $longest = sink_one {
    my $max;
    return (
        sub ($s) { $max = $s if length $s > length($max // '') },
        sub () { $max },
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
`pipeline` word calls.

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
use Ekorn::Pipeline::Sinks qw(keep_all count_items keep_first);
```

Ready-made sinks, usually given last in a pipeline. Nothing is
exported by default. They come in two families. Those named for what
they give, an item being a value, have names that can't clash with
Perl's built-ins or List::Util's, which is why they're `keep_first`
and `joined`, not `first` and `join`. The containers, named for where
the items go, are the `to_` sinks, each the counterpart of a `from_`
source: what one reads, the other writes.

| Sink | Gives | Stops the pull early? |
|---|---|---|
| `keep_all` | every item, as a list | no |
| `keep_first` | the first item, or `undef` if none | yes |
| `keep_single` | the one item, or `undef` if none; at a second, a warning, and the first, for when you meant one and forgot to limit it | at a second |
| `keep_last` | the last item, reading every one to find it, or `undef` if none | no |
| `keep($n)` | the first `$n` items, as a list, as `take($n)` would pass on; it croaks "Expected a count of 0 or more" as `take` does | yes, at `$n` |
| `any_item(sub {...})` | true at the first item the sub is true of, or false | yes, when true |
| `every_item(sub {...})` | false at the first item the sub is false of, or true | yes, when false |
| `count_items` | how many items there were | no |
| `fold($init, sub {...})` | a running total of any kind, from `$init` | no |
| `joined($separator)` | the items joined into one string | no |
| `group_by(sub {...})` | a hash reference of arrays, grouped by what the sub gives | no |
| `for_each(sub {...})` | calls the sub with each item, and gives how many | no |
| `to_fh($fh)` | prints each item to your filehandle, followed by `$/`, and gives how many | no; you opened it, so you close it |
| `to_file($path)` | writes each item to the file, followed by `$/`, and gives how many | no; it closes the file, however the run ends |

Asked for one value, in scalar context or at the end of a `|` chain,
a sink giving a list gives it as an array reference; for how many,
use `count_items`:

```perl
my @titles = $pipeline->(@books);    # with keep_all last: every title
my $titles = $pipeline->(@books);    # every title, as an array reference
```

An array reference is true even when it's empty, so test for no items
with `@$titles`, or use `count_items`.

`from_fh` and `from_file` remove `$/` from each record, and `to_fh` and
`to_file` add it back, so a file read with one is written unchanged by
the other:

```perl
my $copied = Ekorn::Pipeline->new(to_file('copy.txt'))->iterator(from_file('original.txt'))->();
```

There's no sink for an array or a hash: `keep_all` gives every item,
and `push @mine, @{ $source | keep_all }` adds them to your array. A
hash is assigned from a list of keys and values, so to key values by
something of their own, give each one's key and value from a stage:

```perl
my %by_title = Ekorn::Pipeline->new(sub { ($_->{title}, $_) })->(@tracks);
```

A sink that stops the pull early is told `done`: it decided the run
had enough. The source and the stages before it are told `stopped`.

```perl
say Ekorn::Pipeline->new(count_items)->(1 .. 10);                          # 10
say Ekorn::Pipeline->new(keep_first)->iterator(counter(1, 1))->();  # 1, then stops
```

## Operators: Ekorn::Pipeline::Operators

```perl
use Ekorn::Pipeline::Operators;
```

It puts `|`, `|=` and `@{}` in force for Ekorn's sources, stages,
gathers and chains, for the rest of the scope it's used in; `no
Ekorn::Pipeline::Operators` takes them out again. Written where
they're not in force, they croak: "Expected use
Ekorn::Pipeline::Operators in scope". They're a shorthand for the commonest shapes, not the
whole of Ekorn: a pipeline made with `new` can have stages after a
sink, give a list as a list, and, pulled with `iterator`, be a source
that gives a sink's result, none of which a chain can.

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
`Ekorn::Pipeline::Operators::drain` (see
[Delivering parts for Ekorn](#delivering-parts-for-ekorn)).

`|` binds more loosely than `.` and `+`, so put a chain inside a larger
expression in parentheses.

An operator gives one scalar, so a chain ending in a sink gives one
value: the result of a sink of one, such as `count_items`, or the
list of a sink of many, such as `keep_all`, as an array reference. Nothing can be chained after
a sink: a chain ending in one has already run, and gives its result.

```perl
my $n      = $source | count_items;                  # a number
my $titles = $source | keep_all;              # an array reference
my @titles = @{ $source | keep_all };         # a list
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
my @all   = @{$source};                                      # every value
my $first = $source | keep_first;                            # the first, reading only one
my $next  = Ekorn::Pipeline->new->iterator($source);
while (my ($value) = $next->()) { say $value }               # each, as it comes
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
deliver sources, sinks and stages that keep its protocols, and let your
users run them in Ekorn's pipelines, with Ekorn's parts and their own.
Don't subclass Ekorn's classes, or wrap its words.

### The protocols

A part of yours says what it can be by its methods. Each is called at
the start of a run, and returns closures sharing that run's state:

| Method | Makes it | Returns |
|---|---|---|
| `ekorn_source` | a source, given to `iterator` or starting a chain | its step, called with nothing for the next value, or an empty list at the end; optionally its end, told how the run ended; and optionally a context, anything its stages may want to know about this run |
| `ekorn_stage` | a stage with state for the run | its step, called with each value, returning a list; optionally its flush, called when its input runs out; and optionally its end |
| `ekorn_sink_one`, `ekorn_sink_many` | a sink, giving one value or a list | its step, called with each value, its return ignored; its flush, giving the result; and optionally its end |

The methods are named for Ekorn, so an object of yours with a method
of its own such as `as_list` is never taken for a part. One object can
offer `ekorn_source` and one of the others, as a table can
be read from and written to. A plain code reference is a source or a
stage, wherever it's given, with no end. None of these needs your
package to load Ekorn.

```perl
package My::Rows;

sub ekorn_source ($self) {
    my $sth = $self->{sth};
    $sth->execute;                                  # this run's
    return (
        sub ()     { $sth->fetchrow_arrayref // () },
        sub ($how) { $sth->finish },
        {columns => $sth->{NAME}},                  # what stages may ask
    );
}
```

### Stages that ask about their run

A stage that needs to know about the values' source asks
`Ekorn::Pipeline::run_context()` for the context its run's source
gave. Each run has its own, and an iterator used as a source passes on
the context of the run inside it. A pushed run has none.

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
runs them with `new`, as any user of Ekorn does:

```perl
sub each_row ($rows, @stages) {
    return Ekorn::Pipeline->new(@stages)->iterator($rows);
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
- a set-up that doesn't return what its role needs: a step, and the
  flush, end or context it may have;
- an object offering more than one of `ekorn_stage`, `ekorn_sink_one` and
  `ekorn_sink_many`;
- an end that died while the run was already dying (a warning,
  naming the end);
- `|` started with something that isn't one of the types, or given
  on its right what can't go where a stage goes.

## Exports (revised rows)

| Module | By default | On request | Tags |
|---|---|---|---|
| `Ekorn::Pipeline` | nothing | `is_stage`, `is_sink` | |
| `Ekorn::Pipeline::Factories` | nothing | `pipeline`, `stage`, `gather`, `source`, `sink_one`, `sink_many` | `:all` |
| `Ekorn::Pipeline::Sources` | nothing | each source | `:all` |
| `Ekorn::Pipeline::Sinks` | nothing | each sink | `:all` |
| `Ekorn::Pipeline::Operators` | nothing: loading it is enough | | |
| `Ekorn::Pipeline::Sugar` | its import list | | |
