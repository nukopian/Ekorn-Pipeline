use v5.36;
use Time::HiRes qw(time sleep);
use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:core :context source);
use Ekorn::Pipeline::Workers qw(in_workers);
for my $n (1, 2, 4, 8, 16) {
    my $t = time;
    Ekorn::Pipeline->new(in_workers($n, sub { sleep 0.1; $_ }))->(1 .. 32);
    printf "n=%-2d  %.2fs\n", $n, time - $t;
}
my $t = time;
Ekorn::Pipeline->new(in_workers(4, sub { $_ }))->(1 .. 20000);
printf "overhead: %.1f us a value (20000 trivial values, 4 workers)\n", (time - $t) / 20000 * 1e6;
my $src = source { my $i = 0; return {step => sub { $i < 3 ? ++$i : () }, context => 'COLS', original => sub { "orig$i" }} };
say 'in the block:  ', join ' ', Ekorn::Pipeline->new(in_workers(2, sub { join '/', $_, run_context() // 'undef', result_number() // 'undef', result_original() // 'undef' }))->iterator($src)->all;
say 'after it:      ', join ' ', Ekorn::Pipeline->new(in_workers(2, sub { $_ }), sub { join '/', $_, result_number() // 'undef', result_original() // 'undef' })->iterator($src)->all;
