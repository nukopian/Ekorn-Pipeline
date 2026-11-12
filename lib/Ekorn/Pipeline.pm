use v5.36;

package Ekorn::Pipeline;

use experimental qw(builtin try);

use builtin   qw(blessed refaddr);
use Carp      qw(croak);
use Exporter  qw();
use Ref::Util qw(is_arrayref is_coderef is_ref);
use mro       qw();

use parent 'Ekorn::Pipeline::Element';

use Ekorn::Pipeline::Errors   qw(croakf);
use Ekorn::Pipeline::Iterator qw();
use Ekorn::Pipeline::Stage    qw();

use namespace::clean -except => 'import';

our $VERSION = 'v0.2.0';

our @EXPORT_OK = qw(is_sink is_stage pipeline);

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Return true if what's given can go where a stage goes: a code
# reference; a pipeline, whose stages go in its place; or anything
# offering a stage's or a sink's role method.
sub is_stage ($thing) {
    return !!(is_coderef($thing)
        || $thing isa 'Ekorn::Pipeline'
        || _stage_role($thing));
}


# Return "scalar" if what's given is a sink giving one value, "list" if
# it's a sink giving a list, or false otherwise; a pipeline, by the
# sink it ends in.
sub is_sink ($thing) {
    ($thing) = ($thing->stages)[-1] if $thing isa 'Ekorn::Pipeline';
    return !!0                      unless blessed($thing);
    return 'scalar'                 if $thing->can('as_scalar');
    return 'list'                   if $thing->can('as_list');
    return !!0;
}


# Return the role method that what's given offers for a stage's place,
# as_stage, as_scalar or as_list, or nothing if it offers none.
sub _stage_role ($thing) {
    return unless blessed($thing);
    my @roles = grep { $thing->can($_) } qw(as_stage as_scalar as_list);
    return $roles[0];
}


# Return true if what's given offers a source's role method.
sub _is_source ($thing) {
    return !!(blessed($thing) && $thing->can('as_source'));
}


# Return the stage given as an element: a part offering a role method is
# kept as it is, and a code reference is made a Stage.
sub _element ($stage) {
    return $stage if $stage isa 'Ekorn::Pipeline::Element' || _stage_role($stage);
    return Ekorn::Pipeline::Stage->new($stage);
}


# Croak unless what's given, as stage #$n, can go where a stage goes, as
# one role: a source isn't a stage, and a part offering more than one of
# a stage's and a sink's role methods couldn't say which it is.
sub _check_stage ($stage, $n) {
    my @roles
        = blessed($stage)
        ? grep { $stage->can($_) } qw(as_stage as_scalar as_list)
        : ();
    croakf
        'Expected stage #%d to offer one of as_stage, as_scalar and as_list, not %s',
        $n,
        join ' and ', @roles
        if @roles > 1;
    croakf 'Expected stage #%d to be a stage, not a source', $n
        if !@roles && _is_source($stage);
    croakf 'Expected stage #%d to be a code reference or a pipeline', $n
        unless is_stage($stage);
    return;
}


# Return a pipeline, called with values to run each of them through the
# stages. A pipeline given as a stage has its stages spliced in, each
# named by its place in each pipeline, such as "2.3". In scalar context,
# a call gives how many values came out, unless the last stage is a
# scalar sink, when it gives that sink's result.
sub new ($class, @given) {
    my(@stages, @names);
    for my $n (1 .. @given) {
        my $stage = $given[$n - 1];
        _check_stage($stage, $n);
        if ($stage isa 'Ekorn::Pipeline') {
            my($inner, $inner_names) = _composed($stage);
            croakf 'Expected stage #%d to be a code reference or a pipeline', $n
                unless $inner_names;
            push @stages, map { _element($_) } @$inner;
            push @names,  map { "$n.$_" } @$inner_names;
            next;
        }
        push @stages, _element($stage);
        push @names,  $n;
    }
    my $scalar_sink = @stages && is_sink($stages[-1]) eq 'scalar';
    return bless {
        stages => \@stages,
        names  => \@names,
        call   => sub (@values) {
            return @values unless @stages;
            my $next
                = _iterator(\@stages, \@names, sub { @values ? shift @values : () });
            my @results;
            while (my($result) = $next->()) { push @results, $result }
            return @results if wantarray;
            return $scalar_sink ? $results[0] : scalar @results;
        },
    }, $class;
}

# The named pipelines: for each class, the names defined through it, each
# qualified by its package. A class sees its own names and its ancestors',
# never its descendants', so a subclass's stay with it.
my %named;

# Return $name qualified by $package, unless it's qualified already, or
# nothing if it isn't a name: identifiers, as Perl's, joined by "::".
sub _qualified ($name, $package) {
    return if !defined $name || is_ref($name);
    return unless $name =~ m( \A (?: [^\W\d] \w* :: )* [^\W\d] \w* \z )x;
    return $name =~ m( :: )x ? $name : "${package}::$name";
}


# Return the pipeline named $name, qualified, as $class sees it: its own,
# or else its nearest ancestor's, or nothing if it has none.
sub _lookup ($class, $name) {
    for my $from (@{ mro::get_linear_isa($class) }) {
        my $pipeline = $named{$from}{$name};
        return $pipeline if $pipeline;
    }
    return;
}


