use v5.36;
use Time::HiRes qw(time);
use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:core :sources :context source);
my $N = 300_000;
my $counted = gather { my $n = 0; return (sub { $n++; $_[0] }, sub { () }) };   # a flush: the full loop
my $split   = sub { ($_[0], $_[0]) };                                         # values wait on @todo
my $part_src = sub { source { my $i = 0; { step => sub { $i < $N ? ++$i : () }, original => sub { $i } } } };
my %cases = (
    'pulled, a stage with a flush'              => sub { Ekorn::Pipeline->new($counted, sub { $_[0] })->iterator(counter(1))->next for 1; Ekorn::Pipeline->new(sub { $_[0] }, $counted)->iterator($part_src->())->all },
    'pulled, values split onto the queue'       => sub { Ekorn::Pipeline->new($split, $counted)->iterator($part_src->())->all },
    'pushed, a stage with a flush'              => sub { Ekorn::Pipeline->new(sub { $_[0] }, $counted)->(1 .. $N) },
    'pulled, asking result_original each value' => sub { Ekorn::Pipeline->new($counted, sub { result_original() })->iterator($part_src->())->all },
);
for my $name (sort keys %cases) {
    my @t;
    for (1 .. 7) { my $s = time; $cases{$name}->(); push @t, time - $s }
    @t = sort { $a <=> $b } @t;
    printf "%-44s %6.1f ns a value (median of 7)\n", $name, $t[3] / $N * 1e9;
}
