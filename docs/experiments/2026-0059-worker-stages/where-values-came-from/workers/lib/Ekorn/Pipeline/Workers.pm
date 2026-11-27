use v5.36;

package Ekorn::Pipeline::Workers;

# A prototype: stages running a block for each value in a pool of forked
# workers. Core Perl only: fork, pipes and Storable.
#
# - in_workers($n, $block): results in the order the values came;
# - in_workers_any($n, $block): results as they finish;
# - once_per($key, $n, $block, join => ...): the block run once per key,
#   in the workers, each value joined with its key's results.
#
# All three are made on Ekorn::Pipeline::Workers::Pool, below, which
# knows nothing of order or keys: it takes values tagged by its caller,
# and gives back what each finished with, tagged.

use Carp       qw(croak);
use Exporter   qw(import);
use IO::Select ();
use POSIX      ();
use Storable   qw(nfreeze thaw);
use Ekorn::Pipeline;
use Ekorn::Pipeline::Context qw(kept_origin);
use Ekorn::Pipeline::Gather qw(gather);
use Ekorn::Pipeline::Source ();
use Ekorn::Pipeline::Stop   ();

our $VERSION   = 'v0.0.1';
our @EXPORT_OK = qw(in_workers in_workers_any once_per);

# For tests: the pids of every worker forked.
our @FORKED;


sub _check_pool_args ($n, $block, $window) {
    croak 'Expected a number of workers of 1 or more'
        unless defined $n && $n =~ m( \A [1-9] \d* \z )x;
    croak 'Expected a code reference' unless ref $block eq 'CODE';
    croak 'Expected a window at least the number of workers' if $window < $n;
    return;
}


# As in_workers, but passing each value's results on as soon as they're
# back, in the order they finish, so one slow value holds up none of the
# rest.
sub in_workers_any ($n, $block, %options) {
    return in_workers($n, $block, %options, ordered => 0);
}


sub in_workers ($n, $block, %options) {
    my $window  = $options{window} // 2 * $n;
    my $ordered = $options{ordered} // 1;
    _check_pool_args($n, $block, $window);
    return gather {
        my $pool = Ekorn::Pipeline::Workers::Pool->new($n, $block);
        my @pending;     # in order: {seq, state => sent|done, kind, payload}
        my @finished;    # done, in the order they finished
        my %by_seq;
        my $next_seq = 0;

        my $collect = sub ($timeout) {
            for my $reply ($pool->poll($timeout)) {
                my($seq, $kind, $payload) = @$reply;
                my $job = $by_seq{$seq};
                @$job{qw(state kind payload)} = ('done', $kind, $payload);
                push @finished, $job;
            }
        };

        # The next finished job whose results may go on: ordered, the
        # oldest, once it's done; unordered, the first to have finished.
        my $next_done = $ordered
            ? sub () { @pending && $pending[0]{state} eq 'done' ? $pending[0] : undef }
            : sub () { $finished[0] };

        # Take the finished jobs that may go on: their results, and a
        # stop's. An error stops the taking; it's thrown once nothing
        # taken before it is left to pass on.
        my $take = sub () {
            my @results;
            while (my $job = $next_done->()) {
                return @results if $job->{kind} eq 'err' && @results;
                @pending  = grep { $_ != $job } @pending;
                @finished = grep { $_ != $job } @finished;
                delete $by_seq{ $job->{seq} };
                die $job->{payload} if $job->{kind} eq 'err';    ## no critic (ErrorHandling::RequireCarping): the worker's error as it was
                if ($job->{kind} eq 'stop') {
                    @pending = @finished = ();
                    Ekorn::Pipeline::Stop->throw(@results, $job->{origin}->gives(@{ $job->{payload} }));
                }
                push @results, $job->{origin}->gives(@{ $job->{payload} });
            }
            return @results;
        };

        my $step = sub ($value) {
            my $job = {seq => $next_seq++, state => 'sent', origin => kept_origin};
            push @pending, $job;
            $by_seq{ $job->{seq} } = $job;
            $pool->submit($job->{seq}, $value, _where());
            $collect->(0);
            # Wait while the window's full and nothing may go on yet.
            $collect->(undef) while @pending >= $window && !$next_done->();
            return $take->();
        };

        my $flush = sub () {
            my @results;
            while (@pending) {
                $collect->(undef) unless $next_done->();
                push @results, $take->();
            }
            return @results;
        };

        my $end = sub ($how) {
            $pool->shut_down($how);
            @pending = @finished = ();
            %by_seq  = ();
        };

        return {step => $step, flush => $flush, end => $end, holds => 1};
    };
}


