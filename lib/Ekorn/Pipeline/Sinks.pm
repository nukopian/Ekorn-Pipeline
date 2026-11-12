use v5.36;

package Ekorn::Pipeline::Sinks;

use Carp                    qw();
use Exporter                qw(import);
use Ekorn::Pipeline::Errors qw(croakf);
use Ekorn::Pipeline::Sink   qw();
use Ekorn::Pipeline::Stop   qw();
use namespace::clean -except => 'import';

our @EXPORT_OK = qw(all_items count_items first_item single_item to_file);

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Each sink taking no arguments has an empty prototype, so that
# `count_items + 0` reads as `count_items() + 0`, not `count_items(+0)`. A chain inside a
# larger expression still needs parentheses, as | binds loosest.

# Return a sink giving how many values there were.
sub count_items : prototype() () {
    return Ekorn::Pipeline::Sink->new_scalar(sub {
        my $n = 0;
        return (sub ($value) { $n++ }, sub () { $n });
    });
}


# The sinks named for what they give: all_items, first_item, single_item
# and count_items. The container sink, named for where the items go, is
# to_file, below.

# Return a sink giving every item, as a list.
sub all_items : prototype() () {
    return Ekorn::Pipeline::Sink->new(sub {
        my @all;
        return (sub ($item) { push @all, $item }, sub () { @all });
    });
}


# Return a sink giving the one item, asserting it's the only one: at a
# second, it warns and stops the run, giving the first; undef if there
# was none.
sub single_item : prototype() () {
    return Ekorn::Pipeline::Sink->new_scalar(sub {
        my @only;
        return (
            sub ($item) {
                if (@only) {
                    Carp::carp 'Expected only one item, but there were more';
                    Ekorn::Pipeline::Stop->throw;
                }
                @only = ($item);
                return;
            },
            sub () { @only },
        );
    });
}


# Return a sink giving the first item, stopping the run there; undef if
# there was none.
sub first_item : prototype() () {
    return Ekorn::Pipeline::Sink->new_scalar(sub {
        my @first;
        return (
            sub ($value) { @first = ($value); Ekorn::Pipeline::Stop->throw },
            sub () { @first },
        );
    });
}


# Return a sink writing each value to the file, followed by $/, giving
# how many; the file is opened as the run starts, and closed as it ends.
sub to_file ($path) {
    return Ekorn::Pipeline::Sink->new_scalar(sub {
        # Open for the run, and closed by its end.
        open my $fh, '>', $path    ## no critic (InputOutput::RequireBriefOpen)
            or croakf q(Can't write %s: %s), $path, $!;
        my $after = ref $/ || !defined $/ ? '' : length $/ ? $/ : "\n\n";
        my $n     = 0;
        return (
            sub ($value) {
                print { $fh } $value, $after or croakf q(Can't write %s: %s), $path, $!;
                $n++;
            },
            sub () { $n },
            sub ($how) { close $fh or croakf q(Can't write %s: %s), $path, $! },
        );
    });
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Sinks - ready-made sinks (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
