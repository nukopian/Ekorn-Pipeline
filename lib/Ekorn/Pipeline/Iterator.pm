use v5.36;

package Ekorn::Pipeline::Iterator;

use parent 'Ekorn::Pipeline::Element';

use Carp                    qw();
use Ekorn::Pipeline::Errors qw(croakf);
use namespace::clean;

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Return an iterator, calling $next for each value, whose run $end_run
# ends from outside, $context is the context its run's source gave,
# $ended says how its run ended, $spent whether it has handed out
# everything it will, and $all, if given, gives every value still to
# come in one call, as calling $next until it gives none would.
sub new (
    $class, $next, $end_run, $context = undef, $ended = sub () { return },
    $spent = sub () { return }, $all = undef,
) {
    return bless {
        call    => $next,
        end_run => $end_run,
        context => $context,
        ended   => $ended,
        spent   => $spent,
        all     => $all,
    }, $class;
}


# Return how the run ended: "done" if its source was read to its end,
# "stopped" if the reading was cut short, by a stop or from outside, or
# values still to be handed out were dropped, and "died" if anything in
# it died; nothing until the iterator has given all it will.
sub ended ($self) {
    return $self->{ended}->();
}


# End the run, if it hasn't ended, as from outside: each part is told
# how from where it stands, and nothing more is handed out.
sub finish ($self) {
    $self->{end_run}->();
    return;
}


# Return the values still to be handed out, reading the run to its end:
# as a list, or, asked for one value, an array reference of them.
sub all ($self) {
    my @all;
    if (my $all = $self->{all}) {
        @all = $all->();
    }
    else {
        my $next = $self->{call};
        while (my($value) = $next->()) { push @all, $value }
    }
    return wantarray ? @all : \@all;
}


# Return the next value, or undef if there's none, and end the run, so
# nothing more is read.
sub first ($self) {
    my($value) = $self->{call}->();
    $self->finish;
    return $value;
}


# Return the next value, or undef if there's none, asserting it's the
# only one: if there's another, warn. The run ends either way.
sub single ($self) {
    my $next = $self->{call};
    my($value) = $next->();
    Carp::carp 'Expected only one item, but there were more'
        if my($more) = $next->();
    $self->finish;
    return $value;
}


# An iterator is a source: of the values its run gives, the run ended
# from outside when the run reading it ends, passing on its context.
sub ekorn_source ($self) {
    croakf
        'Expected a source with values still to give: an iterator is one run, and this one is spent'
        if $self->{spent}->();
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
