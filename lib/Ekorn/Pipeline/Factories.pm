use v5.36;

package Ekorn::Pipeline::Factories;

use Exporter                qw(import);
use Ekorn::Pipeline::Gather qw();
use Ekorn::Pipeline::Sink   qw();
use Ekorn::Pipeline::Source qw();
use Ekorn::Pipeline::Stage  qw();

our @EXPORT_OK   = qw(stage gather source sink_one sink_many);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

*gather = \&Ekorn::Pipeline::Gather::gather;

# Return a Stage of the block given.
sub stage : prototype(&) ($code) {
    return Ekorn::Pipeline::Stage->new($code);
}


# Return a Source made for each run by the set-up given.
sub source : prototype(&) ($setup) {
    return Ekorn::Pipeline::Source->new($setup);
}


# Return a Sink made for each run by the set-up given, its result one
# value.
sub sink_one : prototype(&) ($setup) {
    return Ekorn::Pipeline::Sink->new_sink_one($setup);
}


# Return a Sink made for each run by the set-up given, its result a
# list.
sub sink_many : prototype(&) ($setup) {
    return Ekorn::Pipeline::Sink->new_sink_many($setup);
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Factories - words that make Ekorn's types (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
