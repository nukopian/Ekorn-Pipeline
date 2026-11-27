use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

use File::Temp  qw(tempdir);
use Time::HiRes qw(time sleep);

use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:core :flow :sources :sinks :context source);
use Ekorn::Pipeline::Workers qw(in_workers in_workers_any);

my $dir = tempdir(CLEANUP => 1);


# Every worker forked so far has been reaped: none is alive, and none is
# a zombie waiting for us.
sub all_reaped () {
    return !grep { kill 0, $_ } @Ekorn::Pipeline::Workers::FORKED;
}


# The values a block was started on, as the workers logged them.
sub started ($log) {
    open my $fh, '<', $log or return ();
    return map { chomp; $_ } <$fh>;
}


subtest 'the same results as the block run in the stage, in order' => sub {
    my $block = sub ($x) { sleep rand 0.05; $x * 10 };
    my @want  = map { $block->($_) } 1 .. 40;
    my @got   = Ekorn::Pipeline->new(in_workers(4, $block))->(1 .. 40);
    is \@got, \@want, 'in the order the values came';
    ok all_reaped(), 'every worker reaped';
};

subtest 'faster, for work that waits' => sub {
    my $slow  = sub ($x) { sleep 0.2; $x };
    my $start = time;
    my @got   = Ekorn::Pipeline->new(in_workers(8, $slow))->(1 .. 16);
    my $took  = time - $start;
    is \@got, [1 .. 16], 'all the values';
    ok $took < 1.2, sprintf 'took %.2fs, against 3.2s run in the stage', $took;
};

subtest 'drops and many, as a stage can' => sub {
    my @got = Ekorn::Pipeline->new(in_workers(3, sub ($x) { $x % 2 ? () : ($x, $x) }))->(1 .. 8);
    is \@got, [2, 2, 4, 4, 6, 6, 8, 8], 'odd values dropped, even ones doubled';
    is [Ekorn::Pipeline->new(in_workers(3, sub { $_ + 1 }))->(1, 2)], [2, 3], '$_ is the value';
};

subtest 'nothing forked for a run without values' => sub {
    my $before = @Ekorn::Pipeline::Workers::FORKED;
    is [Ekorn::Pipeline->new(in_workers(4, sub { $_ }))->()], [], 'no results';
    is scalar @Ekorn::Pipeline::Workers::FORKED, $before, 'no worker forked';
};

subtest 'a stop after it cuts the work short, and kills the workers' => sub {
    my $log = "$dir/take.log";
    my $block = sub ($x) {
        open my $fh, '>>', $log or die $!;
        say {$fh} $x;
        close $fh;
        sleep 0.05;
        $x;
    };
    my $start = time;
    my @got   = Ekorn::Pipeline->new(in_workers(4, $block), take(3))->(1 .. 1000);
    is \@got, [1, 2, 3], 'the first three';
    my @started = started($log);
    ok @started <= 3 + 8, scalar(@started) . ' of 1000 started: no more than the window past the stop';
    ok all_reaped(), 'every worker reaped';
};

subtest 'a source is told it was stopped, and read only as needed' => sub {
    my($pulled, $how) = (0);
    my $source = source {
        my $i = 0;
        return (sub { $pulled++; $i < 1000 ? ++$i : () }, sub ($h) { $how = $h });
    };
    my $iterator = Ekorn::Pipeline->new(in_workers(4, sub { $_ }), take(5))->iterator($source);
    is [$iterator->all], [1 .. 5], 'five values';
    is $how, 'stopped', 'the source told it was stopped';
    ok $pulled < 20, "$pulled pulls of 1000";
};

subtest 'an error in the block kills the run, in its place' => sub {
    my @seen;
    my $block = sub ($x) { die "bad value $x\n" if $x == 5; $x };
    my $died  = dies {
        Ekorn::Pipeline->new(in_workers(4, $block), sub { push @seen, $_; $_ })->(1 .. 20);
    };
    like $died, qr( bad\ value\ 5 )x, 'the worker\'s error';
    is \@seen, [1 .. 4], 'the values before it went on, as they would have';
    ok all_reaped(), 'every worker reaped';
};

subtest 'a stop in the block stops the run, with its values' => sub {
    my $block = sub ($x) { $x == 4 ? Stop('last') : $x };
    is [Ekorn::Pipeline->new(in_workers(3, $block))->(1 .. 50)], [1, 2, 3, 'last'],
        'the values before it, then the stop\'s';
    ok all_reaped(), 'every worker reaped';
};

