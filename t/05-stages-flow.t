use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

use Ekorn::Pipeline;
use Ekorn::Pipeline::Stages::Flow qw(:all);

my $class = 'Ekorn::Pipeline';

# Return every value an iterator hands out.
sub drain ($next) {
    my @xs;
    while (my($x) = $next->()) { push @xs, $x }
    return \@xs;
}

# Return a source handing out @xs one per call, and a reference to the
# number of times it was called.
sub source (@xs) {
    my $calls = 0;
    return sub { $calls += 1; @xs ? shift @xs : () }, \$calls;
}

subtest 'what is exported' => sub {

    package Defaults {    ## no critic (Modules::ProhibitMultiplePackages)
        use Ekorn::Pipeline::Stages::Flow;
        ::ok __PACKAGE__->can($_), "$_ by default" for qw(take drop);
        ::ok !__PACKAGE__->can($_), "not $_"
            for qw(take_first take_last take_single take_while drop_while);
    }

    package All {         ## no critic (Modules::ProhibitMultiplePackages)
        use Ekorn::Pipeline::Stages::Flow qw(:all);
        ::ok __PACKAGE__->can($_), "$_ with :all"
            for qw(
                take drop take_first take_last take_single take_while
                drop_while);
    }

    package None {        ## no critic (Modules::ProhibitMultiplePackages)
        use Ekorn::Pipeline::Stages::Flow ();
        ::ok !__PACKAGE__->can($_), "not $_ with ()"
            for qw(take drop take_while drop_while);
    }
};

subtest 'take' => sub {
    is [$class->new(take(2))->(qw(a b c d))], [qw(a b)], 'the first values';
    is [$class->new(take(5))->(qw(a b))],     [qw(a b)], 'or all there are';
    is [$class->new(take(0))->(qw(a b))],     [],        'or none';
    is [$class->new(take(2))->()],            [],        'from none';

    my($src, $calls) = source(qw(a b c d));
    my $next = $class->new(take(2))->iterator($src);
    is drain($next), [qw(a b)], 'pulled';
    is $$calls,      2,         'without asking for the value after';
};

subtest 'take_first, take_last and take_single' => sub {
    is [$class->new(take_first)->(qw(a b c))], [qw(a)], 'take_first: the first';
    is [$class->new(take_first)->()],          [],      'or none';
    my($src, $calls) = source(qw(a b c d));
    is drain($class->new(take_first)->iterator($src)), [qw(a)], 'pulled';
    is $$calls, 1, 'asking for nothing after';

    is [$class->new(take_last)->(qw(a b c))], [qw(c)], 'take_last: the last';
    is [$class->new(take_last)->()],          [],      'or none';
    is [$class->new(take_last, sub { uc })->(qw(a b))], [qw(B)],
        'and the stages after it go on';
    is [$class->new(take_last)->(qw(a b))], [qw(b)], 'afresh on each run';
    is [$class->new(take(2), take_last)->(qw(a b c))], [qw(b)],
        'the last to reach it, if the run is stopped before it';

    is [$class->new(take_single)->(qw(a))], [qw(a)], 'take_single: the one';
    is [$class->new(take_single)->()],      [],      'or none';
    my @out;
    my $warnings = warnings { @out = $class->new(take_single)->(qw(a b c)) };
    is \@out,             [qw(a)], 'given more, the first';
    is scalar @$warnings, 1,       'and a warning, once';
    like $warnings->[0],
        qr( \A Expected\ only\ one\ item,\ but\ there\ were\ more )x;
    ($src, $calls) = source(qw(a b c d));
    $warnings = warnings { drain($class->new(take_single)->iterator($src)) };
    is $$calls, 2, 'pulled, it stops at the second';
};

subtest 'drop' => sub {
    is [$class->new(drop(2))->(qw(a b c d))], [qw(c d)], 'the values after';
    is [$class->new(drop(5))->(qw(a b))],     [],        'or none';
    is [$class->new(drop(0))->(qw(a b))],     [qw(a b)], 'or all';
    is [$class->new(drop(1), take(2))->(qw(a b c d))], [qw(b c)],
        'and with take, a page';
};

subtest 'take and drop start afresh on each run' => sub {
    my $p = $class->new(drop(1), take(2));
    is [$p->(qw(a b c d))], [qw(b c)], 'the first run';
    is [$p->(qw(e f g h))], [qw(f g)], 'the second';
};

subtest 'take_while' => sub {
    my @seen;
    my $p = $class->new(take_while { push @seen, $_; $_ < 3 });
    is [$p->(1 .. 5, 1)], [1, 2], 'the values until one fails';
    is \@seen, [1, 2, 3],
        'given each in $_, and stopped at the first that fails';

    my($src, $calls) = source(1 .. 5);
    my $next = $class->new(take_while { $_ < 3 })->iterator($src);
    is drain($next), [1, 2], 'pulled';
    is $$calls,      3,      'without asking for the value after';

    is [$class->new(take_while sub ($x) { $x ne 'c' })->(qw(a b c))],
        [qw(a b)], 'as its argument too';
};

subtest 'drop_while' => sub {
    my @seen;
    my $p = $class->new(drop_while { push @seen, $_; $_ < 3 });
    is [$p->(1 .. 5, 1)], [3, 4, 5, 1], 'the values from the first that fails';
    is \@seen,            [1, 2, 3],    'asking no more once one has';
    is [$p->(1, 4, 1)],   [4, 1],       'starting afresh on each run';
};

subtest 'counts are checked when the stage is made' => sub {
    for my $bad (-1, 1.5, 'x', '', undef, "\x{0663}", "3\n") {
        # A digit of another script is named by its code point, such as U+0663
        my $shown
            = ($bad // 'undef') =~ s( ([^\x00-\x7f]) )( sprintf 'U+%04X', ord $1 )xger;
        for my $fn (\&take, \&drop) {
            my $line = __LINE__ + 1;
            is dies { $fn->($bad) },
                "Expected a count of 0 or more at ${\ __FILE__ } line $line.\n",
                "$shown";
        }
    }
    # Past the prototype, as nothing else can give them anything but code
    for my $fn (\&take_while, \&drop_while) {
        my $line = __LINE__ + 1;
        is dies { $fn->('x') },
            "Expected a code reference at ${\ __FILE__ } line $line.\n",
            'and tests';
    }
};

done_testing;