# The block, given each distinct key once, in the workers; each value
# passed on as join gives it, from the value and its key's results. A
# key asked for while it's still being looked up waits for that lookup,
# rather than starting another. Keys are kept, with their results, for
# the run.
sub once_per ($key_of, $n, $block, %options) {
    my $window  = $options{window} // 2 * $n;    # keys in flight at most
    my $hold    = $options{hold}   // 1000;      # values waiting, before we wait
    my $ordered = $options{ordered} // 1;
    my $join    = $options{join}   // sub ($value, @found) {@found};
    croak 'Expected a code reference for the key' unless ref $key_of eq 'CODE';
    croak 'Expected a code reference to join'     unless ref $join eq 'CODE';
    _check_pool_args($n, $block, $window);
    return gather {
        my $pool = Ekorn::Pipeline::Workers::Pool->new($n, $block);
        my %found;      # key => [kind, payload], once its lookup's back
        my %asked;      # key => 1, while its lookup's in flight
        my @waiting;    # in order: [value, key]

        my $collect = sub ($timeout) {
            for my $reply ($pool->poll($timeout)) {
                my($key, $kind, $payload) = @$reply;
                $found{$key} = [$kind, $payload];
                delete $asked{$key};
            }
        };

        # The waiting values whose keys are back, joined: ordered, from
        # the oldest, stopping at the first still waiting; unordered, all
        # of them. A key's error is thrown once nothing joined before it
        # is left to pass on; its stop, with them.
        my $take = sub () {
            my(@results, @still);
            while (my $wait = shift @waiting) {
                my($value, $key, $origin) = @$wait;
                my $found = $found{$key};
                unless ($found) {
                    if ($ordered) { unshift @waiting, $wait; last }
                    push @still, $wait;
                    next;
                }
                my($kind, $payload) = @$found;
                if ($kind eq 'err') {
                    if (@results) { unshift @waiting, $wait; last }
                    die $payload;    ## no critic (ErrorHandling::RequireCarping): the worker's error as it was
                }
                if ($kind eq 'stop') {
                    @waiting = @still = ();
                    Ekorn::Pipeline::Stop->throw(@results, $origin->gives(@$payload));
                }
                local $_ = $value;
                push @results, $origin->gives($join->($value, @$payload));
            }
            unshift @waiting, @still;
            return @results;
        };

        my $step = sub ($value) {
            my $key = do { local $_ = $value; $key_of->($value) };
            croak 'Expected a key for each value, not undef' unless defined $key;
            push @waiting, [$value, $key, kept_origin];
            unless ($found{$key} || $asked{$key}) {
                $asked{$key} = 1;
                $pool->submit($key, $key, _where());
            }
            $collect->(0);
            # Wait while the window's full of keys in flight, or too many
            # values wait behind one whose key isn't back.
            $collect->(undef)
                while %asked
                && (keys %asked >= $window || (@waiting >= $hold && !$found{ $waiting[0][1] }));
            return $take->();
        };

        # Take as the keys come back, so the flush gives its values in
        # the order they could go on. An error after values taken here
        # is thrown at the next take, and they're lost with the run: a
        # flush can't pass values on and then die.
        my $flush = sub () {
            my @results;
            while (@waiting) {
                push @results, $take->();
                $collect->(undef) if @waiting;
            }
            return @results;
        };

        my $end = sub ($how) {
            $pool->shut_down($how);
            %found = %asked = ();
            @waiting = ();
        };

        return {step => $step, flush => $flush, end => $end, holds => 1};
    };
}


