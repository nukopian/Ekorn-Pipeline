use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

# A run gives the same results however it's run: pushed, pulled a value
# at a time, read with all, or fed a value at a time and closed, as the
# reference promises. The same values, each with the same number and
# the original it was made from, the same ends told the same, and the
# same way of ending; or each way dies with the same error. Random
# pipelines from xt/lib/RandomPipelines.pm, ending in a sink or not, are
# run each way, from a source with an original part, by a pipeline made
# fresh, again by the one pipeline after the ways before it, as a stop
# or a death mustn't leave anything behind for the next run, and on the
# full path, which the shorter way a plain run takes must agree with;
# and, without a sink, pushed in scalar context, counting the results
# (roadmap 2026-0053's F16, and 2026-0062's D1 and D4). Each case is
# made from a seed of its own, printed with a failure:
# EKORN_AGREEMENT_CASE set to it runs that case alone.

use FindBin qw($Bin);
use lib "$Bin/lib";

use Ekorn::Pipeline;
use Ekorn::Pipeline::Factories qw(source);
use Ekorn::Pipeline::Tooling   qw(:all);
use RandomPipelines            qw(random_stages);

my $CASES = $ENV{EKORN_AGREEMENT_CASES} // 3000;
my $SEED  = $ENV{EKORN_AGREEMENT_SEED}  // 20260062;
my $ONE   = $ENV{EKORN_AGREEMENT_CASE};
srand $SEED;

my @sinks = (
    sub { (keep_all,    'keep_all') },
    sub { (count_items, 'count_items') },
    sub { (keep_first,  'keep_first') },
    sub { (keep(2),     'keep(2)') },
);

# What the way being run did, in the order it came: each value
# reaching the end, with its number and original, and what each end
# was told; and each value whose original it wasn't made from.
my(@log, @wrong);

# A stage of ours, among the random ones: one with an end, noting how
# it's told the run ended (2026-0022's D16 and D20).
my @makers = ({
    make => sub ($settings) {
        my $ends = gather {
            return {
                step => sub ($value) { $value },
                end  => sub ($how) { push @log, "end:$how"; return },
            };
        };
        ($ends, 'an end');
    },
});


# A value as a number: a batch's size, or the number itself.
sub _number ($value) {
    return ref $value ? scalar @$value : $value;
}


# Return the numbers in a value, however deep in array references.
sub _leaves ($value) {
    return ref $value ? map { _leaves($_) } @$value : $value;
}


