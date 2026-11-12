use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

# The design's proofs (docs/design/DESIGN.md, section 19), run against
# the prototype on pipeline-experimental: a source joined directly to a
# sink, and a complete pipeline used as a source. And the pattern that
# lets a package such as DBIx::Squirrel use Ekorn as it is: a source of
# its own that knows something, and a stage of its own that asks it
# (Q21).

use Carp       qw(croak);
use File::Temp qw(tempdir);
use Ekorn::Pipeline;
use Ekorn::Pipeline::Factories qw(stage source sink);
use Ekorn::Pipeline::Operators;
use Ekorn::Pipeline::Sinks   qw(count first_value to_array to_file);
use Ekorn::Pipeline::Sources qw(from_file);
use Ekorn::Pipeline::Stages::Flow;

my $class = 'Ekorn::Pipeline';
my $dir   = tempdir(CLEANUP => 1);

# What the parts below were told, in order.
my @log;

# A source of the values given, logging its set-up, how many values it
# was asked for, and how its run ended.
sub spy_source (@values) {
    return source {
        push @log, 'source set-up';
        my @remaining = @values;
        return (
            sub () { push @log, 'pull'; @remaining ? shift @remaining : () },
            sub ($how) { push @log, "source $how" },
        );
    };
}

# A sink giving every value, logging its set-up and how its run ended.
sub spy_sink () {
    return sink {
        push @log, 'sink set-up';
        my @all;
        return (
            sub ($value) { push @all, $value; return },
            sub ($how) { push @log, "sink $how"; @all },
        );
    };
}


sub drain ($next) {
    my @values;
    while (my($value) = $next->()) { push @values, $value }
    return @values;
}


sub write_file ($name, $content) {
    my $path = "$dir/$name";
    open my $fh, '>', $path or croak "Can't write $path: $!";
    print { $fh } $content;
    close $fh or croak "Can't write $path: $!";
    return $path;
}


sub read_file ($path) {
    open my $fh, '<', $path or croak "Can't read $path: $!";
    local $/ = undef;
    my $content = readline $fh;
    close $fh or croak "Can't read $path: $!";
    return $content;
}

