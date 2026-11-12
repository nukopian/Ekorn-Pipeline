use v5.36;

package Ekorn::Pipeline::Stage;

use parent 'Ekorn::Pipeline::Element';

use experimental            qw(builtin);
use builtin                 qw(blessed);
use overload                qw();
use Ref::Util               qw(is_coderef);
use Ekorn::Pipeline::Errors qw(croakf);
use namespace::clean;

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Return a stage of the code given, which is kept as it is, never
# blessed: a code reference, or an object called as one that isn't
# itself one of Ekorn's types, as a gather made into a Stage would run
# per value.
sub new ($class, $code) {
    my $callable
        = is_coderef($code) || (blessed($code) && overload::Method($code, '&{}'));
    croakf 'Expected a code reference'
        if !$callable || $code isa 'Ekorn::Pipeline::Element';
    return bless {call => $code}, $class;
}


# Return the code the stage was made of.
sub code ($self) {
    return $self->{call};
}


# Return the stage's step for a new run: its code, as it is.
sub as_stage ($self) {
    return $self->{call};
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Stage - a stage, as an object (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
