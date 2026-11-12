use v5.36;

package Ekorn::Pipeline::Iterator;

use parent 'Ekorn::Pipeline::Element';

use namespace::clean;

# Return an iterator, calling $next for each value, whose run $finish
# ends, told how it ended.
sub new ($class, $next, $finish) {
    return bless {call => $next, finish => $finish}, $class;
}


# End the run, if it hasn't ended, telling its parts how: "stopped",
# unless told otherwise.
sub finish ($self, $how = 'stopped') {
    $self->{finish}->($how);
    return;
}


# An iterator is a source, so it can't go where a stage goes.
sub goes_as_stage ($self) {
    return 0;
}


# An iterator let go ends its run, as stopped.
sub DESTROY ($self) {
    local $@ = undef;
    $self->{finish}->('stopped') if $self->{finish};
    return;
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Iterator - an iterator that ends its run (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