subtest 'a worker that dies hard is an error, not a hang' => sub {
    my $block = sub ($x) { POSIX::_exit(3) if $x == 2; $x };
    my $died  = dies { Ekorn::Pipeline->new(in_workers(2, $block))->(1 .. 6) };
    like $died, qr( worker\ \d+\ exited,\ status\ 768,\ with\ value\ \#1 )x, 'says which value';
    ok all_reaped(), 'every worker reaped';
};

subtest 'values and results that can\'t cross a process' => sub {
    like dies { Ekorn::Pipeline->new(in_workers(2, sub { $_ }))->(sub { 1 }) },
        qr( can't\ send\ value\ \#0 )x, 'a code reference given';
    like dies { Ekorn::Pipeline->new(in_workers(2, sub { sub { 1 } }))->(1) },
        qr( can't\ send\ back\ the\ results\ of\ value\ \#0 )x, 'a code reference returned';
    ok all_reaped(), 'every worker reaped';
};

subtest 'an iterator let go ends its workers' => sub {
    my $iterator = Ekorn::Pipeline->new(in_workers(4, sub { sleep 0.05; $_ }))
        ->iterator(counter(1));
    is $iterator->next, 1, 'the first value';
    undef $iterator;
    ok all_reaped(), 'every worker reaped';
};

subtest 'fed a value at a time' => sub {
    my $feed = Ekorn::Pipeline->new(in_workers(2, sub { $_ * 2 }))->feed;
    my @got  = map { $feed->push($_) } 1 .. 5;
    push @got, $feed->close;
    is \@got, [2, 4, 6, 8, 10], 'all of them, by the close at the latest';
};

subtest 'nested in itself' => sub {
    my $inner = Ekorn::Pipeline->new(in_workers(2, sub { $_ + 1 }));
    my $outer = Ekorn::Pipeline->new(in_workers(3, sub ($x) { [$inner->($x, $x * 10)] }));
    is [$outer->(1 .. 4)], [[2, 11], [3, 21], [4, 31], [5, 41]], 'workers running workers';
    ok all_reaped(), 'every worker reaped';
};

subtest 'two runs of one pipeline at once have their own workers' => sub {
    my $p  = Ekorn::Pipeline->new(in_workers(2, sub { $_ * 3 }));
    my $i1 = $p->iterator(from_array(1 .. 5));
    my $i2 = $p->iterator(from_array(10 .. 12));
    my @got = ($i1->next, $i2->next, $i1->next, $i2->all, $i1->all);
    is \@got, [3, 30, 6, 33, 36, 9, 12, 15], 'interleaved, each in its order';
};

# What a stage sees of where its value stands in the run.
my $where = sub ($x) {
    return [
        $x,
        Ekorn::Pipeline::run_context(),
        Ekorn::Pipeline::ending() ? 1 : 0,
        result_number(),
        result_original(),
    ];
};


# A source of three values, with a context and an original for each.
sub numbers_with_originals ($context = 'COLS') {
    return source {
        my $i = 0;
        return {
            step     => sub { $i < 3 ? ++$i : () },
            context  => $context,
            original => sub { "row $i" },
        };
    };
}


# A stage giving the values it's given, then two more from its flush.
my $and_two_more = gather {
    return (sub { $_ }, sub { ('late', 'later') });
};

subtest 'the block sees where its value stands, as it would in the stage' => sub {
    for my $case (
        ['an iterator with a context and originals', sub ($s) { Ekorn::Pipeline->new($s)->iterator(numbers_with_originals())->all }],
        ['a pushed run',                             sub ($s) { Ekorn::Pipeline->new($s)->(1 .. 3) }],
        ['values from a flush before it',            sub ($s) { Ekorn::Pipeline->new($and_two_more, $s)->iterator(numbers_with_originals())->all }],
        ['after a stage that drops some',            sub ($s) { Ekorn::Pipeline->new(sub { $_ == 2 ? () : $_ }, $s)->iterator(numbers_with_originals())->all }],
        ['fed, from inside a stage of a run with a context', sub ($s) {
            my $feed;
            my $outer = Ekorn::Pipeline->new(gather {
                $feed = Ekorn::Pipeline->new($s)->feed;
                return (sub { $feed->push($_) }, sub { $feed->close });
            });
            $outer->iterator(numbers_with_originals('OUTER'))->all;
        }],
    ) {
        my($name, $run) = @$case;
        # The number aside: run in the stage, it counts the results that have
        # left the run; in a worker, those that had when the value arrived,
        # as the next results are still being made.
        my $but_number = sub (@seen) { [map { [@{$_}[0 .. 2, 4]] } @seen] };
        is $but_number->($run->(in_workers(2, $where))), $but_number->($run->($where)), "$name: context, ending and original";
        my @arrived;
        my $then = Ekorn::Pipeline->new(sub { push @arrived, result_number(); $_ }, in_workers(2, $where));
        is [map { $_->[3] } $run->($then)], \@arrived, "$name: the number when the value arrived";
    }
    ok all_reaped(), 'every worker reaped';
};

subtest 'a run inside the block counts its own, and leaves the outer count' => sub {
    my $block = sub ($x) {
        my @inner = Ekorn::Pipeline->new(sub { result_number() })->('a', 'b');
        return [@inner, result_number(), Ekorn::Pipeline::run_context()];
    };
    my $run = sub ($s) { Ekorn::Pipeline->new($s)->iterator(numbers_with_originals())->all };
    is [map { [@{$_}[0, 1, 3]] } $run->(in_workers(2, $block))], [map { [@{$_}[0, 1, 3]] } $run->($block)], "its own count, and the outer context, as in the stage";
};

subtest 'a context that can\'t cross a process is left behind' => sub {
    open my $fh, '<', $0 or die $!;
    my @arrived;
    my @got = Ekorn::Pipeline->new(sub { push @arrived, result_number(); $_ }, in_workers(2, $where))
        ->iterator(numbers_with_originals($fh))->all;
    is [map { $_->[1] } @got], [undef, undef, undef], 'undef for the context';
    is [map { $_->[4] } @got], [undef, undef, undef], 'and for the original';
    is [map { $_->[3] } @got], \@arrived, "the numbers still sent";
};

subtest 'unordered: the same results, as they finish' => sub {
    my $block = sub ($x) { sleep($x == 1 ? 0.5 : 0.02); $x * 10 };
    my @got   = Ekorn::Pipeline->new(in_workers_any(4, $block))->(1 .. 12);
    is [sort { $a <=> $b } @got], [map { $_ * 10 } 1 .. 12], 'every result, once';
    is $got[-1], 10, 'the slow value\'s last, not first';
    ok all_reaped(), 'every worker reaped';
};

subtest 'unordered: one slow value holds up none of the rest' => sub {
    my $block = sub ($x) { sleep($x == 1 ? 1 : 0.1); $x };
    my %took;
    for my $make (['ordered', \&in_workers], ['unordered', \&in_workers_any]) {
        my($name, $stage) = @$make;
        my $start = time;
        Ekorn::Pipeline->new($stage->(4, $block))->(1 .. 40);
        $took{$name} = time - $start;
    }
    note sprintf 'ordered %.2fs, unordered %.2fs', @took{qw(ordered unordered)};
    ok $took{unordered} < $took{ordered} - 0.25,
        sprintf 'unordered %.2fs, against ordered %.2fs', @took{qw(unordered ordered)};
};

subtest 'unordered: a stop after it takes the first to finish' => sub {
    my $block = sub ($x) { sleep($x <= 4 ? 0.5 : 0.02); $x };
    my @got = Ekorn::Pipeline->new(in_workers_any(8, $block), take(3))->(1 .. 1000);
    is scalar @got, 3, 'three';
    ok !(grep { $_ <= 4 } @got), "the quick ones: @got";
    ok all_reaped(), 'every worker reaped';
};

subtest 'unordered: drops, many, and the flush' => sub {
    my @got = Ekorn::Pipeline->new(in_workers_any(3, sub ($x) { $x % 2 ? () : ($x, $x) }))->(1 .. 8);
    is [sort { $a <=> $b } @got], [2, 2, 4, 4, 6, 6, 8, 8], 'odd values dropped, even ones doubled';
};

subtest 'unordered: errors and stops' => sub {
    my $died = dies { Ekorn::Pipeline->new(in_workers_any(4, sub { die "bad $_\n" if $_ == 5; $_ }))->(1 .. 20) };
    like $died, qr( bad\ 5 )x, 'the worker\'s error';
    my @got = Ekorn::Pipeline->new(in_workers_any(1, sub { $_ == 4 ? Stop('last') : $_ }))->(1 .. 50);
    is \@got, [1, 2, 3, 'last'], 'one worker: the values before the stop, then its own';
    my $hard = dies { Ekorn::Pipeline->new(in_workers_any(2, sub { POSIX::_exit(3) if $_ == 2; $_ }))->(1 .. 6) };
    like $hard, qr( worker\ \d+\ exited )x, 'a worker that dies hard';
    ok all_reaped(), 'every worker reaped';
};

subtest 'unordered: each result with its own value\'s context' => sub {
    my $block = sub ($x) { sleep rand 0.05; [$x, Ekorn::Pipeline::run_context(), result_original()] };
    my @got = Ekorn::Pipeline->new(in_workers_any(3, $block))->iterator(numbers_with_originals())->all;
    is [sort { $a->[0] <=> $b->[0] } @got], [map { [$_, 'COLS', "row $_"] } 1 .. 3], 'whatever the order';
};

subtest 'unordered: fed, and nested in itself' => sub {
    my $feed = Ekorn::Pipeline->new(in_workers_any(2, sub { $_ * 2 }))->feed;
    my @got  = map { $feed->push($_) } 1 .. 5;
    push @got, $feed->close;
    is [sort { $a <=> $b } @got], [2, 4, 6, 8, 10], 'fed, by the close at the latest';
    my $inner = Ekorn::Pipeline->new(in_workers_any(2, sub { $_ + 1 }));
    my $outer = Ekorn::Pipeline->new(in_workers_any(3, sub ($x) { [sort { $a <=> $b } $inner->($x, $x * 10)] }));
    is [sort { $a->[0] <=> $b->[0] } $outer->(1 .. 4)], [[2, 11], [3, 21], [4, 31], [5, 41]], 'workers running workers';
    ok all_reaped(), 'every worker reaped';
};

done_testing;
