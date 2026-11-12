use v5.36;

package Ekorn::Pipeline::Iterator;

use experimental qw(builtin);
use builtin      qw(refaddr);
use namespace::clean;

# Each iterator's finish, by its address.
my %finish;

# Return an iterator: a code reference of this class, calling $next,
# whose run $finish ends, told how it ended.
sub new ($class, $next, $finish) {
    my $self = bless sub { &{ $next } }, $class;
    $finish{refaddr($self)} = $finish;
    return $self;
}


# End the run, if it hasn't ended, telling its parts how: "stopped",
# unless told otherwise.
sub finish ($self, $how = 'stopped') {
    my $finish = $finish{refaddr($self)};
    $finish->($how) if $finish;
    return;
}


# An iterator let go ends its run, as stopped.
sub DESTROY ($self) {
    local $@ = undef;
    my $finish = delete $finish{refaddr($self)};
    $finish->('stopped') if $finish;
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
