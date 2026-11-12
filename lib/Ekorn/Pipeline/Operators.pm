use v5.36;

package Ekorn::Pipeline::Operators;

use experimental            qw(builtin);
use builtin                 qw(blessed);
use Ekorn::Pipeline         qw(is_sink is_stage);
use Ekorn::Pipeline::Errors qw(croakf);
use Ekorn::Pipeline::Gather qw();
use Ekorn::Pipeline::Sink   qw();
use Ekorn::Pipeline::Source qw();
use Ekorn::Pipeline::Stage  qw();
use namespace::clean;

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# The key in %^H marking the scopes where the operators are in force.
my $IN_FORCE = 'Ekorn::Pipeline::Operators';

# Put the operators in force for the rest of the scope being compiled:
# they work on Ekorn's types only in code that says so.
sub import ($class, @) {
    $^H{$IN_FORCE} = 1;    ## no critic (Variables::RequireLocalizedPunctuationVars): a pragma's import sets %^H for the scope being compiled
    return;
}


# Take the operators out of force for the rest of the scope.
sub unimport ($class, @) {
    delete $^H{$IN_FORCE};
    return;
}


# Croak unless the operators are in force where the line that used one
# was compiled.
sub _check_in_force ($operator) {
    my $hints = (caller 1)[10];
    croakf 'Expected use Ekorn::Pipeline::Operators in scope, for %s', $operator
        unless $hints && $hints->{$IN_FORCE};
    return;
}

# The | of two parts. From a source: with a scalar sink, the sink's
# result, at once; with a stage, a chain, a source of the values through
# it. From a stage: a chain of stages, a pipeline with |. A class of
# sources of its own can overload | with this, to chain as Ekorn's do.
sub chain ($before, $after, $swapped = undef, @) {
    _check_in_force('|');
    ($before, $after) = ($after, $before) if $swapped;
    croakf 'Expected a source, or a stage made with a word, on the left of |'
        unless blessed($before) && (_is_source($before) || is_stage($before));
    # A pipeline made with new has no operators, though Perl swaps the
    # sides to call one for a typed part on its right.
    croakf 'Expected a source, or a stage made with a word, on the left of |'
        if $before isa 'Ekorn::Pipeline'
        && !($before isa 'Ekorn::Pipeline::Operators::Stages');
    croakf 'Expected a stage or a sink on the right of |' unless is_stage($after);
    unless (_is_source($before)) {
        return Ekorn::Pipeline::Operators::Stages->new($before, $after);
    }
    my($source, @stages) = _parts($before);
    my $sink = is_sink($after);
    croakf
        'Expected a sink giving one value at the end of |, not a list: use to_arrayref, not to_array'
        if $sink eq 'list';
    return _chain($source, @stages, $after) unless $sink;
    my($result) = Ekorn::Pipeline->new(@stages, $after)->iterator($source)->();
    return $result;
}


# Return a reference to an array of every value the source gives. A
# class of sources of its own can overload @{} with this.
sub drain ($source, @) {
    _check_in_force('@{}');
    my $next = Ekorn::Pipeline->new->iterator($source);
    my @values;
    while (my($value) = $next->()) { push @values, $value }
    return \@values;
}


sub _is_source ($thing) {
    return !!(blessed($thing) && $thing->can('as_source'));
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
        return (
            sub () { $next->() }, sub ($how) { $next->finish },
            $next->{context},
        );
    });
    $chain->{parts} = [$source, @stages];
    return $chain;
}

# A chain from a source is a source that keeps what it was made of.
package Ekorn::Pipeline::Operators::Chain {    ## no critic (Modules::ProhibitMultiplePackages)
    use parent -norequire, 'Ekorn::Pipeline::Source';
}

# A chain of stages is a pipeline, of this class, which has |.
package Ekorn::Pipeline::Operators::Stages {    ## no critic (Modules::ProhibitMultiplePackages)
    use parent -norequire, 'Ekorn::Pipeline';
    use overload '|' => \&Ekorn::Pipeline::Operators::chain, fallback => 1;
}

# Loading this module gives Ekorn's sources and iterators | and @{},
# and its stages, gathers and sinks |, and only then.
package Ekorn::Pipeline::Source {    ## no critic (Modules::ProhibitMultiplePackages)
    use overload
        '|'      => \&Ekorn::Pipeline::Operators::chain,
        '@{}'    => \&Ekorn::Pipeline::Operators::drain,
        fallback => 1;
}

package Ekorn::Pipeline::Iterator {    ## no critic (Modules::ProhibitMultiplePackages)
    use overload
        '|'      => \&Ekorn::Pipeline::Operators::chain,
        '@{}'    => \&Ekorn::Pipeline::Operators::drain,
        fallback => 1;
}

package Ekorn::Pipeline::Stage {    ## no critic (Modules::ProhibitMultiplePackages)
    use overload '|' => \&Ekorn::Pipeline::Operators::chain, fallback => 1;
}

package Ekorn::Pipeline::Gather {    ## no critic (Modules::ProhibitMultiplePackages)
    use overload '|' => \&Ekorn::Pipeline::Operators::chain, fallback => 1;
}

package Ekorn::Pipeline::Sink {    ## no critic (Modules::ProhibitMultiplePackages)
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
