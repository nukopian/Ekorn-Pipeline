use v5.36;

package Ekorn::Pipeline::Sink;

use experimental            qw(builtin);
use builtin                 qw(refaddr);
use Ref::Util               qw(is_coderef);
use Ekorn::Pipeline::Errors qw(croakf);
use namespace::clean;

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Each sink's set-up, and whether its result is a list, by its address.
my(%setup, %list);

# Return a sink made afresh for each run by the set-up given, which
# returns its step and its end. With list => 1, its result is a list,
# which an operator gives as an array reference.
sub new ($class, $setup, %option) {
    croakf 'Expected a code reference' unless is_coderef($setup);
    # A closure, over $setup, so that each sink is a code reference of its
    # own: Perl gives every call of an anonymous sub that closes over
    # nothing the same one.
    my $self
        = bless sub { croakf 'Expected a sink to be run in a pipeline' if $setup },
        $class;
    $setup{refaddr($self)} = $setup;
    $list{refaddr($self)}  = !!$option{list};
    return $self;
}


# Return the step and the end of a new run.
sub for_run ($self) {
    my @made = $setup{refaddr($self)}->();
    croakf 'Expected the set-up of a sink to return a code reference and an end'
        unless @made == 2 && is_coderef($made[0]) && is_coderef($made[1]);
    return @made;
}


# Return true if the sink's result is a list, rather than one value.
sub gives_list ($self) {
    return $list{refaddr($self)};
}


sub DESTROY ($self) {
    delete $setup{refaddr($self)};
    delete $list{refaddr($self)};
    return;
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Sink - a sink made for each run (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
