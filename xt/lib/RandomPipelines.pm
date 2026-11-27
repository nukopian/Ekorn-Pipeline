use v5.36;

package RandomPipelines;

# Random pipelines, for tests that run them every way and compare what
# each gives (roadmap 2026-0062's D2). The stages are Ekorn-Pipeline's,
# so this file is kept there; DBIx-Squirrel copies it as it is, for its
# 2026-0066, and a change either project wants to it goes to the other
# as a message. A copy names here the Ekorn-Pipeline commit it came
# from.
#
# Its contract:
#
# - It makes stages and their names, and nothing else: the test brings
#   the source, any sink, and the ways it runs them.
# - Values are opaque. A stage keeps a value, drops it, repeats it,
#   wraps it in an array reference, or holds it back, and never looks
#   inside it, but for the caller's number function, which gives any
#   value a whole number, and which the stages choosing by value ask
#   (a filter, a stop, a death). So it's given the caller's values,
#   and array references of them, nested.
# - It's driven by the caller's srand, and calls rand only as it makes
#   stages, never as they run, so the same seed makes the same stages:
#   the test prints the seed, so a failure can be made again.
# - The caller may add makers of its own, of the same form as those
#   below, such as DBIx-Squirrel's nested statement run.
#
# A maker is a hash: make, a sub given the pipeline's settings and
# returning a stage and its name; and nests, true if make asks for a
# pipeline of its own, which it does with $settings->{inner}, getting
# the stages and their names. A maker that nests is left out at the
# deepest level.

use Exporter qw(import);

use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:all);

our @EXPORT_OK = qw(random_stages);

my $DEEPEST = 2;


# Return stages' names, joined, as one name.
sub _named ($names) {
    return join ', ', @$names;
}


# Return a pipeline of random stages, and its name, for a maker that
# nests.
sub _inner ($settings) {
    my($stages, $names) = $settings->{inner}->();
    return (Ekorn::Pipeline->new(@$stages), _named($names));
}

my @MAKERS = (
    {make => sub ($s) { my $n = int rand 6;     (take($n),  "take($n)") }},
    {make => sub ($s) { my $n = int rand 4;     (drop($n),  "drop($n)") }},
    {make => sub ($s) { my $n = 1 + int rand 3; (batch($n), "batch($n)") }},
    {
        make => sub ($s) { (collect { [@_] }, 'collect') },
    },
    {make => sub ($s) { (take_last, 'take_last') }},
    {
        make => sub ($s) { (sub ($v) { [$v] }, 'wrap it') },
    },
    {
        make => sub ($s) { (sub ($v) { ($v, $v) }, 'repeat it') },
    },
    {
        make => sub ($s) {
            my $number = $s->{number};
            (sub ($v) { $number->($v) % 2 ? $v : () }, 'the odd');
        },
    },
    {
        make => sub ($s) {
            my($number, $at) = ($s->{number}, int rand 8);
            my $stop = sub ($v) { $number->($v) == $at ? Stop($v, [$v]) : $v };
            ($stop, "a stop at $at");
        },
    },
    {
        make => sub ($s) {
            my($number, $at) = ($s->{number}, int rand 8);
            # With die, as the message is the same whichever way it's run.
            my $die = sub ($v) {
                $number->($v) == $at ? die "died at $at\n" : $v;    ## no critic (ErrorHandling::RequireCarping)
            };
            ($die, "a death at $at");
        },
    },
    {
        make => sub ($s) {
            my $n      = int rand 4;
            my $gather = gather {
                Ekorn::Pipeline->new(take($n), sub ($v) { $v })
            };
            ($gather, "a gather of take($n)");
        },
    },
    {
        nests => 1,
        make  => sub ($s) {
            my($stages, $names) = $s->{inner}->();
            (tee(@$stages), 'a tee of (' . _named($names) . ')');
        },
    },
    {
        nests => 1,
        make  => sub ($s) {
            my($inner, $name) = _inner($s);
            my $gather = gather { $inner };
            ($gather, "a gather of ($name)");
        },
    },
    {
        nests => 1,
        make  => sub ($s) {
            my($inner, $name) = _inner($s);
            (sub ($v) { $inner->($v) }, "a run of ($name) in a step");
        },
    },
    {
        nests => 1,
        make  => sub ($s) {
            my($inner, $name) = _inner($s);
            my $one_behind = gather {
                my @held;    # [value, origin]
                my $give = sub ($held) { $held->[1]->gives($inner->($held->[0])) };
                return {
                    step => sub ($v) {
                        push @held, [$v, kept_origin];
                        return @held > 1 ? $give->(shift @held) : ();
                    },
                    flush => sub () {
                        map { $give->($_) } splice @held;
                    },
                    holds => 1,
                };
            };
            ($one_behind, "one behind, through a run of ($name)");
        },
    },
);


# Return random stages, and their names, as two array references.
# Settings: number, the caller's number function (required); makers,
# more makers; and the fewest and most stages, from and to.
sub random_stages (%settings) {
    my $number = $settings{number} // die "random_stages needs a number function\n";
    my @makers = (@MAKERS, @{ $settings{makers} // [] });
    my($from, $to, $depth) = map { $settings{$_} } qw(from to depth);
    ($from, $to, $depth) = ($from // 1, $to // 4, $depth // 0);
    my @here  = $depth < $DEEPEST ? @makers : grep { !$_->{nests} } @makers;
    my %inner = (
        %settings,
        number => $number,
        from   => 1,
        to     => 2,
        depth  => $depth + 1,
    );
    my $s = {number => $number, inner => sub () { random_stages(%inner) }};
    my(@stages, @names);
    for (1 .. $from + int rand($to - $from + 1)) {
        my($stage, $name) = $here[rand @here]{make}->($s);
        push @stages, $stage;
        push @names,  $name;
    }
    return (\@stages, \@names);
}

1;
