use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

use Time::HiRes qw(time);

use Ekorn::Pipeline;
use Ekorn::Pipeline::Gather  qw(gather);
use Ekorn::Pipeline::Sources qw(from_arrayref);

# A run's time grows in proportion to its values, where a flush puts many
# of them on its queue at once. A maintainers' test, as it times: four
# times the values should take about four times as long, and the test
# allows twice that, where time in n squared would take sixteen. Found
# by DBIx-Squirrel's session, in a task of 2026-11-12, after the queue
# was scanned for each value reaching the end.

my $class = 'Ekorn::Pipeline';

# Return a gather holding every value, and letting them all out at once.
sub hold_all () {
    return gather {
        my @held;
        return (sub ($value) { push @held, $value; return }, sub () { splice @held });
    };
}


# Return the shortest of three timings of $run, given $n values.
sub fastest ($run, $n) {
    my $best;
    for (1 .. 3) {
        my $start = time;
        $run->($n);
        my $took = time - $start;
        $best = $took if !defined $best || $took < $best;
    }
    return $best;
}


my %runs = (
    pushed => sub ($n) {
        my @out = $class->new(hold_all, sub { $_ })->(1 .. $n);
    },
    pulled => sub ($n) {
        my @out = $class->new(hold_all, sub { $_ })
            ->iterator(from_arrayref([1 .. $n]))
            ->all;
    },
);

for my $how (sort keys %runs) {
    my $small = fastest($runs{$how}, 5_000);
    my $large = fastest($runs{$how}, 20_000);
    my $ratio = $large / ($small || 1e-6);
    ok $ratio < 8,
        sprintf
        'a flush then a stage, %s: four times the values took %.1f times as long',
        $how, $ratio;
}

done_testing;
