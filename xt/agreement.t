use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

# A run gives the same values however it's run: pushed, pulled a value
# at a time, read with all, or fed a value at a time and closed, as the
# reference promises; and each result the same original, the one it was
# made from, or each way dies with the same error. Random pipelines from
# xt/lib/RandomPipelines.pm (roadmap 2026-0062), ending in a sink or
# not, are run each way, from a source with an original part, by a
# pipeline made fresh, and again by the one pipeline after the ways
# before it, as a stop or a death mustn't leave anything behind for the
# next run (2026-0053's F16 and 2026-0062's D1). Each case is made from a seed of its own, printed
# with a failure: EKORN_AGREEMENT_CASE set to it runs that case alone.

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

# What each value reaching the end was, and its original, in the order
# they came; and each whose original it wasn't made from: the way being
# run sets both.
my(@log, @wrong);


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


# Return a case made from a seed: its pipeline, the values it's run
# over, and what it is, for a failure's message. The same seed makes
# the same case, fresh.
sub make_case ($seed) {
    srand $seed;
    my($stages, $names) = random_stages(number => \&_number);
    # A case's values are all different, so a value with an original,
    # holding any of them, was made from it only if the original is one:
    # a stage that holds values back mustn't give the latest value's
    # (2026-0060). One holding none, as a nested collect of nothing, has
    # nothing to tell.
    my $note = sub ($value) {
        my $original = result_original;
        my @leaves   = _leaves($value);
        my $shown    = _shown($value) . ':' . _shown($original);
        push @log, $shown;
        push @wrong, $shown
            if defined $original && @leaves && !grep { $_ == $original } @leaves;
        return $value;
    };
    my @stages = (@$stages, $note);
    my @named  = @$names;
    if (rand > 0.4) {
        my($sink, $name) = $sinks[rand @sinks]->();
        push @stages, $sink;
        push @named,  $name;
    }
    my @all    = 0 .. 9;
    my @values = map { splice @all, rand @all, 1 } 1 .. int rand 8;
    return (Ekorn::Pipeline->new(@stages), \@values, join ', ', @named);
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

my %ways = (
    pushed => sub ($pipeline, @values) { $pipeline->(@values) },
    all    => sub ($pipeline, @values) {
        $pipeline->iterator(from_values(@values))->all;
    },
    pulled => sub ($pipeline, @values) {
        my $next = $pipeline->iterator(from_values(@values));
        my @pulled;
        while (my($value) = $next->()) { push @pulled, $value }
        return @pulled;
    },
    fed => sub ($pipeline, @values) {
        my $feed = $pipeline->feed;
        my @fed;
        for my $value (@values) {
            push @fed, $feed->push($value);
            last if defined $feed->ended;
        }
        push @fed, $feed->close unless defined $feed->ended;
        return @fed;
    },
);
my @ways = sort keys %ways;


# Run a pipeline one way, returning what it gave and the log, or the
# error it died with and the log so far, and any value whose original
# it wasn't made from.
sub run_way ($way, $pipeline, $values) {
    @log = @wrong = ();
    my @got;
    my $died = !eval { @got = $ways{$way}->($pipeline, @$values); 1 };
    # A death's message names the line that ran the way, so not that.
    my $what
        = $died
        ? 'died: ' . ($@ =~ s( \ at\ \S+\ line\ \d+ )()xgr =~ s( \n )( )xgr)
        : _shown(@got);
    my $wrong = @wrong ? " | not made from its original: @wrong" : '';
    return "$what | @log$wrong";
}

# Each case's seed, drawn first, so a case is made the same whatever
# the cases before it did with rand.
my @seeds = defined $ONE ? ($ONE) : map { int rand 2**31 } 1 .. $CASES;

my $failed = 0;
for my $seed (@seeds) {
    my($pipeline, $values, $named) = make_case($seed);
    my %got;
    for my $way (@ways) {
        $got{"$way, fresh"} = run_way($way, (make_case($seed))[0], $values);
        $got{"$way, again"} = run_way($way, $pipeline, $values);
    }
    my @differ = grep { $got{$_} ne $got{'pushed, fresh'} } keys %got;
    next if !@differ && $got{'pushed, fresh'} !~ m( not\ made\ from )x;
    $failed++;
    fail "seed $seed: (@$values) through $named";
    diag "    $_: $got{$_}" for sort keys %got;
    last if $failed >= 5;
}
ok !$failed, scalar(@seeds) . " pipelines agree every way, from seed $SEED";

done_testing;