package Ekorn::Pipeline::Workers::Pool {

    use Carp       qw(croak);
    use IO::Select ();
    use Storable   qw(nfreeze);

    # A pool of up to $n workers, forked as they're needed, each running
    # $block on one value at a time.
    sub new ($class, $n, $block) {
        return bless {
            n       => $n,
            block   => $block,
            workers => [],                  # {pid, to, from, busy => job or undef}
            queue   => [],                  # jobs not yet sent: {tag, seq, value, where}
            select  => IO::Select->new,
            seq     => 0,
        }, $class;
    }


    # Queue $value, tagged, with where it stands in its run, and send it
    # if a worker's free, or can be forked.
    sub submit ($self, $tag, $value, $where) {
        push @{ $self->{queue} }, {tag => $tag, seq => $self->{seq}++, value => $value, where => $where};
        $self->_dispatch;
        return;
    }


    # How many values are queued or with a worker.
    sub in_flight ($self) {
        return @{ $self->{queue} } + grep { defined $_->{busy} } @{ $self->{workers} };
    }


    # The replies that are ready within $timeout seconds (undef: wait for
    # one, if any's in flight), each [tag, kind, payload]; and the
    # workers freed are sent more.
    sub poll ($self, $timeout) {
        return () unless $self->in_flight;
        my @replies;
        for my $fh ($self->{select}->can_read($timeout)) {
            my($worker) = grep { $_->{from} == $fh } @{ $self->{workers} };
            my $job   = $worker->{busy};
            my $frame = Ekorn::Pipeline::Workers::_read_frame($fh);
            if (defined $frame) {
                my(undef, $kind, $payload) = @{ Storable::thaw($frame) };
                push @replies, [$job->{tag}, $kind, $payload];
            }
            else {
                # The worker went without replying: exit, kill or crash.
                waitpid $worker->{pid}, 0;
                push @replies,
                    [$job->{tag}, err => "in_workers' worker $worker->{pid} exited, status $?, with value #$job->{seq}\n"];
                $self->{workers} = [grep { $_ != $worker } @{ $self->{workers} }];
            }
            $worker->{busy} = undef;
            $self->{select}->remove($fh);
        }
        $self->_dispatch;
        return @replies;
    }


    # However the run ended: close each worker's input, so an idle one
    # exits; kill one still working, unless the run was done.
    sub shut_down ($self, $how) {
        my @workers = @{ $self->{workers} };
        for my $worker (@workers) {
            close $worker->{to};
            kill 'TERM', $worker->{pid} if defined $worker->{busy} || $how ne 'done';
        }
        waitpid $_->{pid}, 0 for @workers;
        close $_->{from} for @workers;
        @$self{qw(workers queue)} = ([], []);
        return;
    }


    # Send queued values to idle workers, forking up to n.
    sub _dispatch ($self) {
        my $queue = $self->{queue};
        while (@$queue) {
            my($worker) = grep { !defined $_->{busy} } @{ $self->{workers} };
            $worker //= $self->_spawn if @{ $self->{workers} } < $self->{n};
            last unless $worker;
            my $job = shift @$queue;
            # Where the value stands in the run goes with it. A context or
            # an original that can't cross, such as a handle, is left
            # behind, and the block sees undef for both.
            my($seq, $value, $where) = @$job{qw(seq value where)};
            my $frame = eval { nfreeze([$seq, $value, $where]) }
                // eval { nfreeze([$seq, $value, {%$where, context => undef, original => undef}]) }
                // croak "in_workers can't send value #$seq to a worker: $@";
            Ekorn::Pipeline::Workers::_write_frame($worker->{to}, $frame)
                or croak "in_workers lost worker $worker->{pid}: $!";
            delete $job->{value};
            $worker->{busy} = $job;
            $self->{select}->add($worker->{from});
        }
        return;
    }


    sub _spawn ($self) {
        pipe(my $from_parent, my $to_worker) or croak "pipe: $!";
        pipe(my $from_worker, my $to_parent) or croak "pipe: $!";
        STDOUT->flush;
        STDERR->flush;
        my $pid = fork // croak "fork: $!";
        if ($pid == 0) {
            close $to_worker;
            close $from_worker;
            # Siblings' ends of their pipes, or they'd never see EOF.
            for my $sibling (@{ $self->{workers} }) { close $sibling->{to}; close $sibling->{from} }
            Ekorn::Pipeline::Workers::_work($self->{block}, $from_parent, $to_parent);
        }
        close $from_parent;
        close $to_parent;
        push @Ekorn::Pipeline::Workers::FORKED, $pid;
        my $worker = {pid => $pid, to => $to_worker, from => $from_worker};
        push @{ $self->{workers} }, $worker;
        return $worker;
    }
}