subtest '19.1 A source joined directly to a sink' => sub {
    my $from = write_file('a.txt', "one\ntwo\nthree\n");

    subtest 'it copies, and gives how many records' => sub {
        my($n) = $class->new(to_file("$dir/b.txt"))->iterator(from_file($from))->();
        is $n,                      3,                   'pulled, through an iterator';
        is read_file("$dir/b.txt"), "one\ntwo\nthree\n", 'record for record';
        is from_file($from) | to_file("$dir/c.txt"), 3,  'and with |';
        is read_file("$dir/c.txt"), read_file("$dir/b.txt"), 'the same';
    };

    subtest 'a last line without a newline gains one' => sub {
        my $short = write_file('short.txt', "x\ny");
        is from_file($short) | to_file("$dir/short-copy.txt"), 2;
        is read_file("$dir/short-copy.txt"),                   "x\ny\n";
    };

    subtest 'run out: both told done, the source last' => sub {
        @log = ();
        my @result = drain($class->new(spy_sink)->iterator(spy_source(1, 2)));
        is \@result, [1, 2];
        is \@log,
            [
                'source set-up', 'sink set-up', 'pull', 'pull', 'pull', 'sink done',
                'source done',
            ];
    };

    subtest 'stopped by first_value: the source stopped, after one value' =>
        sub {
            @log = ();
            my($first) = $class->new(first_value)->iterator(spy_source(1, 2, 3))->();
            is $first, 1;
            is \@log,  ['source set-up', 'pull', 'source stopped'];
            is spy_source(7, 8) | first_value, 7, 'and with |';
        };

    subtest "a sink that can't be set up: the source told died" => sub {
        @log = ();
        like dies {
            $class->new(to_file("$dir/no/such/dir/b.txt"))->iterator(spy_source(1))
        },
            qr( \A Can't\ write\ \S+/no/such/dir/b\.txt: )x;
        is \@log, ['source set-up', 'source died'];
    };

    subtest
        'a sink that dies on a value: both told died, and the error thrown' => sub {
            @log = ();
            my $fails = sink {
                return (
                    sub ($value) { die "No room\n" },
                    sub ($how) { push @log, "sink $how" },
                );
            };
            like dies { drain($class->new($fails)->iterator(spy_source(1, 2))) },
            qr( \A Pipeline\ stage\ \#1\ failed .* No\ room )xs;
            is \@log, ['source set-up', 'pull', 'sink died', 'source died'];
        };

    subtest 'both forms agree' => sub {
        @log = ();
        my $by_iterator
            = ($class->new(count)->iterator(spy_source(1, 2, 3))->())[0];
        my @iterator_log = @log;
        @log = ();
        my $by_operator = spy_source(1, 2, 3) | count;
        is $by_operator, $by_iterator,   'the same result';
        is \@log,        \@iterator_log, 'the same ends';
    };
};

subtest 'An end that dies (Q6)' => sub {
    subtest 'while the run is dying: a warning, keeping the first error' =>
        sub {
            @log = ();
            my $fails = sink {
                return (sub ($value) { croak 'First' }, sub ($how) { croak 'Second' });
            };
            my $warnings = warnings {
                like dies { drain($class->new($fails)->iterator(spy_source(1))) },
                qr( First )x;
            };
            is scalar @$warnings, 1;
            like $warnings->[0], qr( \A An\ end\ died .* dying:\ Second )x;
            is \@log, ['source set-up', 'pull', 'source died'],
            'and the source is still told';
        };

    subtest 'as the run ends: thrown, once the rest are told it died' => sub {
        @log = ();
        my $fails = sink {
            return (sub ($value) { return }, sub ($how) { croak 'Full' });
        };
        like dies { drain($class->new($fails, spy_sink)->iterator(spy_source(1))) },
            qr( Full )x;
        is \@log,
            ['source set-up', 'sink set-up', 'pull', 'pull', 'sink died',
                'source died'];
    };
};

subtest '19.2 A complete pipeline as a source' => sub {
    subtest 'the inner run ends at the first pull' => sub {
        @log = ();
        my $lines
            = $class->new(stage { uc }, spy_sink)->iterator(spy_source(qw(a b c)));
        my $next = $class->new(take(2))->iterator($lines);
        is [$next->()], ['A'];
        is \@log,
            [
                'source set-up', 'sink set-up', 'pull', 'pull', 'pull', 'pull',
                'sink done',     'source done',
            ],
            'its source and sink told done, before the outer run has its first value';
        is [drain($next)], ['B'], 'take(2) then stops the outer run';
        is scalar @log,    8,     "and the inner's parts, ended, aren't told again";
    };

    subtest "a die in the outer run doesn't reach the inner" => sub {
        @log = ();
        my $lines = $class->new(spy_sink)->iterator(spy_source(1, 2));
        my $next
            = $class->new(sub { $_ == 2 ? croak 'Two' : $_ })->iterator($lines);
        is [$next->()], [1];
        like dies { $next->() }, qr( Two )x;
        is \@log,
            [
                'source set-up', 'sink set-up', 'pull', 'pull', 'pull', 'sink done',
                'source done',
            ];
    };

    subtest 'a result of one value is a source of one value' => sub {
        my $counted = $class->new(count)->iterator(spy_source(qw(a b c)));
        is [drain($class->new->iterator($counted))], [3];
    };

    subtest 'without a sink, the inner run is pulled only as needed' => sub {
        @log = ();
        my $lines = $class->new(stage { uc })->iterator(spy_source(qw(a b c d)));
        is [drain($class->new(take(2))->iterator($lines))], [qw(A B)];
        is \@log, ['source set-up', 'pull', 'pull', 'source stopped'],
            'two pulls, and the inner source told stopped by the outer stop';
    };

    subtest 'abandoned, it ends' => sub {
        @log = ();
        {
            my $lines = $class->new(stage { uc })->iterator(spy_source(qw(a b c)));
            my $next  = $class->new->iterator($lines);
            $next->();
        }
        is \@log, ['source set-up', 'pull', 'source stopped'],
            'let go after one pull';
    };

    subtest 'with |, a chain of a complete pipeline is a result' => sub {
        is spy_source(qw(a b)) | stage { uc } | to_array, [qw(A B)],
            'to_array gives a reference';
    };
};

# A package outside Ekorn's namespace, standing for DBIx::Squirrel: a
# source of rows that knows its columns, and a stage that asks the run's
# source for them. It uses Ekorn as it is: nothing subclassed or wrapped.
package My::Table {
    use Ekorn::Pipeline;
    use Ekorn::Pipeline::Operators;
    use overload '|' => \&Ekorn::Pipeline::Operators::chain;


    sub new ($class, $columns, @rows) {
        return bless {columns => $columns, rows => \@rows, log => []}, $class;
    }


    sub columns ($self) {
        return @{ $self->{columns} };
    }


    sub for_run ($self) {
        my $i = 0;
        return (
            sub () { $i < @{ $self->{rows} } ? $self->{rows}[$i++] : () },
            sub ($how) { push @{ $self->{log} }, $how },
        );
    }


    sub column ($name) {
        return sub ($row) {
            my @columns = Ekorn::Pipeline::run_source()->columns;
            my($at) = grep { $columns[$_] eq $name } 0 .. $#columns;
            return $row->[$at];
        };
    }
}

subtest 'A package delivers parts, using Ekorn as it is (Q21)' => sub {
    my $people
        = My::Table->new([qw(id name)], [1, 'Ann'], [2, 'Bo'], [3, 'Cy']);

    is [drain($class->new(My::Table::column('name'))->iterator($people))],
        [qw(Ann Bo Cy)],
        'its stage asks its source for the columns';
    is $people->{log}, ['done'], 'its source is told how the run ended';

    is $people | My::Table::column('name') | take(2) | to_array, [qw(Ann Bo)],
        "with |, composed with Ekorn's parts";
    is $people->{log}, ['done', 'stopped'], 'told stopped by take(2)';

    my $inner = $class->new(My::Table::column('id'))->iterator($people);
    is [
        drain(
            $class->new(sub { [$_, scalar Ekorn::Pipeline::run_source()] })
                ->iterator($inner))
        ],
        [[1, exact_ref($inner)], [2, exact_ref($inner)], [3, exact_ref($inner)]],
        "in a pipeline pulled from another, a stage sees its own run's source";
};

done_testing;