# Return the stages given, each name replaced by the pipeline it names, as
# $class sees it, looked up in $package unless it's qualified.
sub _resolved ($class, $package, @given) {
    my @stages;
    for my $n (1 .. @given) {
        my $stage = $given[$n - 1];
        if (is_stage($stage)) {
            push @stages, $stage;
            next;
        }
        my $name = _qualified($stage, $package);
        croakf
            'Expected stage #%d to be a code reference, a pipeline or the name of one',
            $n
            unless defined $name;
        my $pipeline = _lookup($class, $name);
        croakf 'No pipeline named %s', $name unless $pipeline;
        push @stages, $pipeline;
    }
    return @stages;
}


# Return a new pipeline of the stages given, each a code reference, a
# pipeline, or the name of one, which is looked up now.
sub pipeline (@stages) {
    return __PACKAGE__->new(_resolved(__PACKAGE__, scalar caller, @stages));
}


# Export what's asked for, as Exporter does, but pipeline, asked for
# through a subclass, is a function making that subclass. It reads its
# caller when it's called, so names are looked up in the package that
# calls it, wherever it's been exported to.
sub import ($class, @names) {
    my $into = caller;
    if ($class ne __PACKAGE__ && grep { $_ eq 'pipeline' } @names) {
        no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
        *{ "${into}::pipeline" } = sub (@stages) {
            return $class->new(_resolved($class, scalar caller, @stages));
        };
        @names = grep { $_ ne 'pipeline' } @names;
    }
    Exporter::export($class, $into, @names);
    return;
}


# Name a pipeline, in the caller's package unless the name is qualified,
# and return it: on the class, a new one of the stages after the name,
# read as pipeline reads them; on a pipeline, that one. The name is the
# class's, seen by it and its descendants, and overrides an ancestor's of
# the same name for them; it can't be one the class has defined already.
sub named ($invocant, $name, @stages) {
    my $class     = ref $invocant ? ref $invocant : $invocant;
    my $package   = caller;
    my $qualified = _qualified($name, $package);
    croakf 'Expected a name, made of words joined by ::' unless defined $qualified;
    my $pipeline;
    if (ref $invocant) {
        croakf 'Expected only a name, naming a pipeline you have' if @stages;
        $pipeline = $invocant;
    }
    else {
        $pipeline = $class->new(_resolved($class, $package, @stages));
    }
    my $own = $named{$class}{$qualified};
    croakf 'A pipeline named %s is already defined', $qualified
        if $own && refaddr($own) != refaddr($pipeline);
    return $named{$class}{$qualified} = $pipeline;
}

