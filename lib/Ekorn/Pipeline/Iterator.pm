use v5.36;

package Ekorn::Pipeline::Iterator;

use parent 'Ekorn::Pipeline::Element';

use namespace::clean;

# Return an iterator, calling $next for each value, whose run $end_run
# ends from outside, and $context is the context its run's source gave.
sub new ($class, $next, $end_run, $context = undef) {
    return bless {call => $next, end_run => $end_run, context => $context}, $class;
}


# End the run, if it hasn't ended, as from outside: each part is told
# how from where it stands, and nothing more is handed out.
sub finish ($self) {
    $self->{end_run}->();
    return;
}


# An iterator is a source: of the values its run gives, the run ended
# from outside when the run reading it ends, passing on its context.
sub as_source ($self) {
    my $next = $self->{call};
    return (sub () { $next->() }, sub ($how) { $self->finish }, $self->{context});
}


# An iterator let go ends its run.
sub DESTROY ($self) {
    local $@ = undef;
    $self->{end_run}->() if $self->{end_run};
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
