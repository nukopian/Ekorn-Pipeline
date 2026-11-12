use v5.36;

package Ekorn::Pipeline::Operators;

use experimental            qw(builtin);
use builtin                 qw(blessed);
use Ekorn::Pipeline         qw(is_stage);
use Ekorn::Pipeline::Errors qw(croakf);
use Ekorn::Pipeline::Sink   qw();
use Ekorn::Pipeline::Source qw();
use namespace::clean;

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# The | of a source and what follows it: with a sink, the sink's result,
# at once, as one value, or, for a sink giving a list, an array
# reference; with a stage, a chain, a source of the values through it.
# A class of sources of its own can overload | with this, to chain as
# Ekorn's do.
sub chain ($before, $after, $swapped = undef, @) {
    ($before, $after) = ($after, $before) if $swapped;
    croakf 'Expected a source on the left of |'
        if !blessed($before)
        || !$before->can('for_run')
        || $before isa 'Ekorn::Pipeline::Sink';
    croakf 'Expected a stage or a sink on the right of |' unless is_stage($after);
    my($source, @stages) = _parts($before);
    return _chain($source, @stages, $after)
        unless $after isa 'Ekorn::Pipeline::Sink';
    my $next = Ekorn::Pipeline->new(@stages, $after)->iterator($source);
    my @result;
    while (my($value) = $next->()) { push @result, $value }
    return $after->gives_list ? \@result : $result[0];
}


# Return what a chain was made of, a source and stages; or, given a
# source that isn't a chain, the source.
sub _parts ($source) {
    return $source isa 'Ekorn::Pipeline::Operators::Chain'
        ? @{ $source->{parts} }
        : $source;
}


# Return a chain: a source of the values from $source through the
# stages, which keeps them, so that more can be added to it.
sub _chain ($source, @stages) {
    my $pipeline = Ekorn::Pipeline->new(@stages);
    my $chain    = Ekorn::Pipeline::Operators::Chain->new(sub {
        my $next = $pipeline->iterator($source);
        return (sub () { $next->() }, sub ($how) { $next->finish($how) });
    });
    $chain->{parts} = [$source, @stages];
    return $chain;
}

# A chain is a source that keeps what it was made of.
package Ekorn::Pipeline::Operators::Chain {    ## no critic (Modules::ProhibitMultiplePackages)
    use parent -norequire, 'Ekorn::Pipeline::Source';
}

# Loading this module gives Ekorn's sources |, and only then.
package Ekorn::Pipeline::Source {    ## no critic (Modules::ProhibitMultiplePackages)
    use overload '|' => \&Ekorn::Pipeline::Operators::chain, fallback => 1;
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Operators - | between sources, stages and sinks (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
