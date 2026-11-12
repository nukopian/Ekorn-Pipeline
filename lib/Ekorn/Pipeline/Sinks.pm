use v5.36;

package Ekorn::Pipeline::Sinks;

use Exporter                qw(import);
use Ref::Util               qw(is_arrayref);
use Ekorn::Pipeline::Errors qw(croakf);
use Ekorn::Pipeline::Sink   qw();
use Ekorn::Pipeline::Stop   qw();
use namespace::clean -except => 'import';

our @EXPORT_OK = qw(count first_value to_array to_arrayref to_file);

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# Each sink taking no arguments has an empty prototype, so that
# `count + 0` reads as `count() + 0`, not `count(+0)`. A chain inside a
# larger expression still needs parentheses, as | binds loosest.

# Return a sink giving how many values there were.
sub count : prototype() () {
    return Ekorn::Pipeline::Sink->new_scalar(sub {
        my $n = 0;
        return (sub ($value) { $n++ }, sub () { $n });
    });
}


# Return a sink giving the first value, stopping the run there; undef if
# there was none.
sub first_value : prototype() () {
    return Ekorn::Pipeline::Sink->new_scalar(sub {
        my @first;
        return (
            sub ($value) { @first = ($value); Ekorn::Pipeline::Stop->throw },
            sub () { @first },
        );
    });
}


# Return a sink giving every value, as a list.
sub to_array : prototype() () {
    return Ekorn::Pipeline::Sink->new(sub {
        my @all;
        return (sub ($value) { push @all, $value }, sub () { @all });
    });
}


# Return a sink giving an array reference of every value: the array
# given, with each pushed onto it, or a new one.
sub to_arrayref : prototype(;$) ($array = undef) {
    croakf 'Expected an array reference' if defined $array && !is_arrayref($array);
    return Ekorn::Pipeline::Sink->new_scalar(sub {
        my $into = $array // [];
        return (sub ($value) { push @$into, $value }, sub () { $into });
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
