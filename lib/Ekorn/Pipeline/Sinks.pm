use v5.36;

package Ekorn::Pipeline::Sinks;

use Exporter                qw(import);
use Ekorn::Pipeline::Errors qw(croakf);
use Ekorn::Pipeline::Sink   qw();
use Ekorn::Pipeline::Stop   qw();
use namespace::clean -except => 'import';

our @EXPORT_OK = qw(count first_value to_array to_file);

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Return a sink giving how many values there were.
sub count () {
    return Ekorn::Pipeline::Sink->new(sub {
        my $n = 0;
        return (sub ($value) { $n++; return }, sub ($how) { $n });
    });
}


# Return a sink giving the first value, stopping the run there.
sub first_value () {
    return Ekorn::Pipeline::Sink->new(sub {
        my @first;
        return (
            sub ($value) { @first = ($value); Ekorn::Pipeline::Stop->throw },
            sub ($how) { @first },
        );
    });
}


# Return a sink giving every value, as a list.
sub to_array () {
    return Ekorn::Pipeline::Sink->new(
        sub {
            my @all;
            return (sub ($value) { push @all, $value; return }, sub ($how) { @all });
        },
        list => 1,
    );
}


# Return a sink writing each value to the file, followed by $/, giving
# how many; the file is opened for each run, and closed as it ends.
sub to_file ($path) {
    return Ekorn::Pipeline::Sink->new(sub {
        # Open for the run, and closed by its end.
        open my $fh, '>', $path or croakf    ## no critic (InputOutput::RequireBriefOpen)
            q(Can't write %s: %s), $path, $!;
        my $after = ref $/ || !defined $/ ? '' : length $/ ? $/ : "\n\n";
        my $n     = 0;
        return (
            sub ($value) {
                print { $fh } $value, $after or croakf q(Can't write %s: %s), $path, $!;
                $n++;
                return;
            },
            sub ($how) {
                close $fh or croakf q(Can't write %s: %s), $path, $!;
                return $n;
            },
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
