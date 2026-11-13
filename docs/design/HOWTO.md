# Ekorn::Pipeline how-to: draft recipes

**Status:** a draft for review, roadmap 2026-0022, with
[DESIGN.md](DESIGN.md) and [REFERENCE.md](REFERENCE.md). These are the
recipes `docs/HOWTO.md` would gain or change, written as they'd read
there. The code in them is the design's; IMPLEMENTATION.md says what
the prototype on `pipeline-experimental` runs, and where it differs.

The examples follow on from the how-to's first section, The examples'
data: `@tracks`, six tracks with an artist, a title and a number of
plays, and `tracks(@stages)`, which runs them through the stages its
caller gives.

Where the recipes go:

- **Writing a function that takes stages** changes two recipes, "Take
  stages after values that may be code references" and "Name a
  pipeline you use often", as `pipeline` comes from Factories.
- **A new part, Sources: reading from anything,** after Pulling values
  one at a time.
- **A new part, Sinks: a result from many values,** after Gathering
  values.
- **A new part, Chaining with |,** after Sinks.
- **Writing stages for others** gains "Deliver sources, sinks and stages for Ekorn".

## Writing a function that takes stages (changed recipes)

### Take stages after values that may be code references

If the function's values can be code references, such as callbacks,
`is_stage` can't tell them from stages. Take a pipeline given last as
the stages instead: a pipeline is never one of the values. The caller
makes one with `pipeline`, from Ekorn::Pipeline::Factories:

```perl
use Ekorn::Pipeline::Factories qw(pipeline);

# What each callback returns, through the stages given last, as a pipeline.
sub call_all (@callbacks) {
    my $stages = @callbacks && $callbacks[-1] isa 'Ekorn::Pipeline' ? pop @callbacks : pipeline();
    return $stages->(map { $_->() } @callbacks);
}

my @plays = map { my $track = $_; sub { $track->{plays} } } @tracks;
say join ', ', call_all(@plays, pipeline(sub { $_ > 6000 ? $_ : () }, take(2)));    # 9100, 6100
```

### Name a pipeline you use often

A pipeline used in several places can be named, and found by its name
with `pipeline`, which takes a name wherever it takes a stage:

```perl
use Ekorn::Pipeline::Factories qw(pipeline);

Ekorn::Pipeline->named(hit   => sub { $_->{plays} >= 6000 ? $_ : () });
Ekorn::Pipeline->named(title => sub { $_->{title} });
Ekorn::Pipeline->named(hit_titles => 'hit', 'title');

say join ', ', tracks(pipeline('hit_titles', take(2)));    # Dancing Queen, Girls & Boys
```

Or name them as the program compiles, and get a function of each name:

```perl
use Ekorn::Pipeline::Sugar
    pipeline => {
        hit        => [sub { $_->{plays} >= 6000 ? $_ : () }],
        hit_titles => ['hit', sub { $_->{title} }],
    };

say join ', ', hit_titles(@tracks);    # Dancing Queen, Girls & Boys, Sunshine of Your Love
```

A name is kept in the package that defined it, so modules don't clash.
A name can't be defined twice, so define each once, as the program
starts.

## Sources: reading from anything (new)

### Read a file, and close it however the run ends

`from_file` gives a file's lines, or its records as `$/` divides them,
and closes the file when the run ends, however it ends: when the lines
run out, when a stage stops it, or when a stage dies.

```perl
use Ekorn::Pipeline::Sources qw(from_file);

my $next = Ekorn::Pipeline->new(take(2))->iterator(from_file('setlist.txt'));
while (my($line) = $next->()) { say $line }
# the first two lines; the file is closed once take(2) stops
```

Compare `from_fh($fh)`, which reads a filehandle you opened, and leaves
it to you to close.

### Write a source of your own

A source is called with nothing, and gives the next value, or an empty
list when there are no more. Any code reference will do. For one with
something to open and close, use `source`: its block runs at the start
of each run, and returns the step and the end, closures sharing what
it opened:

```perl
use Ekorn::Pipeline::Factories qw(source);

sub csv_rows ($path) {
    return source {
        open my $fh, '<', $path or die "Can't read $path: $!\n";
        return (
            sub ()     { my $line = readline $fh; defined $line ? [split m( , )x, $line =~ s( \n \z )()xr] : () },
            sub ($how) { close $fh },
        );
    };
}
```

Two iterators each open the file for themselves, and each closes it,
once, however its run ends.

### Don't leave a file open when you stop reading early

An iterator you stop reading before it's finished ends its run when
you're done with it, as Perl lets it go:

```perl
{
    my $next = Ekorn::Pipeline->new(sub { uc })->iterator(from_file('setlist.txt'));
    my($first) = $next->();
}
# $next has gone, so the file is closed
```


