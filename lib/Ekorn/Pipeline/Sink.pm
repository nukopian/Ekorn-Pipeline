use v5.36;

package Ekorn::Pipeline::Sink;

use parent 'Ekorn::Pipeline::Element';

use Ref::Util               qw(is_coderef);
use Ekorn::Pipeline::Errors qw(croakf);
use namespace::clean;

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Return a sink made afresh for each run by the set-up given, which
# returns its step, its flush, giving its result, and, optionally, its
# end. Its result is one value, as_scalar, unless list => 1 is given,
# when it's a list, as_list.
sub new ($class, $setup, %option) {
    croakf 'Expected a code reference' unless is_coderef($setup);
    my $into
        = $option{list}
        ? 'Ekorn::Pipeline::Sink::List'
        : 'Ekorn::Pipeline::Sink::Scalar';
    return bless {
        setup => $setup,
        call  => sub { croakf 'Expected a sink to be run in a pipeline' },
    }, $into;
}

# A sink whose result is one value.
package Ekorn::Pipeline::Sink::Scalar {    ## no critic (Modules::ProhibitMultiplePackages)
    use parent -norequire, 'Ekorn::Pipeline::Sink';


    sub as_scalar ($self) {
        return $self->{setup}->();
    }
}

# A sink whose result is a list.
package Ekorn::Pipeline::Sink::List {    ## no critic (Modules::ProhibitMultiplePackages)
    use parent -norequire, 'Ekorn::Pipeline::Sink';


    sub as_list ($self) {
        return $self->{setup}->();
    }
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Sink - a sink made for each run (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
