# Ekorn::Pipeline how-to: draft recipes

**Status:** a draft for review, roadmap 2026-0022, with
[DESIGN.md](DESIGN.md) and [REFERENCE.md](REFERENCE.md). These are the
recipes `docs/HOWTO.md` would gain or change, written as they'd read
there. None of the code in them runs yet. Notes in brackets, such as
**[Q8]**, name the open question in the design a recipe depends on;
they go before anything is merged.

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

**[Q7]**

## Sinks: a result from many values (new)

### Count, total or join, in one result

A sink takes every value and turns them into its result, here a
single value. Given last, its result is what the run gives:

```perl
use Ekorn::Pipeline::Sinks qw(count fold joined);

say tracks(sub { $_->{artist} eq 'Blur' ? $_ : () }, count);              # 3
say tracks(sub { $_->{plays} }, fold(0, sub { $_[0] + $_[1] }));          # 36800
say tracks(sub { $_->{artist} }, joined(', '));                           # Abba, Abba, Blur, Blur, Blur, Cream
```

**[Q8]**

### Stop reading once you have your answer

Some sinks stop the pull as soon as they know the result, so a source
reading a file or a database reads no further:

```perl
use Ekorn::Pipeline::Sources qw(from_arrayref);
use Ekorn::Pipeline::Sinks   qw(first_value);

my $first_hit = Ekorn::Pipeline->new(sub { $_->{plays} > 6000 ? $_ : () }, first_value)
    ->iterator(from_arrayref(\@tracks))->();
say $first_hit->{title};    # Dancing Queen: the rest aren't read
```

The source is told `stopped`. Had it been `from_file`, it would have
closed its file there and then.

### Write a sink of your own, and act on how the run ended

`sink`'s block runs at the start of each run, and returns the step,
called with each value, and the end, told how the run ended. Most ends
ignore how. One that should take effect only if every value went
through checks it, such as writing to a temporary file and moving it
into place only when the run is `done`:

```perl
use Ekorn::Pipeline::Factories qw(sink);
use File::Temp qw(tempfile);

sub save_to ($path) {
    return sink {
        my($fh, $tmp) = tempfile();
        my $n = 0;
        return (
            sub ($line) { say {$fh} $line; $n++; return },
            sub ($how) {
                close $fh;
                if ($how eq 'done') { rename $tmp, $path; return $n }
                unlink $tmp;
                return;
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
use Ekorn::Pipeline::Sinks   qw(to_array);

my $lines = Ekorn::Pipeline->new(sub { uc }, to_array)->iterator(from_file('setlist.txt'));
my $next  = Ekorn::Pipeline->new(take(2))->iterator($lines);
while (my($line) = $next->()) { say $line }
# the first two lines, in capitals
```

`to_array` holds back every line until there are no more, so the first
pull reads the whole file, and closes it, before the first line comes
out. Without `to_array`, `take(2)` would read only two lines. Use a
sink this way when the reading must finish before what follows starts.

## Chaining with | (new)

### Join a source, stages and a sink with |

With Ekorn::Pipeline::Operators loaded, the types join with `|`:

```perl
use Ekorn::Pipeline::Operators;
use Ekorn::Pipeline::Factories qw(stage);
use Ekorn::Pipeline::Sources   qw(from_arrayref);
use Ekorn::Pipeline::Sinks     qw(count);

my $blur = stage { $_->{artist} eq 'Blur' ? $_ : () };

say from_arrayref(\@tracks) | $blur | count;                                  # 3
my @titles = @{ from_arrayref(\@tracks) | $blur | stage { $_->{title} } };    # Girls & Boys, Parklife, Country House
```

A source and a sink join directly too, so a file is copied with
`from_file('setlist.txt') | to_file('setlist.bak')`. A chain ending in
a sink gives its result at once, not a source: to feed one pipeline's
result to another, use `iterator`, as above.

**Write every stage in a chain with `stage`,** or use a ready-made
one. `sub { ... } | sub { ... }` isn't an error in Perl: it's a
bitwise OR of two addresses, and gives a meaningless number.

## Writing stages for others (new recipe)

### Deliver sources, sinks and stages for Ekorn

If your package hands out values, as DBIx::Squirrel hands out rows,
use Ekorn as it is: give your users the parts only you can make, and
let them run them in Ekorn's pipelines, with Ekorn's parts and their
own.

1. **A source for what you read,** made with `source` if it opens
   something, so it's closed however the run ends.
2. **A sink for what you write,** made with `sink`, committing only
   when the run is `done`.
3. **Stages for what only you know** about your values.
4. **Functions that take stages,** if you like, finding them with
   `is_stage` and running them with `Ekorn::Pipeline->new(@stages)`.
5. **Ekorn's `@INTERNAL` in your `@CARP_NOT`,** so mistakes are
   reported at your users' lines.

Don't subclass Ekorn's classes, or make words of your own for its
types: your users take those from Ekorn, and compose your parts with
them:

```perl
my $next = Ekorn::Pipeline->new(take(5))->iterator(rows($sth));
```
