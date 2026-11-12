use v5.36;

package Ekorn::Pipeline::Sinks;

use Carp                    qw();
use Exporter                qw(import);
use Ekorn::Pipeline::Errors qw(croakf);
use Ekorn::Pipeline::Sink   qw();
use Ekorn::Pipeline::Stop   qw();
use namespace::clean -except => 'import';

our @EXPORT_OK = qw(
    keep keep_all count_items keep_first keep_last keep_single
    to_file);

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Each sink taking no arguments has an empty prototype, so that
# `count_items + 0` reads as `count_items() + 0`, not `count_items(+0)`.
# A chain inside a larger expression still needs parentheses, as |
# binds loosest.

# Return a sink giving how many values there were.
sub count_items : prototype() () {
    return Ekorn::Pipeline::Sink->new_scalar(sub {
        my $n = 0;
        return (sub ($value) { $n++ }, sub () { $n });
    });
}


# The sinks named for what they give: keep_all, keep(N), keep_first,
# keep_last, keep_single and count_items. The container sink, named for
# where the items go, is to_file, below.

# Return a sink giving every item, as a list.
sub keep_all : prototype() () {
    return Ekorn::Pipeline::Sink->new(sub {
        my @all;
        return (sub ($item) { push @all, $item }, sub () { @all });
    });
}


# Return a sink giving the one item, asserting it's the only one: at a
# second, it warns and stops the run, giving the first; undef if there
# was none.
sub keep_single : prototype() () {
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
sub keep_first : prototype() () {
    return Ekorn::Pipeline::Sink->new_scalar(sub {
        my @first;
        return (
            sub ($value) { @first = ($value); Ekorn::Pipeline::Stop->throw },
            sub () { @first },
        );
    });
}


# Return a sink giving the first $count items, as a list, stopping the
# run once it has them.
sub keep ($count) {
    croakf 'Expected a count of 0 or more'
        unless defined $count && $count =~ m( \A \d+ \z )xa;
    return Ekorn::Pipeline::Sink->new(sub {
        my @kept;
        return (
            sub ($item) {
                Ekorn::Pipeline::Stop->throw if @kept >= $count;
                push @kept, $item;
                Ekorn::Pipeline::Stop->throw if @kept >= $count;
                return;
            },
            sub () { @kept },
        );
    });
}


# Return a sink giving the last item, reading every one to find it;
# undef if there was none.
sub keep_last : prototype() () {
    return Ekorn::Pipeline::Sink->new_scalar(sub {
        my @kept;
        return (sub ($item) { @kept = ($item); return }, sub () { @kept });
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
