use v5.36;

package Ekorn::Pipeline::Source;

use experimental            qw(builtin);
use builtin                 qw(refaddr);
use Ref::Util               qw(is_coderef);
use Ekorn::Pipeline::Errors qw(croakf);
use namespace::clean;

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Each source's set-up, by the source's address.
my %setup;

# Return a source made afresh for each run by the set-up given, which
# returns the source's step and, optionally, its end. Called as a code
# reference outside a run, it makes one run of its own, and steps it.
sub new ($class, $setup) {
    croakf 'Expected a code reference' unless is_coderef($setup);
    my $step;
    my $self = bless sub { $step //= (_made($setup))[0]; return $step->() }, $class;
    $setup{refaddr($self)} = $setup;
    return $self;
}


# Return the step and the end of a new run.
sub for_run ($self) {
    return _made($setup{refaddr($self)});
}


sub _made ($setup) {
    my @made = $setup->();
    croakf
        'Expected the set-up of a source to return a code reference, and optionally an end'
        unless (@made == 1 || @made == 2)
        && is_coderef($made[0])
        && (@made == 1 || is_coderef($made[1]));
    return @made;
}


sub DESTROY ($self) {
    delete $setup{refaddr($self)};
    return;
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Source - a source made for each run (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
