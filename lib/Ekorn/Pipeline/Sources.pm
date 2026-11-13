use v5.36;

package Ekorn::Pipeline::Sources;

use Exporter                   qw(import);
use Ekorn::Pipeline::Errors    qw(croakf);
use Ekorn::Pipeline::Factories qw(source);
use namespace::clean -except => 'import';

our @EXPORT_OK = qw(from_array from_file);

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Return a source giving the values given, from the first, each run.
sub from_array (@values) {
    return source {
        my $i = 0;
        return sub () { $i < @values ? $values[$i++] : () };
    };
}


# Return a source giving the file's records, as $/ divides them, with $/
# taken off; the file is opened for each run, and closed as it ends.
sub from_file ($path) {
    return source {
        # Open for the run, and closed by its end.
        open my $fh, '<', $path or croakf    ## no critic (InputOutput::RequireBriefOpen)
            q(Can't read %s: %s), $path, $!;
        return (
            sub () {
                my $line = readline $fh;
                return unless defined $line;
                chomp $line;
                return $line;
            },
            sub ($how) { close $fh },
        );
    };
}

1;

__END__

=head1 NAME

Ekorn::Pipeline::Sources - ready-made sources (experimental)

=head1 DESCRIPTION

A prototype, on C<pipeline-experimental>, for the design in
F<docs/design/> (roadmap 2026-0022). Not yet documented.

=cut