# A value, or a list of them, as text to compare.
sub _shown (@values) {
    return join ',',
        map { ref $_ ? '[' . _shown(@$_) . ']' : $_ // 'undef' } @values;
}


# Whether a value was made from its original. A case's values are all
# different, so a number is its own original, and an array reference,
# holding any, was made from its original only if the original is one:
# a stage that holds values back mustn't give the latest value's
# (2026-0060), nor drop a value's own, as take_last's (its D7). An
# array reference may have none, as a batch has, and one holding no
# numbers, as a nested collect of nothing, has nothing to tell.
sub _made_from ($value, $original) {
    return defined $original && $value == $original unless ref $value;
    my @leaves = _leaves($value);
    return !defined $original || !@leaves || grep { $_ == $original } @leaves;
}


# A stage that does nothing but has an end, so a run with it takes the
# full path, not the shorter way a plain run does, which must give the
# same (2026-0032's D2, 2026-0040's D1 and 2026-0041's D3).
my $full = gather {
    return {step => sub ($value) { $value }, end => sub ($how) { return }};
};

# Return a case made from a seed: its pipeline, the values it's run
# over, what it is, for a failure's message, and whether it ends in a
# sink. The same seed makes the same case, fresh, and on the full path
# if asked, by the stage that takes it last before any sink, so the
# stages keep their places, which a death's message names.
sub make_case ($seed, $on_full = 0) {
    srand $seed;
    my($stages, $names) = random_stages(number => \&_number, makers => \@makers);
    my $note = sub ($value) {
        my $original = result_original;
        my $shown
            = '#' . result_number . ' ' . _shown($value) . ':' . _shown($original);
        push @log,   $shown;
        push @wrong, $shown unless _made_from($value, $original);
        return $value;
    };
    my @stages = (@$stages, $note, $on_full ? $full : ());
    my @named  = @$names;
    if (rand > 0.4) {
        my($sink, $name) = $sinks[rand @sinks]->();
        push @stages, $sink;
        push @named,  $name;
    }
    my @all    = 0 .. 9;
    my @values = map { splice @all, rand @all, 1 } 1 .. int rand 8;
    my $sunk   = @named > @$names;
    return (Ekorn::Pipeline->new(@stages), \@values, join(', ', @named), $sunk);
}


# A source of the values, whose original part gives the value it gave
# last, as a pushed value is its own original.
sub from_values (@values) {
    return source {
        my $given;
        return {
            step     => sub () { return unless @values; $given = shift @values; $given },
            original => sub () { $given },
        };
    };
}


# Run a way's run, noting how its iterator or feed says it ended, and
# passing on any death.
sub try_ended ($run, $ended, $code) {
    my $died  = !eval { $code->(); 1 };
    my $error = $@;
    $$ended = $run->ended // 'undef';
    die $error if $died;    ## no critic (ErrorHandling::RequireCarping)
    return;
}

# Each way runs a pipeline over the values, noting in $ended how the
# run ended, as its iterator or feed says, and anything more it gives
# once it has.
my %ways = (
    pushed => sub ($pipeline, $ended, @values) { $pipeline->(@values) },
    all    => sub ($pipeline, $ended, @values) {
        my $iterator = $pipeline->iterator(from_values(@values));
        my @all;
        try_ended($iterator, $ended, sub () { @all = $iterator->all });
        return @all;
    },
    pulled => sub ($pipeline, $ended, @values) {
        my $next = $pipeline->iterator(from_values(@values));
        my @pulled;
        my $pull = sub () {
            while (my($value) = $next->()) { push @pulled, $value }
        };
        try_ended($next, $ended, $pull);
        # An ended iterator gives nothing more (2026-0002's D1).
        my @more = $next->();
        $$ended .= ', then gave ' . _shown(@more) if @more;
        return @pulled;
    },
    fed => sub ($pipeline, $ended, @values) {
        my $feed = $pipeline->feed;
        my @fed;
        my $push = sub () {
            for my $value (@values) {
                push @fed, $feed->push($value);
                last if defined $feed->ended;
            }
            push @fed, $feed->close unless defined $feed->ended;
        };
        try_ended($feed, $ended, $push);
        # An ended feed takes nothing more (2026-0044's D5).
        $$ended .= ', then took a push' if eval { $feed->push(0); 1 };
        return @fed;
    },
);
my @ways = sort keys %ways;


# Run a pipeline one way, returning what it gave and the log, or the
# error it died with and the log so far; any value whose original it
# wasn't made from; and how it ended, if the way can say.
sub run_way ($way, $pipeline, $values) {
    @log = @wrong = ();
    my($ended, @got);
    my $died = !eval { @got = $ways{$way}->($pipeline, \$ended, @$values); 1 };
    # A death's message names the line that ran the way, so not that.
    my $what
        = $died
        ? 'died: ' . ($@ =~ s( \ at\ \S+\ line\ \d+ )()xgr =~ s( \n )( )xgr)
        : _shown(@got);
    my $wrong = @wrong ? " | not made from its original: @wrong" : '';
    return ("$what | @log$wrong", $ended);
}

# Each case's seed, drawn first, so a case is made the same whatever
# the cases before it did with rand.
my @seeds = defined $ONE ? ($ONE) : map { int rand 2**31 } 1 .. $CASES;

# Return what each way gave a case, and how each that can say ended.
sub try_case ($seed, $pipeline, $values, $sunk) {
    my(%got, %ended);
    for my $way (@ways) {
        for my $when ('fresh', 'again', 'on the full path') {
            my $run
                = $when eq 'again' ? $pipeline
                : $when eq 'fresh' ? (make_case($seed))[0]
                :                    (make_case($seed, 1))[0];
            my($got, $ended) = run_way($way, $run, $values);
            $got{"$way, $when"}   = $got;
            $ended{"$way, $when"} = $ended if $way ne 'pushed';
        }
    }
    # Without a sink, a pipeline pushed in scalar context gives how many
    # results it gives in a list (2026-0003's D1), or dies the same.
    if (!$sunk) {
        my $count = eval { scalar((make_case($seed))[0]->(@$values)) };
        my $list  = eval { my @list = (make_case($seed))[0]->(@$values); scalar @list };
        $got{counted}
            = ($count // -1) == ($list // -1)
            ? $got{'pushed, fresh'}
            : 'counted '
            . ($count // 'a death')
            . ', but listed '
            . ($list // 'a death');
    }
    return (\%got, \%ended);
}

my $failed = 0;
for my $seed (@seeds) {
    my($pipeline, $values, $named, $sunk) = make_case($seed);
    my($got, $ended) = try_case($seed, $pipeline, $values, $sunk);
    my $first  = $got->{'pushed, fresh'};
    my $how    = $ended->{'all, fresh'};
    my @differ = (
        (grep { $got->{$_} ne $first } keys %$got),
        (grep { $ended->{$_} ne $how } keys %$ended),
    );
    next if !@differ && $first !~ m( not\ made\ from )x;
    $failed++;
    fail "seed $seed: (@$values) through $named";
    for my $way (sort keys %$got) {
        my $said = exists $ended->{$way} ? " | ended: $ended->{$way}" : '';
        diag "    $way: $got->{$way}$said";
    }
    last if $failed >= 5;
}
ok !$failed, scalar(@seeds) . " pipelines agree every way, from seed $SEED";

done_testing;
