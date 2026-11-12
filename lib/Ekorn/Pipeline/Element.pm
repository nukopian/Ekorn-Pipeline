use v5.36;

package Ekorn::Pipeline::Element;

use namespace::clean;

# Called as a code reference, an element calls the closure it holds,
# which never refers to the element itself, so the element is freed as
# soon as nothing else holds it.
use overload '&{}' => sub ($self, @) { $self->{call} }, fallback => 1;

# Call the element, as calling it as a code reference does.
sub call ($self, @arguments) {
    return $self->{call}->(@arguments);
}


1;

__END__

=head1 NAME

Ekorn::Pipeline::Element - what Ekorn's types are made from (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
