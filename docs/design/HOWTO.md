# Ekorn::Pipeline how-to: draft recipes

**Status:** a draft for review, roadmap 2026-0022, with
[DESIGN.md](DESIGN.md) and [REFERENCE.md](REFERENCE.md). These are the
recipes `docs/HOWTO.md` would gain or change, written as they'd read
there. None of the code in them runs yet. Notes in brackets, such as
**[Q8]**, name the open question a recipe depends on; they go before
anything is merged.

The examples follow on from the how-to's first section, The examples'
data: `@tracks`, six tracks with an artist, a title and a number of
plays, and `tracks(@stages)`, which runs them through the stages its
caller gives.

Where the recipes go:

- **Writing a function that takes stages** changes two recipes, "Take
  stages after values that may be code references" and "Name a
  pipeline you use often", as `pipeline` moves to Factories.
- **A new part, Sources: reading from anything,** after Pulling values
  one at a time.
- **A new part, Sinks: one result from many values,** after Gathering
  values.
- **Gathering values** gains a recipe for the new form of `gather`.
- **A new part, Chaining with |,** after Sinks.
- **Writing stages for others** gains "Build a distribution on Ekorn".

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

`file_lines` gives a file's lines, and closes the file when the run
ends, however it ends: when the lines run out, when a stage stops it,
or when a stage dies.

```perl
use Ekorn::Pipeline::Sources qw(file_lines);

my $next = Ekorn::Pipeline->new(take(2))->iterator(file_lines('setlist.txt'));
while (my($line) = $next->()) { say $line }
# the first two lines; the file is closed once take(2) stops
```

Compare `lines($fh)`, which reads a filehandle you opened, and leaves
it to you to close.

### Write a source of your own

A source is called with nothing, and gives the next value, or an empty
list when there are no more. For one with something to open and close,
give `source` a set-up, a `step` and an `end`:

```perl
use Ekorn::Pipeline::Factories qw(:blocks);

sub csv_rows ($path) {
    return source { open my $fh, '<', $path or die "Can't read $path: $!\n"; $fh }
           step   { my $line = readline $_; defined $line ? [split m( , )x, $line =~ s( \n \z )()xr] : () }
           end    { close $_ };
}
```

The set-up runs at the start of each run, so two iterators each open
the file for themselves. The end runs once, however the run ends.

### Don't leave a file open when you stop reading early

An iterator you stop reading before it's finished ends its run when
you're done with it, as Perl lets it go:

```perl
{
    my $next = Ekorn::Pipeline->new(sub { uc })->iterator(file_lines('setlist.txt'));
    my($first) = $next->();
}
# $next has gone, so the file is closed
```

**[Q7]**

## Gathering values (new recipe)

### Keep state for a run, and let out what's left at the end

`gather`'s new form has a set-up, a step and an end. What the set-up
returns is the run's state; the step can drop each value, pass it on,
or let several out; the end lets out what's left, once the values run
out:

```perl
use Ekorn::Pipeline::Factories qw(:blocks);

my $pairs = gather { [] }
            step   { push @{ $_[0] }, $_->{title}; @{ $_[0] } == 2 ? [splice @{ $_[0] }] : () }
            end    { @{ $_[0] } ? [@{ $_[0] }] : () };

say join ' | ', map { "@$_" } tracks($pairs);
# Dancing Queen Knowing Me, Knowing You | Girls & Boys Parklife | Country House Sunshine of Your Love
```

**[Q23]** If a stage after it stops the run, the end isn't told `done`,
so what it returns is dropped: a half-made pair isn't let out after a
stop.

## Sinks: one result from many values (new)

### Count, total or collect, in one result

A sink goes last, and turns every value into one result:

```perl
use Ekorn::Pipeline::Sinks qw(count fold joined);

say tracks(sub { $_->{artist} eq 'Blur' ? $_ : () }, count);              # 3
say tracks(sub { $_->{plays} }, fold(0, sub { $_[0] + $_[1] }));          # 36800
say tracks(sub { $_->{artist} }, joined(', '));                           # Abba, Abba, Blur, ...
```

**[Q8]**

### Stop reading once you have your answer

Some sinks stop the pull as soon as they know the result, so a source
reading a file or a database reads no further:

```perl
use Ekorn::Pipeline::Sources qw(from_array);
use Ekorn::Pipeline::Sinks   qw(first_value);

my $first_hit = Ekorn::Pipeline->new(sub { $_->{plays} > 6000 ? $_ : () }, first_value)
    ->iterator(from_array(\@tracks))->();
say $first_hit->{title};    # Dancing Queen: the rest aren't read
```

The source is told `stopped`. Had it been `file_lines`, it would have
closed its file there and then.

### Write a sink of your own, and act on how the run ended

A sink's end is told how the run ended, as its second argument. Most
ignore it. One that should only take effect if every value went
through checks it, such as writing to a temporary file and moving it
into place only when the run is `done`:

```perl
use Ekorn::Pipeline::Factories qw(:blocks);
use File::Temp qw(tempfile);

sub save_to ($path) {
    return sink { my($fh, $tmp) = tempfile(); {fh => $fh, tmp => $tmp} }
           step { say { $_[0]{fh} } $_ }
           end  {
               close $_[0]{fh};
               $_[1] eq 'done' ? rename($_[0]{tmp}, $path) : unlink $_[0]{tmp};
           };
}

tracks(sub { $_->{title} }, save_to('titles.txt'));
# titles.txt is replaced only if every title was written
```

## Chaining with | (new)

### Join a source, stages and a sink with |

With Ekorn::Pipeline::Operators loaded, the types join with `|`:

```perl
use Ekorn::Pipeline::Operators;
use Ekorn::Pipeline::Factories qw(:blocks);
use Ekorn::Pipeline::Sources   qw(from_array);
use Ekorn::Pipeline::Sinks     qw(count);

my $blur = stage { $_->{artist} eq 'Blur' ? $_ : () };

say from_array(\@tracks) | $blur | count;                      # 3
my @titles = @{ from_array(\@tracks) | $blur | stage { $_->{title} } };
```

**Write every stage in a chain with `stage`,** or use a ready-made
one. `sub { ... } | sub { ... }` isn't an error in Perl: it's a
bitwise OR of two addresses, and gives a meaningless number.

## Writing stages for others (new recipe)

### Build a distribution on Ekorn

If your distribution gives its users pipelines of its own, as
DBIx::Squirrel does:

1. **Subclass Ekorn::Pipeline** where you change how your pipelines
   behave. Your class inherits `new`, `pipeline_in` and `named`, each
   making or naming your class.
2. **Give your users words of their own,** in a module of yours, each
   one line:

   ```perl
   sub pipeline (@stages) { My::Pipeline->pipeline_in(scalar caller, @stages) }
   ```

   and re-export Ekorn's words for the types you don't subclass.
3. **If you use Ekorn::Pipeline::Pipes,** override `pipeline_class`,
   so `pipe` and `tap` make your class.
4. **Put Ekorn's `@INTERNAL` in your `@CARP_NOT`,** so mistakes are
   reported at your users' lines.

Names your users define through your class are yours: their
`pipeline` finds yours and Ekorn's, and Ekorn's own never finds yours.
