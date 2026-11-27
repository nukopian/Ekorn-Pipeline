use v5.36;
use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:core :context source);
use Ekorn::Pipeline::Workers qw(in_workers);
my $src = source { my $i = 0; return {step => sub { $i < 3 ? ++$i : () }, context => 'COLS', original => sub { "orig$i" }} };
my $p = Ekorn::Pipeline->new(in_workers(2, sub { my $r = eval { join '/', $_, Ekorn::Pipeline::run_context() // 'undef', result_number() // 'undef', result_original() // 'undef' }; $r // "ERR[$@]" }));
say 'in the block:  ', join ' ', $p->iterator($src)->all;
say 'after it:      ', join ' ', Ekorn::Pipeline->new(in_workers(2, sub { $_ }), sub { join '/', $_, result_number() // 'undef', result_original() // 'undef' })->iterator($src)->all;
say 'plain stage:   ', join ' ', Ekorn::Pipeline->new(sub { join '/', $_, Ekorn::Pipeline::run_context() // 'undef', result_number() // 'undef', result_original() // 'undef' })->iterator($src)->all;