## Sinks: a result from many values (new)

### Count, total or join, in one result

A sink takes every value and turns them into its result, here a
single value. Given last, its result is what the run gives:

```perl
use Ekorn::Pipeline::Sinks qw(count_items fold joined);

say tracks(sub { $_->{artist} eq 'Blur' ? $_ : () }, count_items);              # 3
say tracks(sub { $_->{plays} }, fold(0, sub { $_[0] + $_[1] }));          # 36800
say tracks(sub { $_->{artist} }, joined(', '));                           # Abba, Abba, Blur, Blur, Blur, Cream
```


### Stop reading once you have your answer

Some sinks stop the pull as soon as they know the result, so a source
reading a file or a database reads no further:

```perl
use Ekorn::Pipeline::Sources qw(from_arrayref);
use Ekorn::Pipeline::Sinks   qw(keep_first);

my $first_hit = Ekorn::Pipeline->new(sub { $_->{plays} > 6000 ? $_ : () }, keep_first)
    ->iterator(from_arrayref(\@tracks))->();
say $first_hit->{title};    # Dancing Queen: the rest aren't read
```

The source is told `stopped`. Had it been `from_file`, it would have
closed its file there and then.

### Write a sink of your own, and act on how the run ended

A sink giving one value, as most do, is written with `sink_one`; one
written with `sink_many` gives a list, and in scalar context, or at the
end of a `|` chain, gives it as an array reference. The block runs at the start of each run, and returns
the step,
called with each value; the result, called when the values run out;
and, if it needs one, the end, told how the run ended once it has.
One that should take effect only if the whole run went through checks
how, such as writing to a temporary file and moving it into place only
when the run is `done`, so a run that dies, even after the sink, leaves
the old file:

```perl
use Ekorn::Pipeline::Factories qw(sink_one);
use File::Temp qw(tempfile);

sub save_to ($path) {
    return sink_one {
        my($fh, $tmp) = tempfile();
        my $n = 0;
        return (
            sub ($line) { say {$fh} $line; $n++ },
            sub ()      { $n },
            sub ($how) {
                close $fh;
                $how eq 'done' ? rename $tmp, $path : unlink $tmp;
            },
        );
    };
}

say tracks(sub { $_->{title} }, save_to('titles.txt'));    # 6
# titles.txt is replaced only if every title was written
```

### Copy a file, with nothing in between

A source and a sink can be joined directly. Here the pipeline is only
a sink, `to_file`, and the iterator runs it, reading from `from_file`:

```perl
use Ekorn::Pipeline::Sources qw(from_file);
use Ekorn::Pipeline::Sinks   qw(to_file);

my($n) = Ekorn::Pipeline->new(to_file('setlist.bak'))->iterator(from_file('setlist.txt'))->();
say $n;    # how many lines were copied
```

`from_file` takes `$/` from each line and `to_file` puts it back, so
the copy is line for line. Both files are closed however the run ends,
even if `setlist.bak` can't be written.

### Feed one pipeline's result to another

A pipeline that reads from a source and ends in a sink, pulled, is
itself a source: it gives the sink's result. Another pipeline can read
from it:

```perl
use Ekorn::Pipeline::Sources qw(from_file);
use Ekorn::Pipeline::Sinks   qw(keep_all);

my $lines = Ekorn::Pipeline->new(sub { uc }, keep_all)->iterator(from_file('setlist.txt'));
my $next  = Ekorn::Pipeline->new(take(2))->iterator($lines);
while (my($line) = $next->()) { say $line }
# the first two lines, in capitals
```

`keep_all` holds back every line until there are no more, so the first
pull reads the whole file, and closes it, before the first line comes
out. Without `keep_all`, `take(2)` would read only two lines. Use a
sink this way when the reading must finish before what follows starts.

## Chaining with | (new)

### Join a source, stages and a sink with |

With `use Ekorn::Pipeline::Operators` in scope, the types join with
`|`:

```perl
use Ekorn::Pipeline::Operators;
use Ekorn::Pipeline::Factories qw(stage);
use Ekorn::Pipeline::Sources   qw(from_arrayref);
use Ekorn::Pipeline::Sinks     qw(keep_all count_items);

my $blur = stage { $_->{artist} eq 'Blur' ? $_ : () };

say from_arrayref(\@tracks) | $blur | count_items;                                   # 3
my $titles = from_arrayref(\@tracks) | $blur | stage { $_->{title} } | keep_all;
say join ', ', @$titles;                                                       # Girls & Boys, Parklife, Country House
```

A chain ends in one value, as `|` gives one: `count_items`'s number, or, from
a sink giving a list, such as `keep_all`, the list as an array
reference. So `my @titles = ... | keep_all` would get one element,
the reference; write `my @titles = @{ ... | keep_all }`.