# Return the stages of a pipeline given as a stage, from its stages
# method, as giving its stages would, and their names: its own, if the
# method returns the stages it was made with, as it does unless a
# subclass overrides it, or else their places in what it returns. The
# names are undefined if what it returns isn't all code references.
sub _composed ($pipeline) {
    my @stages = $pipeline->stages;
    my $made   = $pipeline->{stages};
    my $same   = @stages == @$made;
    for my $i (0 .. $#stages) {
        last unless $same;
        $same = (refaddr($stages[$i]) // 0) == refaddr($made->[$i]);
    }
    return \@stages, $pipeline->{names} if $same;
    return \@stages, undef              if grep { !is_stage($_) } @stages;
    return \@stages, [1 .. @stages];
}


# Return an iterator handing out, one per call, the values from $source
# run through the stages: $source a code reference, or anything
# offering a source's role method, an iterator included.
sub iterator ($self, $source) {
    croakf 'Expected a code reference'
        unless is_coderef($source) || _is_source($source);
    return _iterator($self->{stages}, $self->{names}, $source);
}


# Return the stages, in order, as a list, to splice into another
# pipeline or give to any function taking stages.
sub stages ($self) {
    return @{ $self->{stages} };
}

# What a pipeline is doing while its stages run.
my %running;

# For code telling its stages about the value they're given: true while
# a flush runs, and while the values it gave go through the stages,
# rather than values from the source.
sub ending () {
    return $running{ending};
}


# For code telling its stages about the run: the context the run's
# source gave, if any, such as a statement's columns. A pushed run has
# none; an iterator used as a source passes on its run's.
sub run_context () {
    return $running{context};
}


# Return the step, the end and the context of a run of $source: from
# its as_source, if it offers one; a code reference is its own step,
# with no end or context.
sub _source_run ($source) {
    return ($source) unless _is_source($source);
    my($step, $end, $context) = $source->as_source;
    croakf
        'Expected the source to return a code reference, and optionally an end and a context'
        unless is_coderef($step) && _code_or_none($end);
    return ($step, $end, $context);
}


# Return true if each of what's given is a code reference, or undefined.
sub _code_or_none (@things) {
    return !grep { defined && !is_coderef($_) } @things;
}


# Return the text of an end's error: a stop's own text, "Stop used
# outside a pipeline", would mislead, as the stop was in a run.
sub _end_error ($error) {
    return 'Expected no stop in an end, as the run has ended'
        if $error isa 'Ekorn::Pipeline::Stop';
    return "$error";
}


# Call each end given, as [$label, $end, $how], in order. While the run
# is dying, an end that dies is reported as a warning naming it, and the
# rest are called. Otherwise, an end that dies tells every end after it
# "died", and its error is thrown once they've run.
sub _end_all ($ends, $dying) {
    my($error, $failed);
    for my $call (@$ends) {
        my($label, $end, $how) = @$call;
        try {
            local $_ = undef;
            $end->($dying || defined $error ? 'died' : $how);
        }
        catch ($e) {
            if ($dying || defined $error) {
                Carp::carp sprintf 'The end of %s died while the run was already dying: %s',
                    $label, _end_error($e) =~ s( \n \z )()xr;
            }
            else {
                ($error, $failed) = ($e, $label);
            }
        }
    }
    return unless defined $error;
    # A stop from an end is an error like any other: the run has ended.
    croak $error if is_ref($error) && !($error isa 'Ekorn::Pipeline::Stop');
    my $at      = Carp::shortmess()  =~ s( \.? \n \z )()xr;
    my $message = _end_error($error) =~ s( \n \z )()xr =~ s( ^ )(    )xmgr;
    die "Pipeline end of $failed failed$at:\n$message\n";
}


# Make the parts of a run from @$stages, named by @$names, into the
# lists in %$run: each part's step, its flush and its end, by its role
# method, and whether it's a sink. A gather's block may return a
# pipeline as its step, whose stages are made in its place, followed by
# the gather's flush and end, if any, on a stage of their own that
# passes values on.
sub _make_run ($stages, $names, $run) {
    for my $i (0 .. $#$stages) {
        my($stage, $name) = ($stages->[$i], $names->[$i]);
        my $role = _stage_role($stage) // '';
        my($step, $flush, $end);
        if ($stage isa 'Ekorn::Pipeline::Gather') {
            my @made = $stage->as_stage;
            my($inner, $inner_names)
                = @made && $made[0] isa 'Ekorn::Pipeline' ? _composed($made[0]) : ();
            croakf
                'Expected stage #%s, made with gather, to return a code reference or a pipeline, and optionally an end function',
                $name
                unless (@made == 1 || @made == 2 || @made == 3)
                && ($inner ? $inner_names : is_coderef($made[0]))
                && _code_or_none(@made[1 .. $#made]);
            ($step, $flush, $end) = @made;
            if ($inner) {
                _make_run($inner, [map { "$name.$_" } @$inner_names], $run);
                next unless $flush || $end;
                $step = sub ($value) { $value };
            }
        }
        elsif ($role eq 'as_scalar' || $role eq 'as_list') {
            ($step, $flush, $end) = $stage->$role;
            croakf
                'Expected sink #%s to return a code reference, a flush, and optionally an end',
                $name
                unless is_coderef($step)
                && is_coderef($flush)
                && _code_or_none($end);
            # What a sink's step returns is ignored; a scalar sink's flush
            # gives one value, undef if it has none.
            my($each, $result) = ($step, $flush);
            $step  = sub ($value) { $each->($value);    return };
            $flush = sub () { my @result = $result->(); return $result[0] }
                if $role eq 'as_scalar';
        }
        elsif ($role eq 'as_stage') {
            ($step, $flush, $end) = $stage->as_stage;
            croakf
                'Expected stage #%s to return a code reference, and optionally a flush and an end',
                $name
                unless is_coderef($step) && _code_or_none($flush, $end);
        }
        else {
            $step = $stage;
        }
        push @{ $run->{stages} },  $step;
        push @{ $run->{names} },   $name;
        push @{ $run->{flushes} }, $flush;
        push @{ $run->{ends} },    $end;
        push @{ $run->{sinks} },   $role eq 'as_scalar' || $role eq 'as_list';
    }
    return;
}


# Return an iterator handing out, one per call, the values from $source
# run through the stages in @$stages, named in messages by @$names.
#
# The run ends as soon as nothing in it can still act on a value: the
# source has run out or stopped, every flush has been called, and every
# value still to be handed out has passed the last stage; or when it's
# ended from outside, or dies. Then each end is called, the source's
# first, told how the run ended from where it stands: "died" if the run
# died; else "done" if its input ran out, and "stopped" if not.
sub _iterator ($stages, $names, $source) {
    my %run = (stages => [], names => [], flushes => [], ends => [], sinks => []);
    my($pull, $source_end, $context);
    try {
        ($pull, $source_end, $context) = _source_run($source);
        _make_run($stages, $names, \%run);
    }
    catch ($e) {
        _end_all(
            [
                ($source_end ? ['the source', $source_end, 'died'] : ()),
                map { ["stage #$run{names}[$_]", $run{ends}[$_], 'died'] }
                    grep { $run{ends}[$_] } 0 .. $#{ $run{ends} },
            ],
            1,
        );
        # A set-up runs before the run has values, so has nothing to stop.
        croakf 'Expected no stop in a set-up, as the run has nothing yet to stop'
            if $e isa 'Ekorn::Pipeline::Stop';
        croak $e if is_ref($e);
        die $e;    ## no critic (ErrorHandling::RequireCarping): thrown again, as it was
    }
    my @stages  = @{ $run{stages} };
    my @flushes = @{ $run{flushes} };
    my @ends    = @{ $run{ends} };
    my @sinks   = @{ $run{sinks} };
    $names = $run{names};
    # Each value waiting to go through a stage, as the stage's index, the
    # value, and whether it came from a flush, the next on top. A value a
    # stage returns on its own, as most are, carries on through the stages
    # without waiting here. Once the source is done, the flushes are called
    # in order, from the first not called or passed over by a stop.
    my(
        @todo,  $done,  $source_done, %flushed, @input_done, $finished, $outside,
        $ended, $spent, $dropped,
    );
    my $next_flush = 0;
    # How the run ended, as its caller asks: whether the source was read
    # to its end, "stopped" if values still to be handed out were dropped,
    # or "died" if anything died, an end included.
    my $finish = sub ($died) {
        return if $finished++;
        $ended
            = $died        ? 'died'
            : $dropped     ? 'stopped'
            : $source_done ? 'done'
            :                'stopped';
        my @calls;
        push @calls, ['the source', $source_end, $source_done ? 'done' : 'stopped']
            if $source_end;
        push @calls,
            map { [
                "stage #$names->[$_]", $ends[$_], $input_done[$_] ? 'done' : 'stopped',
            ] }
            grep { $ends[$_] } 0 .. $#ends;
        local $running{context} = $context;
        try {
            _end_all(\@calls, $died);
        }
        catch ($e) {
            # An end died: the run died, and hands out nothing more.
            ($ended, $spent, @todo) = ('died', 1);
            die $e;    ## no critic (ErrorHandling::RequireCarping): thrown again, as it was
        }
        return;
    };
    # The index of the next flush to call, if any.
    my $flush_at = sub () {
        my($n) = grep { $flushes[$_] && !$flushed{$_} } $next_flush .. $#stages;
        return $n;
    };
    # Every part from the next flush up to $upto has had all its input.
    my $input_ran_out = sub ($upto) {
        $input_done[$_] = 1 for $next_flush .. $upto;
        return;
    };
    # At a stop at stage $n, with nothing more to come from upstream,
    # every stage up to it whose input had run out: none of its values
    # still waiting, and no flush before it still to be called.
    my $input_ran_out_at_stop = sub ($n) {
        for my $stage ($next_flush .. $n) {
            last if grep { $_->[0] <= $stage } @todo;
            last if grep { $flushes[$_] && !$flushed{$_} } $next_flush .. $stage - 1;
            $input_done[$stage] = 1;
        }
        return;
    };
    # End the run if nothing in it can still act on a value.
    my $end_if_ended = sub () {
        return if $finished || !$done || defined $flush_at->();
        return if grep { $_->[0] < @stages } @todo;
        $input_ran_out->($#stages);
        $finish->(0);
        return;
    };
    my $next = sub () {
        return if $outside;
        while (1) {
            my($n, $value, $from_flush, $flush, $sink_flush);
            if (@todo) {
                ($n, $value, $from_flush) = @{ pop @todo };
            }
            elsif (!$done) {
                my @values;
                try {
                    @values = $pull->();
                }
                catch ($e) {
                    if ($e isa 'Ekorn::Pipeline::Stop') {
                        # A source that stops has had enough: what it
                        # carries is its last, and it's done.
                        my(undef, @carried) = is_arrayref($e) ? @$e : ();
                        ($done, $source_done) = (1, 1);
                        push @todo, map { [0, $_] } reverse @carried;
                        next;
                    }
                    ($done, $next_flush, @todo) = (1, scalar @stages);
                    $finish->(1);
                    croak $e if is_ref($e);
                    die $e;    ## no critic (ErrorHandling::RequireCarping): thrown again, as it was
                }
                unless (@values) {
                    ($done, $source_done) = (1, 1);
                    next;
                }
                ($n, $value) = (0, shift @values);
                push @todo, map { [0, $_] } reverse @values;
            }
            else {
                $n = $flush_at->();
                unless (defined $n) {
                    $end_if_ended->();
                    last;
                }
                $input_ran_out->($n);
                $flushed{$n} = 1;
                ($next_flush, $flush, $from_flush) = ($n + 1, $flushes[$n], 1);
            }
            if ($n == @stages) {
                $end_if_ended->();
                return $value;
            }
            # Set only when it changes, as most values come from the source.
            local $running{ending} = $from_flush
                if $from_flush || $running{ending};
            local $running{context} = $context;
            my $kept = 1;
            try {
                if ($flush) {
                    local $_ = undef;
                    my @values = $flush->();
                    $n++;
                    $kept  = @values;
                    $value = shift @values;
                    push @todo, map { [$n, $_, 1] } reverse @values;
                }
                while ($kept && $n < @stages) {
                    local $_ = $value;
                    my @values = $stages[$n]->($value);
                    last if $outside;
                    $n++;
                    unless (@values) {
                        $kept = 0;
                        last;
                    }
                    $value = shift @values;
                    push @todo, map { [$n, $_, $from_flush] } reverse @values;
                }
            }
            catch ($e) {
                if ($e isa 'Ekorn::Pipeline::Stop') {
                    # A stop made by throw is an array; one made otherwise
                    # carries nothing. A sink that stops the run still
                    # gives its result.
                    my(undef, @values) = is_arrayref($e) ? @$e : ();
                    $input_ran_out_at_stop->($n) if $done;
                    $done = 1;
                    my $from = $sinks[$n] && !$flushed{$n} ? $n : $n + 1;
                    $next_flush = $from if $next_flush < $from;
                    @todo       = map { [$n + 1, $_, $from_flush] } reverse @values;
                    next;
                }
                # A stage or a flush that dies ends the run: nothing waiting
                # goes on, and every end is told it died.
                ($done, $next_flush, @todo) = (1, scalar @stages);
                $finish->(1);
                croak $e if is_ref($e);
                my $at      = Carp::shortmess() =~ s( \.? \n \z )()xr;
                my $message = $e =~ s( \n \z )()xr =~ s( ^ )(    )xmgr;
                die "Pipeline stage #$names->[$n] failed$at:\n$message\n";
            }
            return if $outside;
            if ($kept) {
                $end_if_ended->();
                return $value;
            }
        }
        # Everything has been handed out: the iterator is spent.
        $spent = 1;
        return;
    };
    # Ended from outside, by the iterator's finish or as it's let go, the
    # run stops: nothing more is pulled, and nothing waiting goes on.
    my $end_run = sub () {
        $outside = 1;
        $dropped = 1 if @todo && ($ended // '') ne 'died';
        ($done, $next_flush, @todo) = (1, scalar @stages);
        $finish->(0);
        $ended = 'stopped' if $dropped;
        return;
    };
    return Ekorn::Pipeline::Iterator->new(
        $next, $end_run, $context,
        # How the run ended, held back until the iterator has nothing more
        # to give, so it's said once, and doesn't change.
        sub () {
            return $ended if $spent || $outside || ($ended // '') eq 'died';
            return;
        },
        sub () { $spent || $outside || ($ended // '') eq 'died' },
    );
}
1;
__END__

=encoding utf8

=for stopwords flatMap

=head1 NAME

Ekorn::Pipeline - run values through a list of stages

=head1 SYNOPSIS

    use Ekorn::Pipeline;

    my $p = Ekorn::Pipeline->new(
        sub { $_->{active} ? $_ : () },          # filter
        sub ($user) { @{ $user->{roles} } },     # flatMap
        sub { uc },                              # map
    );

    # Push: values in, a list out
    my @roles = $p->(@users);

    # Pull: one value per call, from a source
    my $next = $p->iterator(sub { shift @queue // () });
    while (my($role) = $next->()) { ... }

    # A function of your own, taking stages from its caller
    sub lines_of ($file, @stages) {
        open my $fh, '<', $file or die "Can't read $file: $!\n";
        return Ekorn::Pipeline->new(@stages)->iterator(sub { scalar(<$fh>) // () });
    }

    # Named pipelines, and pipeline() to make one from stages and names
    use Ekorn::Pipeline v0.2.1 qw(pipeline);

    Ekorn::Pipeline->named(clean => sub { s( \A \s+ | \s+ \z )()xgr });
    my @first = pipeline('clean', sub { length ? $_ : () })->(@lines);

=head1 DESCRIPTION

A pipeline is a list of stages. A stage is a code reference, or
another pipeline, which stands for its own stages (see
L</A pipeline as a stage>).

A code reference is called with one value, both as its argument and
in C<$_>. It can name the value with a signature,
C<sub ($row) { $row-E<gt>[1] }>, or use C<$_>, C<sub { $_-E<gt>[1] }>.
C<$_> is localised for each call, so the caller's is left alone. It
returns a list:

=over

=item * nothing, to drop the value (a filter);

=item * one value, to pass it on (a map);

=item * several, each of which goes through the rest of the stages
on its own (a flatMap).

=back

Each value goes through every stage before the next one starts. The
values come out in order, and each stage sees them in the order a
C<for> loop would.

A stage can end the pipeline early with L<Ekorn::Pipeline::Stop>. The
values already out are kept, and any values the stop carries go on
through the rest of the stages. Nothing else is processed:

    sub ($row) { $row->{id} == $wanted ? Stop($row) : () }

A stage made with L<Ekorn::Pipeline::Gather> is made afresh for each
run of the pipeline. It can also have an end function, called once the
values run out, whose values go through the rest of the stages. Each
call of a pipeline with values is a run, and so is each iterator.

=head2 Stages from your caller

A pipeline is for the author of any function that hands out values.
The function takes stages from its caller, as its last arguments, and
runs what it would return through them. The caller says what they want
done with each value, beside the call, and gets back only what they
want:

    sub bands (@stages) {
        return Ekorn::Pipeline->new(@stages)->(load_bands());
    }

    my @names = bands(sub { $_->{name} }, take(5));

With L</iterator>, the values are made one at a time, as the caller
asks for them. A function reading a file or a socket reads no more
than it has to. Once a stage has stopped the pipeline, the source isn't
called again.

The canned stages, in L<Ekorn::Pipeline::Stages::Flow>,
L<Ekorn::Pipeline::Stages::Batch> and L<Ekorn::Pipeline::Stages::Taps>,
work in any pipeline. L<Ekorn::Pipeline::Pipes> gives a class of your
own C<pipe> and C<tap> methods, which run an object through stages.

=head1 METHODS

=head2 new

    my $p = Ekorn::Pipeline->new(@stages);

Returns a pipeline that runs values through C<@stages>, in order. Each
stage must be a code reference or a pipeline (see
L</A pipeline as a stage>); anything else croaks. With no stages, a
pipeline returns its values unchanged.

A pipeline is an object that can be called as a code reference. Called
with values, it returns the list that comes out of the last stage:

    my @results = $p->(@values);

In scalar context, it returns how many results came out, as an array
would:

    my $count = $p->(@values);

=head3 A pipeline as a stage

You can give C<new> a pipeline wherever it takes a stage. Its stages
are spliced in where it stands, so these two run the same:

    my $clean = Ekorn::Pipeline->new(sub { s( \A \s+ | \s+ \z )()xgr }, sub { length ? $_ : () });

    Ekorn::Pipeline->new($clean, take(10));
    Ekorn::Pipeline->new($clean->stages, take(10));

The spliced stages belong to the new pipeline's run. A C<take> inside
C<$clean> limits the whole run, not each value.

The only difference is in error messages. Given C<$clean> itself, a
stage inside it is named by its position in each pipeline: the third
stage of a pipeline given second is C<#2.3>, and three levels down,
C<#1.2.3>. Given C<< $clean->stages >>, it's named by its position in
the combined list.

The stages spliced in are whatever the pipeline's L</stages> method
returns, so a subclass can override it. If the override returns a
different list, its stages are named by their position in that list.

To run a pipeline on each value separately instead, call it from a
stage: C<sub { $clean-E<gt>($_) }>. Each call is then a run of its
own, and a C<take> inside limits each call.

=head2 named

    Ekorn::Pipeline->named(clean => @stages);         # define from stages
    Ekorn::Pipeline->new(@stages)->named('clean');    # name one you have

Names a pipeline, and returns it. On the class, it makes a pipeline of
the stages after the name, each a code reference, a pipeline or the
name of one, as L</pipeline> takes them; a subclass makes one of its
own class. On a pipeline, it names that one, and croaks if given
stages after the name.

The name is kept in the caller's package, unless it's qualified, as
L</Named pipelines> explains. A name is identifiers, as Perl's, joined
by C<::>, such as C<clean> or C<My::Module::clean>. It's new in v0.2.1.

The name belongs to the class C<named> was called on, or, for a
pipeline, to the pipeline's class. A class can't define the same name
twice for another pipeline, which croaks. Naming the same pipeline
again, with C<< $p->named('clean') >>, is no mistake; but C<named> on
a class always makes a new pipeline, even from a single pipeline, so
calling C<< Ekorn::Pipeline->named(clean => $p) >> twice croaks. A
name can't be removed, so define each once, as a program or module
loads. A subclass can define a name its ancestor has, overriding it
for itself and its own subclasses, as
L</Named pipelines and subclasses> explains.

=head3 Named pipelines

A named pipeline is kept for the life of the program. Two things
decide which pipeline a name means, and they're separate: the
I<package> the name is in says whose name it is, so two modules can
each have a C<clean>; and the I<class> it was defined through says who
can find it (see L</Named pipelines and subclasses>). So
C<< My::Pipeline->named(loud => ...) >>, called in C<main>, defines
C<main::loud> for My::Pipeline, and Ekorn::Pipeline's own C<pipeline>,
in C<main>, croaks "No pipeline named main::loud": the name is in
C<main>, but it's My::Pipeline's.

=over

=item * C<named> keeps a name in the package that called it, and
L</pipeline> and C<named> look one up in the package that called them,
so two modules can each have a C<clean> of their own.

=item * A qualified name, such as C<My::Module::clean>, is that
package's, wherever it's used. Code that names or looks up pipelines on
another package's behalf qualifies them: C<"${package}::clean">.

=item * A name is resolved when the pipeline is made, not when it runs,
and the pipeline it names is spliced in, as a pipeline given to L</new>
is. So a pipeline, once made, keeps the pipelines it found, whatever's
defined or overridden later.

=item * Only L</pipeline> and C<named> read names. L</new> doesn't, and
L</is_stage> is false for a string.

=item * A name belongs to a class, and is inherited one way, as methods
are; L</Named pipelines and subclasses> explains.

=back

=head3 Named pipelines and subclasses

Every named pipeline belongs to a class: the class whose C<named>
defined it, or, for C<< $p->named(...) >>, the pipeline's class.
L</pipeline> looks a name up for a class too: Ekorn::Pipeline's own
for Ekorn::Pipeline, and one imported through a subclass (see
L</Through a subclass>) for that subclass. It looks among that
class's own names first, then its parent's, and so on up to
Ekorn::Pipeline, and takes the first it finds. It never looks down,
among a subclass's names. Names among the stages given to C<named> are
looked up the same way, for the class C<named> was called on. So:

=over

=item 1. A subclass sees its ancestors' names.

=item 2. An ancestor never sees a subclass's names: Ekorn::Pipeline's
own C<pipeline> croaks "No pipeline named ..." for one. So a
distribution's names for its own subclass never reach a program's
plain Ekorn pipelines.

=item 3. A subclass can override an ancestor's name, by defining the
same name for itself. It and its own subclasses then get its pipeline;
the ancestor still gets its own. An ancestor can likewise define a
name a subclass already has, and each keeps its own.

=item 4. A class can't define the same name twice, which croaks "A
pipeline named ... is already defined". Overriding defines the name
for a different class, so it isn't defining it twice.

=item 5. Overriding doesn't change a pipeline already made, as a name
is looked up when a pipeline is made. Define names before using them.

=back

    package My::Pipeline { use parent -norequire, 'Ekorn::Pipeline' }

    package main;
    BEGIN { My::Pipeline->import(qw(pipeline)) }    # here, pipeline makes My::Pipelines

    Ekorn::Pipeline->named(tidy => sub { lc });     # Ekorn::Pipeline's name
    My::Pipeline->named(loud => sub { uc });        # My::Pipeline's name

    say pipeline('tidy')->('Hi');                   # hi     (the subclass sees its ancestor's name)
    say pipeline('loud')->('Hi');                   # HI     (and its own)
    say eval { Ekorn::Pipeline::pipeline('loud') } ? 'found' : 'not found';
                                                    # not found  (the ancestor never sees the subclass's)

    my $made_before = pipeline('tidy');
    My::Pipeline->named(tidy => sub { ucfirst lc });    # the subclass overrides tidy

    say pipeline('tidy')->('hI');                   # Hi     (the subclass now gets its own)
    say Ekorn::Pipeline::pipeline('tidy')->('hI');  # hi     (the ancestor keeps its own)
    say $made_before->('hI');                       # hi     (a pipeline made earlier keeps what it found)

=head2 iterator

    my $next = $p->iterator($source);

Returns a closure that hands out the values that come out of the
stages, one per call. C<$source> is a code reference that returns the
next value or values each time it's called, and an empty list when
there are no more. It's called only once the values from its last
call have all been handed out.

The closure returns an empty list when the values run out, and on
every call after that. After a stop, it returns an empty list once the
values the stop carried are handed out, and the source isn't called
again. Read the closure in list context, so that an C<undef> value
isn't mistaken for the end:

    while (my($x) = $next->()) { ... }

The end functions of stages made with L<Ekorn::Pipeline::Gather> are
called once the source runs out, or after a stop, before the closure
returns an empty list.

If a stage or an end function dies, the call dies with it, and the
iterator has ended, as a pushed run does. Every call after returns an
empty list. Nothing waiting goes on through the stages, no end
function is called, and the source isn't called again. To skip a bad
value and carry on, catch the error inside the stage.

=head2 stages

    my @stages = $p->stages;

Returns the pipeline's stages, in order. A pipeline that was given as
a stage appears as the stages it was made of. In scalar context, it
returns how many there are.

The list can go anywhere stages go, including to a function that
accepts only code references:

    my $clean  = Ekorn::Pipeline->new(sub { s( \A \s+ | \s+ \z )()xgr }, sub { length ? $_ : () });
    my @titles = Ekorn::Pipeline->new($clean->stages, take(10))->(@raw);

To give C<new> the pipeline itself, see L</A pipeline as a stage>.
Either way, the stages run as if they had been written out in full:

=over

=item * A stop in one of them ends the whole run.

=item * A stage made with L<Ekorn::Pipeline::Gather> starts afresh on
each run, so pipelines that share it don't share its state.

=item * A plain closure is the same code reference wherever it goes,
so anything it keeps is shared. Keep state in C<gather> instead.

=item * A stage that dies is named by its position, as
L</A pipeline as a stage> describes.

=back

=head1 FUNCTIONS

=head2 pipeline

    use Ekorn::Pipeline v0.2.1 qw(pipeline);

    pipeline(sub { uc }, take(5))                # new, from stages
    pipeline('clean')                            # the pipeline named clean
    pipeline('clean', take(5))                   # it, then more
    pipeline('My::Module::clean', sub {...})     # another package's

Returns a new pipeline of the stages given, as L</new> does, but each
can also be the name of a pipeline, defined with L</named>, which
stands for that pipeline. The name is looked up when C<pipeline> is
called, in the caller's package unless it's qualified (see
L</Named pipelines>), and one not defined croaks.

A function whose values can be code references can't tell them from
stages with L</is_stage>, but it can take a pipeline given last as its
stages, which a caller makes with C<pipeline>:

    sub call_all (@callbacks) {
        my $stages = @callbacks && $callbacks[-1] isa 'Ekorn::Pipeline' ? pop @callbacks : pipeline();
        return $stages->(map { $_->() } @callbacks);
    }

    call_all(@callbacks, pipeline(sub { $_ * 10 }, take(2)));

It's exported on request, and new in v0.2.1.

=head3 Through a subclass

Imported through a subclass, C<pipeline> makes that subclass. With
My::Pipeline in a file of its own, C<My/Pipeline.pm>:

    package My::Pipeline;
    use parent 'Ekorn::Pipeline';
    1;

a program using it writes:

    use My::Pipeline qw(pipeline);
    pipeline('clean', take(5));    # a My::Pipeline

It's a function of its own, made for the subclass, which looks names
up in the package that calls it, as Ekorn::Pipeline's does. So a module
can import it and export it again to its own users, and names are
still looked up in theirs.

A subclass that inherits C<import> from Ekorn::Pipeline needs no code
of its own for it. A subclass with an C<import> of its own, such as
Exporter's, replaces Ekorn::Pipeline's, and so must ask for
C<pipeline> itself, from inside the subclass, and export it as it
exports anything else:

    package My::Pipeline;
    use Exporter qw(import);
    use Ekorn::Pipeline qw();

    our @ISA;
    BEGIN { @ISA = ('Ekorn::Pipeline') }

    # pipeline, made for this class, installed here, so Exporter exports it.
    BEGIN { __PACKAGE__->SUPER::import('pipeline') }

    our @EXPORT_OK = qw(pipeline);

C<@ISA> must be set in a C<BEGIN> block, before that line runs.

A package has one C<pipeline>. Importing both Ekorn::Pipeline's and a
subclass's into the same package warns that the first was redefined;
call the other by its full name, such as
C<Ekorn::Pipeline::pipeline(...)>.

=head2 is_stage

    use Ekorn::Pipeline v0.1.3 qw(is_stage);

    is_stage($thing)

True if C<$thing> can be used as a stage: a code reference (including
a stage made with L<Ekorn::Pipeline::Gather>), or a pipeline of this
class or a subclass. It's the same test L</new> uses. It's false for a
string, even the name of a pipeline.

Use it in a function that takes its stages from the end of its
arguments, so that it accepts the same stages C<new> does, pipelines
included:

    sub fetch ($url, @args) {
        my @stages;
        unshift @stages, pop @args while @args && is_stage($args[-1]);
        ...
    }

It's exported on request. It's new in v0.1.3, so ask for that version
on the C<use> line, as above: v0.1.2 has no C<import>, so without the
version, C<use Ekorn::Pipeline qw(is_stage)> compiles under it, and
fails only when C<is_stage> is called.

A pipeline is a blessed hash, so C<is_hashref> is true of one too. A
function that takes a hash reference of options before its stages
should test C<is_stage> first, or it takes a pipeline for the options.

A subclass inherits C<import>, which exports as Exporter does, so
C<use My::Pipeline qw(name)> croaks unless the subclass exports C<name>
itself; C<pipeline> is the exception, made for the subclass, as
L</Through a subclass> says.

=head2 ending

    Ekorn::Pipeline::ending()

True while the values going through the stages come from an end
function, rather than from the source. It's for code that tells its
stages more about each value, such as where it came from: a value from
an end function has no such origin. It isn't exported.

=head1 DIAGNOSTICS

=over

=item Expected stage #%d to be a code reference or a pipeline

A stage given to L</new> wasn't a code reference or a pipeline. It's
also raised for a pipeline whose overridden C<stages> method returned
something that isn't a code reference.

=item Expected stage #%d to be a code reference, a pipeline or the name of one

A stage given to L</pipeline>, or to L</named> after the name, was
none of them. For C<named>, stages are counted from the first after
the name.

=item No pipeline named %s

A name given to L</pipeline> or L</named> isn't defined in that
package for the class it was looked up for, or for any of its
ancestors. The name is given qualified, so it says which package it
was looked up in. It may be defined for a subclass, which this class
can't see (see L</Named pipelines and subclasses>), or in another
package, which a qualified name reaches.

=item A pipeline named %s is already defined

L</named> was given a name its class, the one it was called on or the
pipeline's, has already defined for another pipeline. A subclass can
define a name its ancestor has, which overrides it rather than
defining it twice (see L</Named pipelines and subclasses>).

=item Expected a name, made of words joined by ::

L</named> was given something other than a name.

=item Expected only a name, naming a pipeline you have

L</named>, on a pipeline, was given stages after the name.

=item Expected a code reference

The source given to L</iterator> wasn't a code reference.

=item Expected stage #%s, made with gather, to return a code reference or a pipeline, and optionally an end function

The block given to L<Ekorn::Pipeline::Gather/gather> for that stage
returned something else.

=item Pipeline stage #%s failed at %s line %d:

A stage, or its end function, died. The message it died with follows,
indented. An exception object is passed on unchanged.

In this message and the one above, a stage is named by its position:
C<#2> for the second stage, or C<#2.3> for the third stage of a
pipeline given as the second stage.

=back

=head1 SEE ALSO

L<Ekorn::Pipeline::Gather>, L<Ekorn::Pipeline::Stop>,
L<Ekorn::Pipeline::Pipes>, and L<DBIx::Squirrel>, where the pipeline
began

L<Ekorn::Pipeline::Manual::HowTo> shows how to do common tasks, one
recipe at a time, and L<Ekorn::Pipeline::Manual::Reference> describes
every module, function and method in full.

=head1 AUTHOR

Iain Campbell E<lt>cpanic@cpan.orgE<gt>

=head1 LICENSE

Copyright (c) 2024-2026 by Iain Campbell.

This is free software; you can redistribute it and/or modify it under the
same terms as the Perl 5 programming language system itself.

=cut
