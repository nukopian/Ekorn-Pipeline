use v5.36;
use Time::HiRes qw(time);
my $N = 2_000_000;
my %ctx = (row => [1, 'x']);
my $part = sub { $ctx{row} };
my @r = (0, 'v', $part, 0);
my $cr = \@r;
my $step = sub { return };
my %t;
sub timed ($name, $code) { my $s = time; $code->() for 1 .. $N; $t{$name} = (time - $s) / $N * 1e9 }
timed('empty loop',            sub { });
timed('a closure call',        sub { $step->(1) });
timed('list copy of 4',        sub { my(undef, $o, $p, $k) = @$cr });
timed('index reads of 3',      sub { my $o = $cr->[1]; my $p = $cr->[2]; my $k = $cr->[3] });
timed('the part call',         sub { $part->() });
timed('bless [x]',             sub { my $x = bless [1], 'Ekorn::Pipeline::Origin' });
timed('plain [x]',             sub { my $x = [1] });
timed('call with 2 args',      sub { my @v = $step->(1, $cr) });
printf "%-22s %5.0f ns\n", $_, $t{$_} - ($_ eq 'empty loop' ? 0 : $t{'empty loop'}) for sort { $t{$a} <=> $t{$b} } keys %t;
