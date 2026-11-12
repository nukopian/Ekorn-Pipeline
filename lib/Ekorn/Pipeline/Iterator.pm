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
# $ended says how its run ended, and $spent whether it has handed out
# everything it will. A value looked at ahead, by single, is held, and
# handed out first.
sub new (
    $class, $next, $end_run, $context = undef, $ended = sub () { return },
    $spent = sub () { return },
) {
    my $ahead = [];
    return bless {
        call    => sub () { @$ahead ? shift @$ahead : $next->() },
        ahead   => $ahead,
        end_run => $end_run,
        context => $context,
        ended   => $ended,
        spent   => $spent,
    }, $class;
}


# Return how the run ended: "done" if its source was read to its end,
# "stopped" if the reading was cut short, by a stop or from outside, or
# values still to be handed out were dropped, and "died" if anything in
# it died; nothing until the iterator has given all it will.
sub ended ($self) {
    return if @{ $self->{ahead} };
    my $ended = $self->{ended}->();
    return $self->{dropped} && ($ended // '') eq 'done' ? 'stopped' : $ended;
}


# End the run, if it hasn't ended, as from outside: each part is told
# how from where it stands, and nothing more is handed out.
sub finish ($self) {
    $self->{dropped} = 1 if splice @{ $self->{ahead} };
    $self->{end_run}->();
    return;
}


# Return the values still to be handed out, reading the run to its end:
# as a list, or, asked for one value, an array reference of them.
sub all ($self) {
    my $next = $self->{call};
    my @all;
    while (my($value) = $next->()) { push @all, $value }
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
# only one: if there's another, warn, and keep it for the next pull.
sub single ($self) {
    my $next = $self->{call};
    my($value) = $next->();
    if (my($more) = $next->()) {
        unshift @{ $self->{ahead} }, $more;
        Carp::carp 'Expected only one item, but there were more';
    }
    return $value;
}


# An iterator is a source: of the values its run gives, the run ended
# from outside when the run reading it ends, passing on its context.
sub ekorn_source ($self) {
    croakf
        'Expected a source with values still to give: an iterator is one run, and this one is spent'
        if !@{ $self->{ahead} } && $self->{spent}->();
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
