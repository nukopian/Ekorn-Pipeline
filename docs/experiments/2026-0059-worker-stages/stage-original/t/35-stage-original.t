use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

# A prototype: a gather's original part, as a source's (roadmap
# 2026-0052), for the stages after it.

use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:core :flow :sources :sinks :context source);

# Rows from a source with an original part: each value is a row's name,
# and its original the row.
sub rows ($n = 4) {
    return source {
        my $i = 0;
        return {step => sub { $i < $n ? 'v' . ++$i : () }, original => sub { "row $i" }};
    };
}


# What a stage sees: its value, and the original it's given.
my $seen = sub { "$_ <- " . (result_original() // 'undef') };

# A stage that holds each value back by one, giving the one before, and
# says where what it gives came from: the original it kept with it. Its
# flush gives the last.
sub one_behind ($with_part = 1) {
    return gather {
        my($held, $held_original, $given_original);
        return {
            step => sub ($value) {
                my @give = defined $held ? ($held) : ();
                $given_original = $held_original if @give;
                ($held, $held_original) = ($value, result_original());
                return @give;
            },
            flush => sub () {
                $given_original = $held_original;
                return defined $held ? ($held) : ();
            },
            ($with_part ? (original => sub () {$given_original}) : ()),
        };
    };
}

subtest 'the stages after it get its answer' => sub {
    my @got = Ekorn::Pipeline->new(one_behind(), $seen)->iterator(rows())->all;
    is \@got, ['v1 <- row 1', 'v2 <- row 2', 'v3 <- row 3', 'v4 <- undef'],
        'each value its own original; the flush\'s undef, as ever';
};

subtest 'without the part, as now' => sub {
    my @got = Ekorn::Pipeline->new(one_behind(0), $seen)->iterator(rows())->all;
    is \@got, ['v1 <- row 2', 'v2 <- row 3', 'v3 <- row 4', 'v4 <- undef'],
        'the original of the latest value, one behind';
};

subtest 'the stage itself, and those before it, get the source\'s' => sub {
    my @before;
    my $before = sub { push @before, result_original(); $_ };
    my @got    = Ekorn::Pipeline->new($before, one_behind(), $seen)->iterator(rows(3))->all;
    is \@before, ['row 1', 'row 2', 'row 3'], 'before it';
    is \@got, ['v1 <- row 1', 'v2 <- row 2', 'v3 <- undef'], 'after it';
};

subtest 'a value it splits keeps its answer, through the stages after' => sub {
    my $split = sub { ("$_.a", "$_.b") };
    my @got   = Ekorn::Pipeline->new(one_behind(), $split, $seen)->iterator(rows(3))->all;
    is \@got, ['v1.a <- row 1', 'v1.b <- row 1', 'v2.a <- row 2', 'v2.b <- row 2', 'v3.a <- undef', 'v3.b <- undef'],
        'each piece, its value\'s';
};

subtest 'a later stage with a part of its own answers from there on' => sub {
    my $tag = gather {
        my $given;
        return {step => sub ($v) { $given = "tagged $v"; $v }, original => sub () {$given}};
    };
    my @mid;
    my $mid = sub { push @mid, result_original(); $_ };
    my @got = Ekorn::Pipeline->new(one_behind(), $mid, $tag, $seen)->iterator(rows(3))->all;
    is \@mid, ['row 1', 'row 2', undef], 'between them, the first\'s';
    is \@got, ['v1 <- tagged v1', 'v2 <- tagged v2', 'v3 <- undef'], 'after the second, its own';
};

subtest 'pushed, with no source part' => sub {
    is [Ekorn::Pipeline->new(one_behind(), $seen)->(qw(a b c))], ['a <- a', 'b <- b', 'c <- undef'],
        'the value it was made from';
    is [Ekorn::Pipeline->new(one_behind(0), $seen)->(qw(a b c))], ['a <- b', 'b <- c', 'c <- undef'],
        'without the part: the latest value pushed, as now';
};

subtest 'fed' => sub {
    my $feed = Ekorn::Pipeline->new(one_behind(), $seen)->feed;
    my @got  = map { $feed->push($_) } qw(a b c);
    push @got, $feed->close;
    is \@got, ['a <- a', 'b <- b', 'c <- undef'], 'as pushed';
};

subtest 'what a stop carries, the stage that stopped gave' => sub {
    my $stops = gather {
        my $last;
        return {
            step     => sub ($v) { $last = "stopped at $v"; $v eq 'v2' ? Stop("$v!") : $v },
            original => sub () {$last},
        };
    };
    is [Ekorn::Pipeline->new($stops, $seen)->iterator(rows())->all],
        ['v1 <- stopped at v1', 'v2! <- stopped at v2'], 'its answer for the stop\'s values';
};

subtest 'an iterator read as a source passes on the answer for its last value' => sub {
    my $inner = Ekorn::Pipeline->new(one_behind());
    my @got   = Ekorn::Pipeline->new($seen)->iterator($inner->iterator(rows(3)))->all;
    is \@got, ['v1 <- row 1', 'v2 <- row 2', 'v3 <- row 3'],
        'the stage\'s answer, for its flush\'s value too: D3 holds only inside the run flushing, as now';
    my $plain = Ekorn::Pipeline->new(sub {$_});
    is [Ekorn::Pipeline->new($seen)->iterator($plain->iterator(rows(2)))->all],
        ['v1 <- row 1', 'v2 <- row 2'], 'with no stage part, the source\'s part, as now';
};

subtest 'by name only, from a gather, a gather returning a pipeline, and EKORN_STAGE' => sub {
    my $part = sub {'from the part'};
    my $as_list = gather { (sub {$_}, undef, undef) };
    is [Ekorn::Pipeline->new($as_list, $seen)->(1)], ['1 <- 1'], 'a list has no part';
    my $wrapping = gather { {step => Ekorn::Pipeline->new(sub { $_ * 2 }), original => $part} };
    is [Ekorn::Pipeline->new($wrapping, $seen)->(1)], ['2 <- from the part'], 'a gather returning a pipeline';
    my $object = bless {}, 'Local::Stage';
    no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
    *{'Local::Stage::EKORN_STAGE'} = sub ($self) { {step => sub { $_[0] }, original => $part} };
    is [Ekorn::Pipeline->new($object, $seen)->(1)], ['1 <- from the part'], 'a class\'s EKORN_STAGE';
};

subtest 'a part that isn\'t a code reference croaks, naming the stage' => sub {
    like dies { Ekorn::Pipeline->new(sub {$_}, gather { {step => sub {$_}, original => 'x'} })->(1) },
        qr( \AExpected\ stage\ \#2's\ original\ to\ be\ a\ code\ reference )x, 'at #2';
};

subtest 'not called until asked' => sub {
    my $calls = 0;
    my $counted = gather { {step => sub {$_}, original => sub { $calls++ }} };
    Ekorn::Pipeline->new($counted, sub {$_})->(1 .. 5);
    is $calls, 0, 'never, when no stage asks';
};

subtest 'nested in itself' => sub {
    my $inner = Ekorn::Pipeline->new(one_behind(), $seen);
    my $outer = Ekorn::Pipeline->new(
        one_behind(),
        sub ($v) { [Ekorn::Pipeline->new(one_behind(), $seen)->iterator(rows(2))->all, $seen->()] },
    );
    is [$outer->iterator(rows(2))->all],
        [['v1 <- row 1', 'v2 <- undef', 'v1 <- row 1'], ['v1 <- row 1', 'v2 <- undef', 'v2 <- undef']],
        'a run inside its stage answers for itself, and leaves the outer run\'s';
};

done_testing;
