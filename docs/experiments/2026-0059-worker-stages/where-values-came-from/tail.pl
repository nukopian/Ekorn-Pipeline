use v5.36;
use Time::HiRes qw(sleep);
use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:core :context source);
use Ekorn::Pipeline::Workers qw(in_workers once_per);
sub rows ($n) { source { my $i = 0; {step => sub { $i < $n ? 'v' . ++$i : () }, original => sub {"row $i"}} } }
my $after = sub { [$_, result_original()] };
for my $case (
    ['in_workers(4), 1000 values',                   sub { in_workers(4, sub { sleep 0.002; $_ }) }],
    ['once_per(4), 1000 distinct keys',              sub { once_per(sub {$_}, 4, sub { sleep 0.002; $_ }, join => sub ($v, @f) {$v}) }],
    ['once_per(4), 1000 rows, 50 keys',              sub { once_per(sub { $_ =~ s( \D )()xgr % 50 }, 4, sub { sleep 0.002; $_ }, join => sub ($v, @f) {$v}) }],
    ['once_per(4), one slow key first, hold 1000',   sub { once_per(sub { $_ eq 'v1' ? 'slow' : 'k' }, 4, sub { sleep($_ eq "slow" ? 0.3 : 0); $_ }, join => sub ($v, @f) {$v}) }],
    ['once_per(4), one slow key first, hold 50',     sub { once_per(sub { $_ eq 'v1' ? 'slow' : 'k' }, 4, sub { sleep($_ eq "slow" ? 0.3 : 0); $_ }, join => sub ($v, @f) {$v}, hold => 50) }],
) {
    my($name, $make) = @$case;
    my @got = Ekorn::Pipeline->new($make->(), $after)->iterator(rows(1000))->all;
    my $wrong = grep { defined $_->[1] && do { my($n) = $_->[0] =~ m( v(\d+) )x; !defined $n || $_->[1] ne "row $n" } } @got;
    printf "%-45s %4d results, %4d with no original, %d wrong\n", $name, scalar @got, scalar(grep { !defined $_->[1] } @got), $wrong;
}
