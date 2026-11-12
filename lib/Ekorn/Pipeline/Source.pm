use v5.36;

package Ekorn::Pipeline::Source;

use parent 'Ekorn::Pipeline::Element';

use Ref::Util               qw(is_coderef);
use Ekorn::Pipeline::Errors qw(croakf);
use namespace::clean;

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Return a source made afresh for each run by the set-up given, which
# returns the source's step and, optionally, its end and a context for
# the run. Called as a code reference outside a run, it makes one run
# of its own, and steps it.
sub new ($class, $setup) {
    croakf 'Expected a code reference' unless is_coderef($setup);
    my $step;
    return bless {
        setup => $setup,
        call  => sub {
            $step //= ($setup->())[0];
            croakf 'Expected the set-up of a source to return a code reference'
                unless is_coderef($step);
            return $step->();
        },
    }, $class;
}


# Return what the set-up returns for a new run: the step, and
# optionally the end and a context.
sub as_source ($self) {
    return $self->{setup}->();
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Source - a source made for each run (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
