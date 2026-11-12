use v5.36;

package Ekorn::Pipeline::Stage;

use Ref::Util               qw(is_coderef);
use Ekorn::Pipeline::Errors qw(croakf);
use namespace::clean;

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Return a stage of the code given: a code reference of this class,
# calling the code, which is wrapped, never blessed itself.
sub new ($class, $code) {
    croakf 'Expected a code reference' unless is_coderef($code);
    return bless sub { &{ $code } }, $class;
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Stage - a stage, as an object (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
