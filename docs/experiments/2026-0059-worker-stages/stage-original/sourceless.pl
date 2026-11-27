use v5.36;
use Time::HiRes qw(sleep);
use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:core :context);
use Ekorn::Pipeline::Workers qw(in_workers once_per);
my $after = sub { "$_ <- " . (result_original() // 'undef') };
my $double = sub { $_ * 2 };
for my $case (
    ['no stage part, pushed', sub { Ekorn::Pipeline->new($double, $after) }],
    ['in_workers, pushed',    sub { Ekorn::Pipeline->new($double, in_workers(2, sub { sleep rand 0.02; $_ + 1 }), $after) }],
    ['once_per, pushed',      sub { Ekorn::Pipeline->new($double, once_per(sub { $_ % 3 }, 2, sub { "k$_" }, join => sub ($v, $k) { "$v/$k" }), $after) }],
) {
    my($name, $make) = @$case;
    say sprintf '%-24s pushed: %s', $name, join ', ', $make->()->(1 .. 4);
    my $feed = $make->()->feed;
    say sprintf '%-24s fed:    %s', '', join ', ', (map { $feed->push($_) } 1 .. 4), $feed->close;
}