package Ekorn::Pipeline::Workers;


# Where the value being given to the stage stands in its run, as the
# block would see it, run in the stage: the run's context, whether a
# flush's values are going through, and the result's number and
# original. Asking for the original calls the source's original part,
# which a run otherwise calls only when a stage asks.
sub _where () {
    return {
        context  => Ekorn::Pipeline::run_context(),
        ending   => Ekorn::Pipeline::ending(),
        number   => Ekorn::Pipeline::Context::result_number(),
        original => Ekorn::Pipeline::Context::result_original(),
    };
}


# The worker's loop: read a value, run the block on it, reply, until the
# parent closes the pipe. It leaves with _exit, so the parent's END
# blocks, destructors and buffered output aren't run or written twice.
#
# The block runs inside a run of its own, made for each value, so that
# Ekorn itself gives it the parent's context, through a source, and
# ending, by calling it from a flush when the parent was ending. The
# result's number and original are set by hand, in the one variable of
# Ekorn's that isn't lexical. A stop or an error is caught around the
# block, before the inner run sees it, and sent back as it was.
sub _work ($block, $in, $out) {
    local $SIG{PIPE} = 'IGNORE';
    local $SIG{TERM} = 'DEFAULT';
    my($value, $where, $kind, $payload);
    my $call = sub () {
        my @results = eval {
            local $Ekorn::Pipeline::CURRENT_RESULT
                = defined $where->{number}
                ? [$where->{number} - 1, $where->{original}]
                : undef;
            local $_ = $value;
            $block->($value);
        };
        if (my $error = $@) {
            ($kind, $payload) = ref $error && $error isa 'Ekorn::Pipeline::Stop'
                ? (stop => [@{$error}[ 1 .. $#$error ]])
                : (err  => "$error");
            return;
        }
        ($kind, $payload) = (ok => \@results);
        return;
    };
    my $stage = Ekorn::Pipeline::Gather->new(sub {
        return (
            sub { $where->{ending} ? () : $call->() },
            sub { $where->{ending} ? $call->() : () },
        );
    });
    my $source = Ekorn::Pipeline::Source->new(sub {
        my $given = 0;
        return {step => sub { $given++ ? () : 1 }, context => $where->{context}};
    });
    my $run = Ekorn::Pipeline->new($stage);
    while (defined(my $frame = _read_frame($in))) {
        (my $seq, $value, $where) = @{ thaw($frame) };
        ($kind, $payload) = (err => "in_workers' worker ran nothing for value #$seq\n");
        $run->iterator($source)->all;
        my $reply = eval { nfreeze([$seq, $kind, $payload]) }
            // nfreeze([$seq, err => "in_workers can't send back the results of value #$seq: $@"]);
        _write_frame($out, $reply) or last;
    }
    STDOUT->flush;
    STDERR->flush;
    POSIX::_exit(0);
}


sub _write_frame ($fh, $frame) {
    my $data = pack('N', length $frame) . $frame;
    while (length $data) {
        my $wrote = syswrite $fh, $data;
        return 0 unless $wrote;
        substr $data, 0, $wrote, '';
    }
    return 1;
}


sub _read_exactly ($fh, $length) {
    my $data = '';
    while (length $data < $length) {
        my $read = sysread $fh, $data, $length - length $data, length $data;
        return undef unless $read;    ## no critic (Subroutines::ProhibitExplicitReturnUndef)
    }
    return $data;
}


sub _read_frame ($fh) {
    my $header = _read_exactly($fh, 4) // return undef;    ## no critic (Subroutines::ProhibitExplicitReturnUndef)
    return _read_exactly($fh, unpack 'N', $header);
}

1;
