use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

use Time::HiRes qw(sleep);

use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:core :context source);
use Ekorn::Pipeline::Workers qw(in_workers in_workers_any once_per);

# Values v1, v2, ... from a source whose original for each is "row N".
sub rows ($n) {
    return source {
        my $i = 0;
        return {step => sub { $i < $n ? 'v' . ++$i : () }, original => sub {"row $i"}};
    };
}


# After the stage: each result, with the original it's given.
my $after = sub { [$_, result_original()] };

for my $case (
    ['in_workers',     sub { in_workers(4, sub { sleep rand 0.02; "$_ done" }) }],
    ['in_workers_any', sub { in_workers_any(4, sub { sleep rand 0.02; "$_ done" }) }],
    ['once_per',       sub { once_per(sub {$_}, 4, sub { sleep rand 0.02; "$_ done" }, join => sub ($v, @f) {@f}) }],
) {
    my($name, $make) = @$case;
    subtest "a stage after $name gets each value's own original" => sub {
        my @got = Ekorn::Pipeline->new($make->(), $after)->iterator(rows(40))->all;
        is scalar @got, 40, 'every value';
        my @given = grep { defined $_->[1] } @got;
        my @wrong = grep { my($n) = $_->[0] =~ m( \A v(\d+) )x; $_->[1] ne "row $n" } @given;
        is \@wrong, [], 'none given another value\'s';
        my $flushed = @got - @given;
        # The window, 8, bounds in_workers' tail; once_per's is bounded by its
        # hold, 8 here, and one more: a step adds a value before it waits.
        is $flushed, 0, 'none without its original, the flush\'s included';
    };
}

subtest 'once_per, rows sharing a key: each its own, not the first\'s' => sub {
    my @got = Ekorn::Pipeline->new(once_per(sub { substr $_, -1 }, 2, sub {"key $_"}, join => sub ($v, $k) {"$v/$k"}), $after)
        ->iterator(rows(30))->all;
    my @wrong = grep { defined $_->[1] && do { my($n) = $_->[0] =~ m( \A v(\d+) )x; $_->[1] ne "row $n" } } @got;
    is \@wrong, [], 'each row its own original';
};

done_testing;
