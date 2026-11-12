use v5.36;

package Ekorn::Pipeline::Sink;

use parent 'Ekorn::Pipeline::Element';

use Ref::Util               qw(is_coderef);
use Ekorn::Pipeline         qw();
use Ekorn::Pipeline::Errors qw(croakf);
use namespace::clean;

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Return a sink made afresh for each run by the set-up given, which
# returns its step, its flush, giving its result, and, optionally, its
# end. A sink's result is a list, offered by as_list; new_scalar makes
# one whose result is one value, offered by as_scalar. Called with
# values, a sink pushes them through a fresh sink of its set-up, as a
# pipeline of the one sink would, and gives its result: the closure
# holds the set-up, not the sink, so it works however long it's kept.
sub new ($class, $setup) {
    return _made($class->can('as_list') ? $class : 'Ekorn::Pipeline::Sink::List',
        $setup);
}


# Return a sink, as new does, whose result is one value.
sub new_scalar ($class, $setup) {
    return _made(
        $class->can('as_scalar') ? $class : 'Ekorn::Pipeline::Sink::Scalar',
        $setup);
}


sub _made ($into, $setup) {
    croakf 'Expected a code reference' unless is_coderef($setup);
    return bless {
        setup => $setup,
        call  => sub (@values) {
            return Ekorn::Pipeline->new(_made($into, $setup))->(@values);
        },
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
