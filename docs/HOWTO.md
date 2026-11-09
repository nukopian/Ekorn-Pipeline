# Ekorn::Pipeline how-to

<!-- stopwords: backtrace -->

Recipes for everyday work with Ekorn::Pipeline, one task at a time.
Each shows the shortest way to do the job. [The reference](REFERENCE.md)
says what every function and method does, in full.

The recipes are for all three kinds of user:

- **Callers** of a function that takes stages, who say what they want
  done with its values, beside the call.
- **Function authors,** who let a function take stages instead of
  options.
- **Stage authors,** who write stages for others to use. Notes marked
  **For stage authors** say what a recipe means for them, and
  [Writing stages for others](#writing-stages-for-others) is for them.

It needs Perl 5.36 or later.

## Contents

- [The examples' data](#the-examples-data)
- [Running values through stages](#running-values-through-stages)
- [Pulling values one at a time](#pulling-values-one-at-a-time)
- [Stopping early](#stopping-early)
- [Gathering values](#gathering-values)
- [Watching values go by](#watching-values-go-by)
- [Writing a function that takes stages](#writing-a-function-that-takes-stages)
- [Writing stages for others](#writing-stages-for-others)
- [Handling errors](#handling-errors)

## The examples' data

Every example below starts from these tracks, and from `tracks`, a
function that hands them out through stages from its caller. The
examples follow on from each other, so `@tracks` and `tracks` mean
these wherever they appear.

```perl
use v5.36;
use Ekorn::Pipeline;

my @tracks = (
    {artist => 'Abba',  title => 'Dancing Queen',           plays => 9100},
    {artist => 'Abba',  title => 'Knowing Me, Knowing You', plays => 4200},
    {artist => 'Blur',  title => 'Girls & Boys',            plays => 6100},
    {artist => 'Blur',  title => 'Parklife',                plays => 5800},
    {artist => 'Blur',  title => 'Country House',           plays => 3900},
    {artist => 'Cream', title => 'Sunshine of Your Love',   plays => 7700},
);

# The tracks, through whatever stages the caller gives.
sub tracks (@stages) {
    return Ekorn::Pipeline->new(@stages)->(@tracks);
}
```

## Running values through stages

### Run values through stages

`new` makes a pipeline from a list of stages, each a code reference.
Call the pipeline with values, and it returns what comes out of the
last stage:

```perl
my $titles = Ekorn::Pipeline->new(sub { $_->{title} });

my @titles = $titles->(@tracks);
say $titles[0];    # Dancing Queen
```

A pipeline can be called as often as you like, with different values
each time. Each call is a *run*.

### Change each value (map)

A stage that returns one value passes it on, in place of the value it
was given:

```perl
my @shouted = tracks(sub { uc $_->{title} });
say "@shouted[0, 1]";    # DANCING QUEEN KNOWING ME, KNOWING YOU
```

### Leave values out (filter)

A stage that returns an empty list drops the value, and the stages
after it never see it:

```perl
my @hits = tracks(
    sub { $_->{plays} >= 6000 ? $_ : () },
    sub { $_->{title} },
);
say join ', ', @hits;    # Dancing Queen, Girls & Boys, Sunshine of Your Love
```

A test on its own isn't a filter. `sub { $_->{plays} >= 6000 }` passes
on what the test returns, true or false, instead of the track. Return
the value, or nothing.

### Turn one value into several (flatMap)

A stage that returns several values passes each of them on, in order,
through the rest of the stages, before the next value starts:

```perl
my @words = tracks(
    sub { $_->{artist} eq 'Abba' ? $_ : () },
    sub { split ' ', $_->{title} },
    sub { lc },
);
say "@words";    # dancing queen knowing me, knowing you
```

### Name the value, or use `$_`

A stage is called with one value, both as its only argument and in
`$_`. Use whichever reads better: `$_` for a short stage, a signature
when the name helps.

```perl
my @with_it   = tracks(sub { $_->{title} });
my @with_name = tracks(sub ($track) { $track->{title} });
say "@with_it" eq "@with_name" ? 'the same' : 'different';    # the same
```

`$_` is local to each call of a stage. The caller's `$_` is left
alone, and a stage can call code that uses `$_` too.

> **For stage authors:** a stage is always called with exactly one
> argument, so a one-argument signature, `sub ($value)`, is safe. An
> [end function](#do-something-once-the-values-run-out) is called with
> none, so its signature is `sub ()`.

### Pass on `undef`, 0 or an empty string

Only an empty list drops a value. `undef`, 0 and the empty string are
ordinary values, and go on:

```perl
my @plays = Ekorn::Pipeline->new(sub { $_ || undef })->(3, 0, '', 5);
say scalar @plays;    # 4
```

### Change values without changing the caller's

The values a pipeline is called with are copied, so assigning to `$_`
changes the copy, not the caller's array. But a reference is copied as
a reference, so a stage that changes a hash it's given changes the
caller's hash. To leave the caller's data alone, return a new one:

```perl
my @doubled = tracks(sub { +{ %$_, plays => $_->{plays} * 2 } });
say "$doubled[0]{plays} $tracks[0]{plays}";    # 18200 9100
```

> **For stage authors:** a stage others use should never change the
> value it's given, unless that's the stage's documented job.

### Count the results

Called in scalar context, a pipeline returns how many values came out:

```perl
my $hits = tracks(sub { $_->{plays} >= 6000 ? $_ : () });
say $hits;    # 3
```

[`count_into`](#count-the-values-that-went-by) counts values at any
point in a pipeline, not only at its end.

## Pulling values one at a time

### Pull values from a source

`iterator` takes a *source*: a function that returns the next value,
or an empty list when there are no more. It returns a function that
hands out the results one per call, then an empty list once they're
done. The source is called only when a result is wanted:

```perl
my @queue = (3, 1, 2);
my $next = Ekorn::Pipeline->new(sub { $_ * 10 })
    ->iterator(sub { @queue ? shift @queue : () });

while (my($n) = $next->()) {
    say $n;    # 30, then 10, then 20
}
```

### Read the results in list context

Read an iterator in list context, as `my($n) = $next->()`, so that a
result of 0, `''` or `undef` isn't taken for the end. In scalar
context, `while (my $n = $next->())` would stop at the first 0:

```perl
my @counts = (2, 0, 1);
my $next = Ekorn::Pipeline->new->iterator(sub { @counts ? shift @counts : () });

my @seen;
while (my($n) = $next->()) { push @seen, $n }
say "@seen";    # 2 0 1
```

### Keep `undef` from ending a source

A source ends by returning an empty list, so a source that returns
`shift @queue // ()` ends at the first `undef` in the queue. Test
whether there's anything left instead:

```perl
my @queue = ('a', undef, 'b');
my $next = Ekorn::Pipeline->new(sub { $_ // 'none' })
    ->iterator(sub { @queue ? shift @queue : () });

my @seen;
while (my($x) = $next->()) { push @seen, $x }
say "@seen";    # a none b
```

### Read a file a line at a time

A filehandle makes a source. Read it in scalar context, so that each
call reads one line:

```perl
my $log = <<~'END';
    INFO  started
    ERROR disk full
    INFO  retrying
    ERROR disk still full
    END
open my $fh, '<', \$log or die "Can't read the log: $!\n";

my $errors = Ekorn::Pipeline->new(sub { m( \A ERROR \s+ (.*) )x ? $1 : () })
    ->iterator(sub { scalar(<$fh>) // () });

while (my($message) = $errors->()) {
    say $message;    # disk full, then disk still full
}
```

Without `scalar`, `<$fh>` would read every line on its first call.

### Fetch values a page at a time

A source can return several values from one call, such as a page of
results from a service. They're all handed out before the source is
called again:

```perl
my @pages = ([qw(a b c)], [qw(d e)]);
my $calls = 0;
my $next = Ekorn::Pipeline->new(sub { uc })
    ->iterator(sub { $calls++; @pages ? @{ shift @pages } : () });

my($first) = $next->();
say "$first after $calls call";    # A after 1 call
```

### Know when an iterator is done

Once an iterator has handed out its last result, it returns an empty
list on every call, and doesn't call its source again. To start again,
make a new iterator; each is a run of its own.

The same goes once a stage has died. The call that asked for the
result dies, and the iterator has ended, so catching the error and
reading on gets nothing more. To skip a bad value, catch the error
inside the stage, as in
[Catch errors in a stage, but not a stop](#catch-errors-in-a-stage-but-not-a-stop).

## Stopping early

### Take the first few

`take` passes on the first few values, then stops the pipeline. With
an iterator, the source isn't called again, so nothing more is read
than is wanted:

```perl
use Ekorn::Pipeline::Stages::Flow;    # take and drop

my $read = 0;
my $next = Ekorn::Pipeline->new(take(2))
    ->iterator(sub { $read < @tracks ? $tracks[$read++] : () });

my @two;
while (my($track) = $next->()) { push @two, $track->{title} }
say join ', ', @two;          # Dancing Queen, Knowing Me, Knowing You
say "read $read of 6";        # read 2 of 6
```

### Page through values

`drop` leaves out the first few values and passes on the rest. With
`take`, it gives a page:

```perl
my @page2 = tracks(drop(2), take(2), sub { $_->{title} });
say join ', ', @page2;    # Girls & Boys, Parklife
```

Stages run in the order they're given, so a filter before `drop` and
`take` pages through what the filter passes on.

### Stop at the first match

`Stop` ends the pipeline from inside a stage. The values already out
are kept, and any values given to `Stop` go on through the rest of the
stages, as the stage's last:

```perl
use Ekorn::Pipeline::Stop;

my($blur) = tracks(sub { $_->{artist} eq 'Blur' ? Stop($_) : () });
say $blur->{title};    # Girls & Boys
```

`Stop()`, with nothing, ends the pipeline without passing anything on.
To stop without importing `Stop`, call
`Ekorn::Pipeline::Stop->throw`, which takes values in the same way.

### Take values while a test holds

`take_while` passes on values while its block returns true for them.
It stops the pipeline at the first value the block returns false for,
and doesn't pass that value on:

```perl
use Ekorn::Pipeline::Stages::Flow qw(:DEFAULT take_while drop_while);

my $mail = <<~'END';
    From: abba@example.com
    Subject: Waterloo

    My, my, at Waterloo Napoleon did surrender
    END
open my $fh, '<', \$mail or die "Can't read the mail: $!\n";

my $headers = Ekorn::Pipeline->new(take_while { m( \S )x }, sub { s( \n \z )()xr })
    ->iterator(sub { scalar(<$fh>) // () });

my @headers;
while (my($line) = $headers->()) { push @headers, $line }
say join ' | ', @headers;    # From: abba@example.com | Subject: Waterloo
```

### Skip values while a test holds

`drop_while` leaves out values while its block returns true for them,
then passes on the rest, starting with the first it returns false
for:

```perl
my @lines = ('# tracks', '# by plays', 'Dancing Queen', '# not a comment now');
my @body = Ekorn::Pipeline->new(drop_while { m( \A \# )x })->(@lines);
say join ' | ', @body;    # Dancing Queen | # not a comment now
```

### Catch errors in a stage, but not a stop

A stop is an exception, so a stage that catches errors itself, with
`eval` or `try`, would catch a stop too. Throw it again:

```perl
use experimental qw(try);

my @titles = tracks(sub ($track) {
    try {
        Stop() if $track->{artist} eq 'Blur';
        return uc $track->{title};
    }
    catch ($e) {
        die $e if $e isa 'Ekorn::Pipeline::Stop';
        return 'unknown';
    }
});
say join ', ', @titles;    # DANCING QUEEN, KNOWING ME, KNOWING YOU
```

Test it with `isa`, so that a stop of a subclass is thrown again too.
The same goes for stops from canned stages, such as `take`'s, when a
stage that catches errors runs a pipeline of its own.

> **For stage authors:** a stage that catches errors must always throw
> a stop again. Otherwise it swallows the stops of the stages it runs,
> and the pipeline carries on when it should have ended.

## Gathering values

### Hand out values in batches

`batch` passes values on in batches, each an array reference. The last
batch, which may be shorter, goes on once the values run out:

```perl
use Ekorn::Pipeline::Stages::Batch;    # batch and collect

my @batches = tracks(sub { $_->{title} }, batch(4));
say scalar @{ $batches[0] };    # 4
say "@{ $batches[1] }";         # Country House Sunshine of Your Love
```

With an iterator, `batch` holds no more than one batch. So you can
write a large file to a database in batches of 500 without reading the
whole file first.

### Make one value from every value

`collect` holds every value. Once they run out, it passes on an array
reference of them, or what its block makes of them:

```perl
use List::Util qw(sum0);

my($total) = tracks(sub { $_->{plays} }, collect { sum0 @_ });
say $total;    # 36800

my($all) = tracks(sub { $_->{artist} eq 'Cream' ? $_->{title} : () }, collect);
say "@$all";    # Sunshine of Your Love
```

`collect` gives a result even when there are no values: an empty
array, or what its block makes of none. Unlike `batch`, it holds every
value until the end, so the whole result is in memory at once.

### Keep count, starting afresh on each run

A stage is a closure, so it can keep state. But a plain closure keeps
its state from one run to the next:

```perl
my $count = 0;
my $plain = Ekorn::Pipeline->new(sub { ++$count . ". $_" });
$plain->('a');
my($second_run) = $plain->('a');
say $second_run;    # 2. a
```

Make the stage with `gather` instead. Its block is called at the start
of each run and returns the stage, so whatever the block declares is
fresh each time:

```perl
use Ekorn::Pipeline::Gather;

sub numbered () {
    return gather {
        my $n = 0;    # this run's
        return sub ($value) { ++$n . ". $value" };
    };
}

my $p = Ekorn::Pipeline->new(numbered());
$p->('a');
my($again) = $p->('a');
say $again;    # 1. a
```

> **For stage authors:** put anything a stage keeps, even a count, in
> a `gather` block. Otherwise a stage given to several pipelines, or
> run by two iterators, carries what it kept from one into the next.

### Do something once the values run out

A `gather` block can return a second function, an *end function*,
called once the values run out. What it returns goes on through the
rest of the stages, just like what a stage returns:

```perl
sub titles_by_artist () {
    return gather {
        my %titles;
        my $stage = sub ($track) {
            push @{ $titles{ $track->{artist} } }, $track->{title};
            return;    # hold every track; pass nothing on yet
        };
        my $end = sub () {
            return map { "$_: " . join(', ', @{ $titles{$_} }) } sort keys %titles;
        };
        return ($stage, $end);
    };
}

say for tracks(titles_by_artist());
# Abba: Dancing Queen, Knowing Me, Knowing You
# Blur: Girls & Boys, Parklife, Country House
# Cream: Sunshine of Your Love
```

That's how `batch` and `collect` are made.

> **For stage authors:** an end function is called even when no
> values went by, so it can give an empty result, such as `[]`, or
> nothing at all. It's called with no arguments, and with `$_`
> undefined. The ends are called in order, first stage first. What one
> returns goes through the stages after it before the next end is
> called, so a `collect` after a `batch` gets the last batch too.

### Tell values from an end apart

While the values going through the stages come from an end function,
rather than from the source, `Ekorn::Pipeline::ending()` is true:

```perl
my @lines = tracks(
    sub { $_->{plays} },
    collect { sum0 @_ },
    sub { Ekorn::Pipeline::ending() ? "total $_" : $_ },
);
say "@lines";    # total 36800
```

It's for code that tells its stages more about each value, such as
where it came from. A value from an end function has no such origin.

## Watching values go by

### Look at each value as it goes by

`peek` calls its block with each value, for its side effects, and
passes the value on, whatever the block returns:

```perl
use Ekorn::Pipeline::Stages::Taps;    # peek and count_into

my @log;
my @titles = tracks(peek { push @log, $_->{artist} }, sub { $_->{title} }, take(2));
say "@log";    # Abba Abba
```

A stage of your own run for its side effects has to return the value
it was given, as `peek` does, or the value is dropped.

### Count the values that went by

`count_into` counts values into a variable and passes them on. It sets
the variable to 0 at the start of each run, so after a run it holds
how many values went by, even if none did:

```perl
my($read, $kept);
my @hits = tracks(
    count_into(\$read),
    sub { $_->{plays} >= 6000 ? $_ : () },
    count_into(\$kept),
);
say "$kept of $read";    # 3 of 6
```

### Dump values while debugging

`dump_to` writes each value with Data::Dumper, keys sorted, to a
filehandle or to STDERR, and passes it on. It's for debugging, and
writes values in full, so take it out before the code goes live:

```perl
use Ekorn::Pipeline::Stages::Taps qw(:DEFAULT dump_to);

open my $out, '>', \my $dumped or die "Can't write the dump: $!\n";
tracks(take(1), dump_to($out));
print $dumped;
# {
#   'artist' => 'Abba',
#   'plays' => 9100,
#   'title' => 'Dancing Queen'
# }
```

## Writing a function that takes stages

### Take stages from your caller

A function that hands out values takes stages as its last arguments,
and runs what it would return through them. The caller says what they
want done with each value, beside the call:

```perl
sub tracks_by ($artist, @stages) {
    my @by = grep { $_->{artist} eq $artist } @tracks;
    return Ekorn::Pipeline->new(@stages)->(@by);
}

say join ', ', tracks_by('Blur', sub { $_->{title} }, take(2));
# Girls & Boys, Parklife
```

A caller who wants nothing done passes no stages. A pipeline with no
stages returns its values unchanged, so there's nothing to
special-case.

### Make values only as they're wanted

If the function makes its values one at a time, from a file, a socket,
a database or a computation, give `iterator` a source and return the
iterator. Then a caller's stage that stops saves the work of making
the rest:

```perl
# Square numbers, for as long as the caller wants them.
sub squares (@stages) {
    my $n = 0;
    return Ekorn::Pipeline->new(@stages)->iterator(sub { ++$n * $n });
}

my $next = squares(sub { $_ % 2 ? $_ : () }, take(3));
my @odd;
while (my($square) = $next->()) { push @odd, $square }
say "@odd";    # 1 9 25
```

The source never runs out, so without a stage that stops, the caller
would loop for ever. That's fine for an iterator, which the caller
reads one value at a time. A function that returns a list needs a
source that ends.

### Replace an option with a stage

Every option that filters, reshapes or limits what a function returns
is code its author has to write, test, document and maintain. A stage
already does it, in the caller's code:

```perl
# In place of tracks(min_plays => 6000, fields => ['title'], limit => 2):
my @top = tracks(sub { $_->{plays} >= 6000 ? $_->{title} : () }, take(2));
say join ', ', @top;    # Dancing Queen, Girls & Boys
```

Keep the arguments only the function can act on, such as which file to
read, or a filter a database can apply with an index. Let stages do
the rest.

### Do some of the work yourself, then the caller's

A function can put stages of its own before its caller's, so that
values reach the caller's stages in the shape it promises:

```perl
# Titles, through whatever stages the caller gives.
sub titles (@stages) {
    return Ekorn::Pipeline->new(sub { $_->{title} }, @stages)->(@tracks);
}

say join ', ', titles(drop(4));    # Country House, Sunshine of Your Love
```

The function's own stages count when a failing stage is numbered, so
its documentation should say what the caller's first stage is given.

### Pass your caller's stages on

A function built on another function that takes stages can pass its
caller's stages on, after its own:

```perl
sub hits (@stages) {
    return tracks(sub { $_->{plays} >= 6000 ? $_ : () }, @stages);
}

say join ', ', hits(sub { $_->{artist} });    # Abba, Blur, Cream
```

### Report your callers' mistakes at their own lines

A stage that dies is reported at the line that ran its pipeline. For a
function that takes stages, that's a line inside the function. Put
Ekorn::Pipeline's packages in the module's `@CARP_NOT`, and errors are
reported at the caller's line instead, where the stage was written:

```perl
package My::Music {
    use Ekorn::Pipeline;

    # Report the errors of Ekorn::Pipeline at my callers' lines.
    our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

    sub tracks (@stages) {
        return Ekorn::Pipeline->new(@stages)->(@tracks);
    }
}

eval { My::Music::tracks(sub { die "Not today\n" }) };
print $@;
# Pipeline stage #1 failed at ... line ...:    (this line, not one in My::Music)
#     Not today
```

The same goes for a stage that isn't a code reference, and for a stage
that dies while the caller reads an iterator the function returned:
the line is the caller's.

### Name the stages you use often

Stages are code references, so a function can make one. A set of such
functions becomes a vocabulary, which grows in the callers' code, not
the author's:

```perl
sub by ($artist) { sub { $_->{artist} eq $artist ? $_ : () } }
sub value_of ($name) { sub { $_->{$name} } }

say join ', ', tracks(by('Abba'), value_of('title'));
# Dancing Queen, Knowing Me, Knowing You
```

The same stages work with every function that takes them, whoever
wrote it.

### Give a class `pipe` and `tap`

A class that inherits from Ekorn::Pipeline::Pipes has two methods that
run the object through stages. `pipe` returns what comes out. `tap`
returns the object, so a chain of method calls can carry on after it:

```perl
package Playlist {
    use parent 'Ekorn::Pipeline::Pipes';
    sub new ($class, @tracks) { bless {tracks => [@tracks]}, $class }
    sub tracks ($self) { @{ $self->{tracks} } }
    sub size ($self) { scalar $self->tracks }
}

my $list = Playlist->new(@tracks[0 .. 2]);
my @artists = $list->pipe(sub { $_->tracks }, sub { $_->{artist} });
say "@artists";    # Abba Abba Blur

say $list->tap(sub { warn "checking\n" if $_->size > 10; $_ })->size;    # 3
```

In scalar context, `pipe` returns the first value that comes out.

## Writing stages for others

Write a stage for others the way the canned stages are written, so it
works alongside them. [Writing stages](REFERENCE.md#writing-stages) in
the reference has the full list.

### Write a function that makes a stage

For a stage others will use, write a function that returns it, as
`take(10)` does. The function can take options, and check them once,
when it's called, not on each value:

```perl
package My::Stages::Words {
    use Ekorn::Pipeline::Errors qw(croakf);

    sub longer_than ($length) {
        croakf 'Expected a length of 0 or more, not %s', $length // 'undef'
            unless defined $length && $length =~ m( \A \d+ \z )xa;
        return sub ($word) { length $word > $length ? $word : () };
    }
}

say join ', ', tracks(sub { $_->{title} }, My::Stages::Words::longer_than(14));
# Knowing Me, Knowing You, Sunshine of Your Love
```

A real module of stages would export `longer_than` for its users to
import. It's written inline here only so the example runs as it
stands. A function that makes a stage without options is called with
empty parentheses, as `numbered()` is, or without them once it's
declared or imported, as `collect` is.

### Report a mistake at the caller's line

`croakf`, from Ekorn::Pipeline::Errors, croaks with a message made by
`sprintf`, at the line that called the function making the stage. The
user sees their own line, not one inside your module:

```perl
eval { My::Stages::Words::longer_than(-1) };
print $@;    # Expected a length of 0 or more, not -1 at ... line ...
```

It reports the caller's line only when the function that croaks is in
a package of its own, as a module of stages is. From `main`, called by
`main`, Carp gives a full backtrace instead. A helper in the same
package can call `croakf` and still report the caller's line. A helper
in another package needs that package in `@CARP_NOT` (see
[Errors](REFERENCE.md#errors-ekornpipelineerrors) in the reference).

### Pass a last value on when stopping

A stage that knows a value is the last one wanted should pass it on
with the stop, as `take` does. Then the pipeline ends without asking
its source for one more:

```perl
sub up_to ($wanted) {
    return sub ($value) { $value eq $wanted ? Stop($value) : $value };
}

my $next = Ekorn::Pipeline->new(value_of('title'), up_to('Parklife'))
    ->iterator(do { my $i = 0; sub { $i < @tracks ? $tracks[$i++] : () } });
my @up_to;
while (my($title) = $next->()) { push @up_to, $title }
say scalar @up_to;    # 4
```

`up_to` compares the whole value with `eq`, so here it's given titles,
not tracks. Mind what a stage is given, and say so in its
documentation.

### Use a pipeline in another

A pipeline can be used as a stage, so stages you've put together once
can be reused, in another pipeline or with any function that passes
its stages to `new`:

```perl
my $clean = Ekorn::Pipeline->new(sub { s( \A \s+ | \s+ \z )()xgr }, sub { length ? $_ : () });

my @titles = Ekorn::Pipeline->new($clean, take(2))->('  Parklife ', '   ', 'Tender', 'Waterloo');
say join '|', @titles;    # Parklife|Tender

say join '|', tracks(value_of('title'), $clean, take(3));    # Dancing Queen|Knowing Me, Knowing You|Girls & Boys
```

Some functions check for code references themselves, and may refuse a
pipeline. Give those the pipeline's stages instead:
`tracks(value_of('title'), $clean->stages, take(3))`.

Either way, the stages run as if you had written them out in full. A
stop in one ends the whole run. A `gather` stage starts afresh on each
run, so two pipelines that use it, or one that uses it twice, don't
share its state. A plain closure is the same code wherever it goes, so
anything it keeps is shared; keep state in `gather` instead, as
[Keep count, starting afresh on each run](#keep-count-starting-afresh-on-each-run)
shows.

To run a pipeline on each value separately, call it from a stage:
`sub { $clean->($_) }`. Each call is then a run of its own, so a
`take(2)` inside limits each call, not the whole run.

### Test a stage

Calling a pipeline with values tests a stage, with no source to set
up. Run it twice, to show it starts afresh, and with no values, to
show what its end gives:

```perl
use Test2::V0;

my $p = Ekorn::Pipeline->new(numbered());
is [$p->(qw(a b))], ['1. a', '2. b'], 'numbers each value';
is [$p->('c')],     ['1. c'],         'from 1 on each run';
is [$p->()],        [],               'nothing, from nothing';
done_testing;
```

Test a stage that stops through an iterator too, counting the
source's calls, to show it reads no more than it should.

### Publish a module of stages

Where a module of stages belongs depends on what its stages need to
know:

- **Stages for any values,** whatever they are and wherever they come
  from, go under `Ekorn::Pipeline::Stages`, like the canned stages.
- **Stages for one kind of value, or one source,** go with the module
  that knows about it, under its namespace. DBIx::Squirrel's stages
  for rows are `DBIx::Squirrel::Stages::Rows`. Stages for a log format
  of your own might be `My::Log::Stages`.

Export the stages a module is mostly used for by default, and the rest
on request, with an `:all` tag, as the canned stages do. Choose names
that don't clash with what common modules export: Flow has `drop`, not
`skip`, because Test2::V0 and Test::More both export `skip`.

Have the distribution require the version of Ekorn::Pipeline it was
tested with, up to the next change of the middle number, since that's
when the way stages behave can change. In a `cpanfile`:

```
requires 'Ekorn::Pipeline', '>= v0.1.1, < v0.2.0';
```

## Handling errors

### Find the stage that failed

A stage that dies is named by its position in the pipeline, and
reported at the line of the code that ran it, with its message below,
indented:

```perl
eval { tracks(sub { $_->{title} }, sub { die "No more Blur\n" if m( Boys )x; $_ }) };
print $@;
# Pipeline stage #2 failed at ... line ...:
#     No more Blur
```

The line is the one that ran the pipeline: here, the line in `tracks`
that calls it, because `tracks` is in `main`. A module of functions
that take stages can report its caller's line instead (see
[Report your callers' mistakes at their own lines](#report-your-callers-mistakes-at-their-own-lines)).
With an iterator, the line is the one that asked for the result. An
end function that dies is named by its stage's position.

A stage inside a pipeline used as a stage is named by its position in
each pipeline. Here `$no_blur` is the second stage, and the stage that
dies is its second, so it's `#2.2`:

```perl
my $no_blur = Ekorn::Pipeline->new(sub { $_->{title} }, sub { die "No more Blur\n" if m( Boys )x; $_ });
eval { tracks(sub { $_ }, $no_blur) };
print $@;
# Pipeline stage #2.2 failed at ... line ...:
#     No more Blur
```

### Throw exception objects through

An exception object, such as one from a class of your own, is thrown
again unchanged, so a caller can catch it by its class:

```perl
package Not::Found { sub new ($class, %args) { bless {%args}, $class } }

eval { tracks(sub { die Not::Found->new(title => $_->{title}) }) };
say ref $@, ': ', $@->{title};    # Not::Found: Dancing Queen
```

### See mistakes in making a pipeline at your own line

A mistake in making a pipeline or a canned stage, such as a stage that
isn't a code reference, or `take(-1)`, is reported at the line that
made it, before any value goes through:

```perl
eval { Ekorn::Pipeline->new(sub { $_ }, 'title') };
print $@;    # Expected stage #2 to be a code reference at ... line ...

eval { take(-1) };
print $@;    # Expected a count of 0 or more at ... line ...
```

[Diagnostics](REFERENCE.md#diagnostics) in the reference lists every
message and what it means.
