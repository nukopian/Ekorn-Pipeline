use v5.36;
use Time::HiRes qw(time);
use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:core :sources source);
my $N = 400_000;
# batch as Ekorn has it, with holds as the core being measured reads it,
# and without.
sub my_batch ($size, $holds) {
    return gather {
        my @batch;
        return {
            step  => sub { push @batch, $_[0]; @batch < $size ? () : [splice @batch] },
            flush => sub () { @batch ? [splice @batch] : () },
            ($holds ? (holds => 1) : ()),
        };
    };
}
my $src = sub { source { my $i = 0; { step => sub { $i < $N ? ++$i : () }, original => sub {$i} } } };
my %case = (
    'batch, no holds' => sub { Ekorn::Pipeline->new(sub { $_[0] }, my_batch(100, 0))->iterator($src->())->all },
    'batch, holds'    => sub { Ekorn::Pipeline->new(sub { $_[0] }, my_batch(100, 1))->iterator($src->())->all },
);
for my $name (sort keys %case) {
    my @t;
    for (1 .. 9) { my $s = time; $case{$name}->(); push @t, time - $s }
    @t = sort { $a <=> $b } @t;
    printf "%-18s %6.1f ns a value\n", $name, $t[4] / $N * 1e9;
}
