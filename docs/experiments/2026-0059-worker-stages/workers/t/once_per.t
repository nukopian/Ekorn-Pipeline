use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

use File::Temp  qw(tempdir);
use Time::HiRes qw(time sleep);

use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:core :flow :sources :context source);
use Ekorn::Pipeline::Workers qw(once_per);

my $dir = tempdir(CLEANUP => 1);


sub all_reaped () {
    return !grep { kill 0, $_ } @Ekorn::Pipeline::Workers::FORKED;
}


# A block that logs each key it's given to $log, sleeps, and returns
# the key's "lookup".
sub logged_lookup ($log, $wait = 0) {
    return sub ($key) {
        open my $fh, '>>', $log or die $!;
        say {$fh} $key;
        close $fh;
        sleep(ref $wait ? $wait->($key) : $wait);
        return "geo:$key";
    };
}


sub logged ($log) {
    open my $fh, '<', $log or return ();
    return map { chomp; $_ } <$fh>;
}


# Rows, as from a CSV: an id, and a postcode shared with other rows.
my @rows = map { {id => $_, postcode => 'PC' . ($_ % 10)} } 1 .. 100;

my $enrich = sub ($row, $geo) { return {%$row, geo => $geo} };

subtest 'each key looked up once; each value joined with its key\'s results' => sub {
    my $log = "$dir/once.log";
    my @got = Ekorn::Pipeline->new(
        once_per(sub { $_->{postcode} }, 4, logged_lookup($log), join => $enrich),
    )->(@rows);
    is \@got, [map { {%$_, geo => "geo:$_->{postcode}"} } @rows], 'every row, in order, enriched';
    my @keys = logged($log);
    is [sort @keys], [sort map {"PC$_"} 0 .. 9], 'ten lookups for a hundred rows, one a key';
    ok all_reaped(), 'every worker reaped';
};

subtest 'without a join, each value becomes its key\'s results' => sub {
    is [Ekorn::Pipeline->new(once_per(sub { $_ % 3 }, 2, sub { "k$_" }))->(1 .. 6)],
        [qw(k1 k2 k0 k1 k2 k0)], 'the key\'s results';
    is [Ekorn::Pipeline->new(once_per(sub { $_ % 2 }, 2, sub { $_ ? () : ('a', 'b') }))->(1 .. 4)],
        ['a', 'b', 'a', 'b'], 'dropped, or several, as the block gives';
};

subtest 'a key asked for while it\'s in flight waits for that lookup' => sub {
    my $log = "$dir/flight.log";
    my @got = Ekorn::Pipeline->new(once_per(sub {'same'}, 4, logged_lookup($log, 0.3)))->(1 .. 20);
    is \@got, [('geo:same') x 20], 'twenty results';
    is [logged($log)], ['same'], 'from one lookup';
};

subtest 'distinct keys concurrently' => sub {
    my $start = time;
    my @got   = Ekorn::Pipeline->new(
        once_per(sub { $_->{postcode} }, 10, sub { sleep 0.2; "geo:$_" }, join => $enrich),
    )->(@rows);
    my $took = time - $start;
    is scalar @got, 100, 'every row';
    ok $took < 0.8, sprintf 'took %.2fs: ten 0.2s lookups at once, against 2s one at a time, or 20s a row', $took;
};

subtest 'unordered: a slow key holds up only its own values' => sub {
    my $slow = sub ($key) { $key eq 'PC1' ? 0.5 : 0.02 };
    my @got  = Ekorn::Pipeline->new(
        once_per(sub { $_->{postcode} }, 4, logged_lookup("$dir/any.log", $slow),
            join => $enrich, ordered => 0),
    )->(@rows);
    is [sort { $a->{id} <=> $b->{id} } @got], [map { {%$_, geo => "geo:$_->{postcode}"} } @rows],
        'every row, enriched';
    is [map { $_->{postcode} } @got[-10 .. -1]], [('PC1') x 10], 'the slow key\'s rows come last';
};

subtest 'a stop after it' => sub {
    my $log = "$dir/take.log";
    my @got = Ekorn::Pipeline->new(
        once_per(sub { $_ }, 4, logged_lookup($log, 0.05)),
        take(3),
    )->(1 .. 1000);
    is \@got, [qw(geo:1 geo:2 geo:3)], 'the first three';
    ok logged($log) <= 3 + 8, scalar(logged($log)) . ' of 1000 looked up';
    ok all_reaped(), 'every worker reaped';
};

subtest 'errors and stops in the block' => sub {
    my @seen;
    my $died = dies {
        Ekorn::Pipeline->new(
            once_per(sub { $_ % 5 }, 2, sub { die "no key $_\n" if $_ == 3; $_ }),
            sub { push @seen, $_; $_ },
        )->(1 .. 20);
    };
    like $died, qr( no\ key\ 3 )x, 'the worker\'s error';
    # Values taken in the flush before the error are lost with the run, so
    # those that went on are 1 and 2, or fewer: never one from key 3 on.
    is \@seen, [(1, 2)[0 .. $#seen]], 'only values before the first with that key went on: ' . join ',', @seen;
    is [Ekorn::Pipeline->new(once_per(sub {$_}, 1, sub { $_ == 4 ? Stop('last') : $_ }))->(1 .. 50)],
        [1, 2, 3, 'last'], 'a stop: the values before it, then its own';
    ok all_reaped(), 'every worker reaped';
};

subtest 'values wait in bounded numbers behind a slow key' => sub {
    my $peak = 0;
    my $p    = Ekorn::Pipeline->new(
        once_per(sub { $_ == 1 ? 'slow' : 'quick' }, 2, sub { sleep($_ eq 'slow' ? 0.3 : 0); $_ }, hold => 50),
    );
    my $feed = $p->feed;
    my $out  = 0;
    for my $i (1 .. 500) {
        $out += () = $feed->push($i);
        $peak = $i - $out if $i - $out > $peak;
    }
    $out += () = $feed->close;
    is $out, 500, 'every value';
    ok $peak <= 50, "at most $peak waiting at once";
};

subtest 'context in the block: the first value with the key\'s' => sub {
    my $source = source {
        my $i = 0;
        return {step => sub { $i < 4 ? ++$i : () }, context => 'COLS', original => sub {"row $i"}};
    };
    my @got = Ekorn::Pipeline->new(
        once_per(sub { $_ % 2 }, 2, sub { [Ekorn::Pipeline::run_context(), result_original()] }),
    )->iterator($source)->all;
    is \@got, [['COLS', 'row 1'], ['COLS', 'row 2'], ['COLS', 'row 1'], ['COLS', 'row 2']],
        'each value given its key\'s, from the first value that asked';
};

subtest 'nested in itself' => sub {
    my $inner = Ekorn::Pipeline->new(once_per(sub { $_ % 2 }, 2, sub { $_ * 100 }));
    my $outer = Ekorn::Pipeline->new(once_per(sub { $_ % 3 }, 3, sub ($k) { [$inner->($k, $k + 1)] }));
    is [$outer->(1 .. 6)], [map { my $k = $_ % 3; [($k % 2) * 100, (($k + 1) % 2) * 100] } 1 .. 6],
        'a lookup that runs a once_per of its own';
    ok all_reaped(), 'every worker reaped';
};

subtest 'a key that\'s undef' => sub {
    like dies { Ekorn::Pipeline->new(once_per(sub {undef}, 2, sub {$_}))->(1) },
        qr( Expected\ a\ key )x, 'croaks';
};

done_testing;
