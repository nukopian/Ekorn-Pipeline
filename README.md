[![Actions Status](https://github.com/nukopian/Ekorn-Pipeline/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/nukopian/Ekorn-Pipeline/actions?workflow=test)
# Ekorn-Pipeline

Stages for any function: let the caller finish the job.

A function that hands out values can't know everything its callers
will want done with them. Ekorn::Pipeline lets it take a list of
_stages_ from its caller, small functions that each see one value at
a time, and run what it would return through them. The caller says,
beside the call, what they want; the function does what only it can,
and no more.

    use Ekorn::Pipeline;
    use Ekorn::Pipeline::Stages::Flow;    # take and drop

    # The author's function: it reads log lines, and nothing else.
    sub log_lines ($file, @stages) {
        open my $fh, '<', $file or die "Can't read $file: $!\n";
        return Ekorn::Pipeline->new(@stages)
            ->iterator(sub { scalar(<$fh>) // () });
    }

    # A caller's use of it: the first ten errors, as their messages.
    my $errors = log_lines(
        'app.log',
        sub { m( \A ERROR \  (.*) )x ? $1 : () },    # only errors, as messages
        take(10),                                    # ten, then stop reading
    );
    while (my($message) = $errors->()) { say $message }

## The problem it solves

Every function that returns a list meets the same pressure. One caller
wants only some of the values, another wants them in a different shape,
a third wants the first ten, a fourth wants them in batches of 500. The
author has two ways to answer, and both cost something.

- **Grow options.** `active_only`, `fields`, `limit`,
`offset`, `as_hash`, `batch_size`, `callback`. Each is code the
author writes, tests, documents and keeps, and each interacts with the
others: does `limit` count before or after `active_only`? The list is
never finished, because the next caller wants something nobody thought
of, and every caller pays, in reading the documentation, for the
options they'll never use.
- **Leave it to the caller.** The function returns everything, and
each caller writes a loop around the call: a temporary array, a
counter, a flag, a `last`. The calling code fills with noise that has
nothing to do with what it's for, the same few loops are written over
and over, and the function can't stop early, because by the time the
caller has the values, all the work of making them is done.

Stages are a third way. The function takes a list of them as its last
arguments, and runs each value it makes through them, so the caller's
processing happens _inside_ the function, one value at a time, as
the values are made:

    # Options
    sub users (%opt) {
        my @users = load_users();
        @users = grep { $_->{active} } @users if $opt{active_only};
        @users = map  { $_->{name} } @users   if $opt{names_only};
        @users = splice @users, 0, $opt{limit} if $opt{limit};
        return @users;
    }

    # Stages
    sub users (@stages) {
        return Ekorn::Pipeline->new(@stages)->(load_users());
    }

    my @names = users(sub { $_->{active} ? $_ : () }, sub { $_->{name} }, take(10));

The second `users` does everything the first does, and everything it
doesn't, without a line more. Its author is done with it: whatever a
caller wants next, the caller can write, as a stage, without asking.

## Stages

A stage is a code reference. It's called with one value, as its
argument and in `$_`, and returns a list:

- **nothing,** to drop the value: a _filter_;
- **one value,** to pass it on, changed or not: a _map_;
- **several,** each of which goes on through the rest of the
stages by itself: a _flatMap_.

One shape covers all three, so a pipeline is just a list of stages,
and a stage needs no wrapper to say which kind it is:

    sub { $_ % 2 ? $_ : () }                # filter: the odd numbers
    sub { $_ * 10 }                         # map: ten times each
    sub ($user) { @{ $user->{roles} } }     # flatMap: each of a user's roles

Returning a list, rather than a value or `undef`, is what makes this
work. An empty list is plainly "nothing", so `undef`, `0` and the
empty string are values like any other, and can be passed on.

## One value at a time

Each value goes through every stage before the next one starts, as it
would in a `for` loop. So the values come out in order, a stage sees
them in order, and nothing is held between stages: a pipeline over a
million values needs no more memory than one over ten.

A pipeline runs two ways:

- **Pushed:** called with values, it returns the list that comes
out of the last stage.

        my @results = $pipeline->(@values);

- **Pulled:** given a _source_, a function returning the next
value each time it's called, `iterator` returns a function handing out
the results one per call. The source is called only when a result is
wanted, so a function reading a file, a socket or a database reads only
as much as its caller asks for.

        my $next = $pipeline->iterator(sub { $queue->shift // () });
        while (my($result) = $next->()) { ... }

## Stopping early

A stage can end the pipeline with [Ekorn::Pipeline::Stop](https://metacpan.org/pod/Ekorn%3A%3APipeline%3A%3AStop). The
values already out are kept, any values the stop carries go on through
the rest of the stages, and nothing else is made: once a stage has
stopped it, a pulled pipeline never calls its source again.

    use Ekorn::Pipeline::Stop;

    sub ($user) { $user->{id} == $wanted ? Stop($user) : () }    # find one, then stop

This is what lets a caller's processing save the author's work. With
`take(10)`, the function in the example at the top reads ten error
lines and however many lines lie between them, and leaves the rest of
the file unread. No option for it was written, and the caller wrote no
`last`.

## Stages with state, and with an end

A stage is a closure, so it can keep state, such as a count. But a
plain closure keeps it from one run to the next, and can't tell when
the last value has gone by. [Ekorn::Pipeline::Gather](https://metacpan.org/pod/Ekorn%3A%3APipeline%3A%3AGather) makes a stage
afresh at the start of each run, and lets it have an _end function_,
called once the values run out, whose values go on through the rest
of the stages:

    use Ekorn::Pipeline::Gather;

    sub batches_of ($size) {
        return gather {
            my @batch;    # this run's
            return (
                sub ($x) { push @batch, $x; @batch == $size ? [splice @batch] : () },
                sub ()   { @batch ? [@batch] : () },    # the last, short batch
            );
        };
    }

That's how `batch`, `collect`, `take` and `drop` are made.

## Stages are values

Stages are code references, so they can be kept in variables, built by
functions and passed around. A function that returns a stage is a word
in a vocabulary, which grows in the caller's code, not the author's:

    sub only_active () { sub { $_->{active} ? $_ : () } }
    sub field ($name)  { sub { $_->{$name} } }

    my @page = (drop(20), take(10));
    my @names = users(only_active, field('name'), @page);

The same stages work with every function that takes them, so one
written for `users` works for `log_lines`, or for a function on
CPAN its author never heard of.

## Writing a function that takes stages

- **Take the stages last.** Whatever arguments the function
needs come first, and the stages after them, as
`sub log_lines ($file, @stages)`. A caller who wants nothing done
passes none, and a pipeline with no stages returns its values as they
are, so there's nothing to special-case.
- **Push what you have; pull what you make.** If the values are
already in memory, call the pipeline with them. If they're made one at
a time, from a file, a socket, a database or a computation, give
`iterator` a source, and return the iterator, so a stage that stops
saves the work of making the rest.
- **Let the stages do the optional work.** If you're about to add
an option that filters, reshapes or limits what's returned, a stage
does it already, and it's one fewer thing for you to maintain.

A class of your own can have `pipe` and `tap` methods, from
[Ekorn::Pipeline::Pipes](https://metacpan.org/pod/Ekorn%3A%3APipeline%3A%3APipes), which run an object through stages: `pipe`
returns what comes out, and `tap` returns the object, so a chain of
method calls can carry on after it.

## Errors

A stage that dies is named by its place in the pipeline, at the line
of the caller's code that ran it, with its message below:

    Pipeline stage #2 failed at app.pl line 12:
        No name for user 7 at app.pl line 9.

An exception object is passed on as it is. A mistake in how a pipeline
or a canned stage is made, such as a stage that isn't a code reference
or `take(-1)`, is reported at the caller's line too.

## Canned stages

- [Ekorn::Pipeline::Stages::Flow](https://metacpan.org/pod/Ekorn%3A%3APipeline%3A%3AStages%3A%3AFlow): `take`, `drop`,
`take_while` and `drop_while`, which pass on values by their place or
by a test.
- [Ekorn::Pipeline::Stages::Batch](https://metacpan.org/pod/Ekorn%3A%3APipeline%3A%3AStages%3A%3ABatch): `batch` and `collect`,
which gather values and pass them on together.
- [Ekorn::Pipeline::Stages::Taps](https://metacpan.org/pod/Ekorn%3A%3APipeline%3A%3AStages%3A%3ATaps): `peek`, `count_into` and
`dump_to`, which look at each value and pass it on, for logging,
counting and debugging.

## Stage modules of your own

Stages are plain code references, so anyone can make them, in any
namespace. Where a module of them goes depends on what its stages need
to know:

- **Stages for any values** go under `Ekorn::Pipeline::Stages`,
as the canned stages do. They work whatever the values are, and
wherever they come from.
- **Stages for one kind of value, or one source,** go with the
module that knows about it, under its own namespace. DBIx::Squirrel's
stages for rows, `pluck` and `as_hash`, which need a statement's
column names, are in `DBIx::Squirrel::Stages::Rows`; stages for a log
format of your own might be in `My::Log::Stages`.

A module of stages, wherever it goes, is built from the same parts as
the canned stages: [Ekorn::Pipeline::Gather](https://metacpan.org/pod/Ekorn%3A%3APipeline%3A%3AGather) for state and end
functions, [Ekorn::Pipeline::Stop](https://metacpan.org/pod/Ekorn%3A%3APipeline%3A%3AStop) to end early, and `croakf`, from
[Ekorn::Pipeline::Errors](https://metacpan.org/pod/Ekorn%3A%3APipeline%3A%3AErrors), to report a mistake in making a stage at
the line of the caller who made it:

    package My::Stages::Words;

    use v5.36;
    use Exporter qw(import);
    use Ekorn::Pipeline::Errors qw(croakf);

    our @EXPORT_OK = qw(longer_than);

    sub longer_than ($length) {
        croakf 'Expected a length of 0 or more, not %s', $length // 'undef'
            unless defined $length && $length =~ m( \A \d+ \z )x;
        return sub ($word) { length $word > $length ? $word : () };
    }

## Where it came from

The pipeline began in [DBIx::Squirrel](https://metacpan.org/dist/DBIx-Squirrel),
where stages declared beside a query shape the rows it returns. None of
it needs a database, so it's here on its own, for any function to use,
and to grow beyond what rows need. DBIx::Squirrel is to use
Ekorn::Pipeline in time, once both are stable.

## Documentation

Each module's POD, starting with [Ekorn::Pipeline](https://metacpan.org/pod/Ekorn%3A%3APipeline), describes it in
full.

## Installing

It isn't on CPAN yet. To install it from GitHub:

    cpanm https://github.com/nukopian/Ekorn-Pipeline.git

It needs Perl 5.36 or later.

## Licence

Copyright (c) 2024-2026 by Iain Campbell. This is free software; you can
redistribute it and/or modify it under the same terms as the Perl 5
programming language system itself. See the file `LICENSE`.

## Acknowledgements

Written by Iain Campbell, with Claude, Anthropic's AI model, which
reviews the code, writes parts of it where Iain asks, often from his
code in DBIx::Squirrel, and helps with the Git Ops, the repository's
setup, and the tests and documentation.
