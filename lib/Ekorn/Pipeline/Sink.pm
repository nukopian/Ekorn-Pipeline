use v5.36;

package Ekorn::Pipeline::Sink;

use parent 'Ekorn::Pipeline::Element';

use Ref::Util               qw(is_coderef);
use Ekorn::Pipeline::Errors qw(croakf);
use namespace::clean;

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Return a sink made afresh for each run by the set-up given, which
# returns its step and its end. With list => 1, its result is a list,
# which an operator gives as an array reference.
sub new ($class, $setup, %option) {
    croakf 'Expected a code reference' unless is_coderef($setup);
    return bless {
        setup => $setup,
        list  => !!$option{list},
        call  => sub { croakf 'Expected a sink to be run in a pipeline' },
    }, $class;
}


# Return the step and the end of a new run.
sub for_run ($self) {
    my @made = $self->{setup}->();
    croakf 'Expected the set-up of a sink to return a code reference and an end'
        unless @made == 2 && is_coderef($made[0]) && is_coderef($made[1]);
    return @made;
}


# Return true if the sink's result is a list, rather than one value.
sub gives_list ($self) {
    return $self->{list};
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Sink - a sink made for each run (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