A source and a sink join directly too, so a file is copied with
`my $copied = from_file('setlist.txt') | to_file('setlist.bak')`. Keep
the result, even if you don't need it: written as a statement of its
own, the chain still runs, but Perl warns of a useless `|` in void
context. A chain ending in a sink gives its result at once, not a
source: to feed one pipeline's result to another, use `iterator`, as
above.

**Start a chain with a source, or a stage made with `stage`,** or a
ready-made one. `sub { ... } | sub { ... }` isn't an error in Perl:
it's a bitwise OR of two addresses, and gives a meaningless number.
And `|` binds more loosely than `.`, so put a chain in parentheses
inside a string: `say 'Blur: ' . (from_arrayref(\@tracks) | $blur |
count_items)`.

### Get every value, or only what you need

End a chain in the sink that says what you want, and it reads only
what that needs:

```perl
use Ekorn::Pipeline::Sinks        qw(keep_all count_items keep_first);
use Ekorn::Pipeline::Stages::Flow qw(take);

my $hits = from_arrayref(\@tracks) | stage { $_->{plays} >= 6000 ? $_->{title} : () };

my $all = $hits | keep_all;           # an array reference
say join ', ', @$all;                  # Dancing Queen, Girls & Boys, Sunshine of Your Love
my @all = @{ $hits | keep_all };      # a list
say scalar @all;                       # 3
say $hits | keep_first;                # Dancing Queen
say $hits | count_items;                     # 3
say join ', ', @{ $hits | take(2) | keep_all };    # Dancing Queen, Girls & Boys

my @mine = ('Waterloo');
push @mine, @{ $hits | keep_all };
say join ', ', @mine;                  # Waterloo, Dancing Queen, Girls & Boys, Sunshine of Your Love
```

`$hits` is a source, so each chain from it is a run of its own, from
the first track. `keep_first` stops reading at the first hit, and
`take(2)` at the second.

To take each value as it comes, pull them from an iterator:

```perl
my $next = Ekorn::Pipeline->new->iterator($hits);
while (my ($title) = $next->()) {
    say "Now playing: $title";         # Now playing: Dancing Queen, and the rest, one at a time
}
```

**`@{ $source }` reads a source through, with no sink.** It looks like
a dereference, but a source holds no array: Operators gives sources
an `@{}` that runs the source, collects every value into a new array,
and hands Perl a reference to it to dereference:

```perl
my @titles = @{$hits};                 # every value, read through, with no sink
say join ', ', @titles;                # Dancing Queen, Girls & Boys, Sunshine of Your Love
```

Each use reads the source again, from its start to its end, however
little you take: `$hits->[0]` reads every track to give the first, and
`scalar @$hits` keeps every title to count them. `for (@$hits)` reads
them all before the loop starts. Use `keep_first`, `count_items`, `take` or
an iterator instead, as above. `@{}` is only for sources; in
`@{ $hits | keep_all }` the braces are Perl's own, dereferencing the
array reference `keep_all` gave.

## Writing stages for others (new recipe)

### Deliver sources, sinks and stages for Ekorn

If your package hands out values, as DBIx::Squirrel hands out rows,
use Ekorn as it is: give your users the parts only you can make, and
let them run them in Ekorn's pipelines, with Ekorn's parts and their
own. Your parts say what they can be by their methods, and needn't
load Ekorn to say it:

1. **`ekorn_source`, for what you read.** It starts a run, and returns
   its step, its end, closing what it opened, and a context, what your
   stages may need to know about the run:

   ```perl
   sub ekorn_source ($self) {
       my $sth = $self->{sth};
       $sth->execute;
       return (sub () { $sth->fetchrow_arrayref // () }, sub ($how) { $sth->finish },
           {columns => $sth->{NAME}});
   }
   ```

2. **`ekorn_sink_one` or `ekorn_sink_many`, for what you write.** A sink's end is
   told how the run ended, so it can commit only when the run is
   `done`.
3. **Stages for what only you know,** asking
   `Ekorn::Pipeline::run_context()` for what the source gave.
4. **Functions that take stages,** if you like, finding them with
   `is_stage` and running them with `Ekorn::Pipeline->new(@stages)`.
5. **`|` for your sources,** by overloading it with
   `Ekorn::Pipeline::Operators::chain`, and `@{}` with `drain`.
6. **Ekorn's `@INTERNAL` in your `@CARP_NOT`,** so mistakes are
   reported at your users' lines.

Don't subclass Ekorn's classes, or make words of your own for its
types: your users take those from Ekorn, and compose your parts with
them:

```perl
my $next = Ekorn::Pipeline->new(pluck('name'), take(5))->iterator($table);
```
