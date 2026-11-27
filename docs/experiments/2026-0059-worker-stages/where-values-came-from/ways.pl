use v5.36;
use Ekorn::Pipeline;
use Ekorn::Pipeline::Stages::Taps qw(tee);
use Ekorn::Pipeline::Tooling qw(:core :flow :batch :context :sinks source);
use Ekorn::Pipeline::Context qw(kept_origin);
my $seen = sub { "$_<-" . (result_original() // '-') };
sub ob () { gather { my @h; { step => sub { push @h, [$_[0], kept_origin]; @h > 1 ? map { $_->[1]->gives($_->[0]) } shift @h : () },
  flush => sub () { map { $_->[1]->gives($_->[0]) } splice @h }, holds => 1 } } }
sub rev2 () { gather { my @h; my $give = sub () { map { $_->[1]->gives($_->[0]) } reverse splice @h };
  { step => sub { push @h, [$_[0], kept_origin]; @h >= 2 ? $give->() : () }, flush => $give, holds => 1 } } }
my $split = sub { ("${_}a", "${_}b") };
my $stopat = sub { $_ =~ /4/ ? Stop("$_!", "$_?") : $_ };
my @pipes = (
  [ob(), $split, $seen], [rev2(), $split, $seen], [$split, rev2(), $seen], [rev2(), rev2(), $seen],
  [ob(), $stopat, $seen], [rev2(), $stopat, $seen], [$stopat, rev2(), $seen], [take_last, $seen],
  [ob(), tee(rev2(), sub {$_}), $seen], [rev2(), $split], [ob(), rev2()],
);
my $i = 0;
for my $st (@pipes) {
  $i++;
  my $mk = sub { Ekorn::Pipeline->new(@$st) };
  my @src = (1..6);
  my @all = do { my @s = @src; $mk->()->iterator(sub { @s ? shift @s : () })->all };
  my @nxt = do { my @s = @src; my $it = $mk->()->iterator(sub { @s ? shift @s : () }); my @o; while (my ($v) = $it->next) { push @o, $v } @o };
  my @push = $mk->()->(@src);
  my @feed = do { my $f = $mk->()->feed; my @o; for (@src) { last if defined $f->ended; push @o, $f->push($_) } (@o, defined $f->ended ? () : $f->close) };
  my $ok = "@all" eq "@nxt" && "@all" eq "@push" && "@all" eq "@feed";
  say "$i ", ($ok ? "same" : "DIFF"), ": @all";
  say "   next: @nxt\n   push: @push\n   feed: @feed" unless $ok;
}
