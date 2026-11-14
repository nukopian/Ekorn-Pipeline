use v5.36;

package Ekorn::Pipeline::JSON;

use experimental qw(builtin try);

use builtin                    qw(blessed);
use Exporter                   qw(import);
use JSON::MaybeXS              qw();
use Ref::Util                  qw(is_plain_arrayref is_plain_hashref);
use Scalar::Util               qw(openhandle);
use Ekorn::Pipeline::Errors    qw(croakf);
use Ekorn::Pipeline::Factories qw(gather sink_one source stage);
use namespace::clean -except => 'import';

our @EXPORT_OK   = qw(from_json to_json);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

# Croak at the line that called Ekorn::Pipeline.
our @CARP_NOT = @Ekorn::Pipeline::Errors::INTERNAL;

# How much a source reads at a time, before reading on to the end of the
# line, so that no number is cut in two; the tests make it small.
our $BLOCK = 65_536;

# The types the type option may name, each as the format it means: one
# document, or lines of them.
my %FORMAT = (json => 'json', jsonl => 'lines', ndjson => 'lines');

# A source of JSON: what it reads, decoded, its values. Given no file or
# filehandle, a stage: each value, a JSON text, decoded.
sub from_json (@options) {
    my %option = _options(@options);
    my $format = _format(\%option) // 'auto';
    return _reader(\%option, $format) if defined $option{file} || $option{fh};
    my $new = $option{new};
    return gather {
        my $json = $new->();    # this run's
        return sub ($text) { _decoded($json, $text, $format) };
    };
}


# A sink of JSON: each value, encoded, written to the file or
# filehandle, giving how many. Given neither, a stage: each value,
# encoded, as a file of its type would hold it.
sub to_json (@options) {
    my %option = _options(@options);
    my $format = _format(\%option) // (defined $option{file} ? 'json' : 'lines');
    my $json   = $option{new}->();
    croakf 'Expected an encoder that doesn\'t indent, to write JSON Lines'
        if $format eq 'lines' && _indents($json);
    return _writer(\%option, $format, $json)
        if defined $option{file} || $option{fh};
    return stage { _encoded($json, $_) } if $format eq 'lines';
    return gather {
        my @values;    # this run's
        return (
            sub ($value) { push @values, $value; return },
            sub () { _encoded($json, \@values) =~ s( \n \z )()xr },
        );
    };
}


# Return the options given, checked, with "new", a sub returning the
# encoder: one made from json's options, over the defaults, or json's
# object, as it is.
sub _options (@given) {
    croakf 'Expected options as name => value pairs' if @given % 2;
    my %option = @given;
    my @unknown
        = sort grep { !m( \A (?: file | fh | type | json ) \z )x } keys %option;
    croakf 'Expected the options file, fh, type and json, not %s', join ', ',
        @unknown
        if @unknown;
    croakf 'Expected a file or a filehandle, not both'
        if defined $option{file} && exists $option{fh};
    croakf 'Expected an open filehandle'
        if exists $option{fh} && !defined openhandle($option{fh});
    croakf 'Expected a type of json, jsonl or ndjson, not %s', $option{type}
        if defined $option{type} && !$FORMAT{$option{type}};
    my $json = $option{json};
    if (blessed($json)) {
        $option{new} = sub () { $json };
        return %option;
    }
    croakf 'Expected json to be a hash reference of options, or an encoder object'
        if defined $json && !is_plain_hashref($json);
    my %settings = (utf8 => 1, allow_nonref => 1, %{ $json // {} });
    try {
        JSON::MaybeXS->new(%settings);
    }
    catch ($e) {
        croakf 'Expected json options the encoder knows: %s', _unplaced($e);
    }
    $option{new} = sub () { JSON::MaybeXS->new(%settings) };
    return %option;
}


# Return the format the type option names, or a file's name ending in
# .jsonl or .ndjson, if either does.
sub _format ($option) {
    return $FORMAT{$option->{type}} if defined $option->{type};
    return 'lines'
        if defined $option->{file}
        && $option->{file} =~ m( \. (?: jsonl | ndjson ) \z )xi;
    return;
}


# Return true if the encoder indents, so writes a document over many
# lines.
sub _indents ($json) {
    return $json->can('get_indent') && $json->get_indent;
}


# Return an error's message without the place it was raised, as a
# message of ours says where.
sub _unplaced ($error) {
    return "$error" =~ s( ,? \s+ at \s+ \S+ \s+ line \s+ \d+ \.? \s* \z )()xr;
}


# Croak that what's read from $from can't be decoded, and why. The
# decoder is reset, for the next run, if it's the caller's.
sub _undecodable ($json, $from, $why) {
    $json->incr_reset;
    return croakf q(Can't decode JSON from %s: %s), $from, $why;
}


# Return the documents in $text, a JSON text: each as it is, or, if the
# format is one document, its elements, if it's an array.
sub _decoded ($json, $text, $format) {
    my @documents;
    if ($format eq 'json') {
        try {
            @documents = $json->decode($text);
        }
        catch ($e) {
            _undecodable($json, 'a value', _unplaced($e));
        }
        return is_plain_arrayref($documents[0]) ? @{ $documents[0] } : @documents;
    }
    try {
        @documents = $json->incr_parse($text);
    }
    catch ($e) {
        _undecodable($json, 'a value', _unplaced($e));
    }
    _complete($json, 'a value');
    return @documents;
}


# Croak unless the decoder has a whole number of documents: it croaks,
# asked for the text it holds, if it's inside one.
sub _complete ($json, $from) {
    try {
        $json->incr_text;
    }
    catch ($e) {
        _undecodable($json, $from, 'it ends inside a document');
    };    # the ; ends the statement for Perl::Critic, which doesn't know try
    return;
}


# Return a source of the documents in the file or filehandle. In the
# format "auto", the first is held back until a second is read, or the
# input ends: one array alone gives its elements.
sub _reader ($option, $format) {
    my($path, $given, $new) = @{ $option }{qw(file fh new)};
    my $from = $path // 'the filehandle';
    return source {
        my $fh = $given;
        unless ($fh) {
            # Open for the run, and closed by its end.
            open $fh, '<:raw', $path    ## no critic (InputOutput::RequireBriefOpen)
                or croakf q(Can't read %s: %s), $path, $!;
        }
        my $json = $new->();            # this run's, or the caller's, reset
        $json->incr_reset;
        my(@documents, $ended);
        my $seen = 0;
        my $step = sub () {
            while (1) {
                return splice @documents
                    if @documents && ($format eq 'lines' || $format eq 'auto' && $seen > 1);
                if ($ended) {
                    return unless @documents;
                    my($only) = splice @documents;
                    return is_plain_arrayref($only) ? @$only : $only;
                }
                my $chunk = _chunk($fh, $from);
                unless (defined $chunk) {
                    _complete($json, $from);
                    $ended = 1;
                    next;
                }
                my @read;
                try {
                    @read = $json->incr_parse($chunk);
                }
                catch ($e) {
                    _undecodable($json, $from, _unplaced($e));
                }
                push @documents, @read;
                $seen += @read;
                _undecodable(
                    $json, $from,
                    'it holds more than one document, and its type is json',
                ) if $format eq 'json' && $seen > 1;
            }
        };
        return {step => $step, end => $path ? sub ($how) { close $fh } : undef};
    };
}


# Return the next chunk of $fh, read from $from: up to $BLOCK, and on to
# the end of its line; nothing at its end.
sub _chunk ($fh, $from) {
    my $chunk;
    my $read = read $fh, $chunk, $BLOCK;
    croakf q(Can't read %s: %s), $from, $! unless defined $read;
    return unless $read;
    local $/ = "\n";
    if (substr($chunk, -1) ne "\n") {
        my $rest = readline $fh;
        $chunk .= $rest if defined $rest;
    }
    return $chunk;
}


# Return $value encoded.
sub _encoded ($json, $value) {
    my $text;
    try {
        $text = $json->encode($value);
    }
    catch ($e) {
        croakf q(Can't encode a value as JSON: %s), _unplaced($e);
    };    # the ; ends the statement for Perl::Critic, which doesn't know try
    return $text;
}


# Return a sink writing each value, encoded, to the file or filehandle,
# as the format says, giving how many. One document is an array,
# written as the values come: an encoder that indents has its values'
# lines indented in it.
sub _writer ($option, $format, $json) {
    my($path, $given) = @{ $option }{qw(file fh)};
    my $to     = $path // 'the filehandle';
    my $indent = _indents($json);
    my($before, $between, $after)
        = $indent ? ("[\n", ",\n", "\n]\n") : ('[', ',', "]\n");
    return sink_one {
        my $fh = $given;
        unless ($fh) {
            # Open for the run, and closed by its end.
            open $fh, '>:raw', $path    ## no critic (InputOutput::RequireBriefOpen)
                or croakf q(Can't write %s: %s), $path, $!;
        }
        my $n     = 0;
        my $write = sub (@text) {
            print { $fh } @text or croakf q(Can't write %s: %s), $to, $!;
        };
        my $step
            = $format eq 'lines'
            ? sub ($value) { $write->(_encoded($json, $value), "\n"); $n++ }
            : sub ($value) {
                my $text = _encoded($json, $value) =~ s( \n \z )()xr;
                $text =~ s( ^ )(   )xmg if $indent;
                $write->($n++ ? $between : $before, $text);
            };
        return {
            step  => $step,
            flush => sub () {
                $write->($n ? $after : "[]\n") if $format eq 'json';
                return $n;
            },
            end => $path
            ? sub ($how) { close $fh or croakf q(Can't write %s: %s), $path, $! }
            : undef,
        };
    };
}

1;

__END__

=encoding utf8

=for stopwords JSON JSONL NDJSON ndjson jsonl

=head1 NAME

Ekorn::Pipeline::JSON - read and write JSON, as a source, a stage or a sink

=head1 SYNOPSIS

    use Ekorn::Pipeline::JSON qw(from_json to_json);

    # A source: the documents in a file, whether JSON Lines, or one
    # array, whose elements are the values.
    my $next = Ekorn::Pipeline->new(@stages)->iterator(from_json(file => 'tracks.json'));

    # A sink: each value written to a file, as JSON Lines, or one array,
    # by the file's name; it gives how many.
    my $written = Ekorn::Pipeline->new(@stages, to_json(file => 'out.jsonl'))->(@values);

    # Stages: JSON texts decoded, and values encoded.
    my @rows  = Ekorn::Pipeline->new(from_json())->(@texts);
    my @lines = Ekorn::Pipeline->new(to_json(json => {canonical => 1}))->(@rows);

=head1 DESCRIPTION

Two functions, each making a different part by the options it's
given. Given a C<file> or an C<fh>, C<from_json> makes a source and
C<to_json> a sink; given neither, each makes a stage. Each part is made
afresh for each run.

The encoder is L<JSON::MaybeXS>'s: L<Cpanel::JSON::XS> where it's
installed, L<JSON::PP> otherwise. Text is UTF-8 bytes, as
C<encode_json> and C<decode_json> have it, and files are opened
C<:raw>.

Nothing is exported by default; ask for each, or for C<:all>, or import
them from L<Ekorn::Pipeline::Tooling>'s C<:json>. L<JSON> exports a
C<from_json> and a C<to_json> of its own by default, so a module using
both needs to import one under another name, or call it by its full
name.

=head1 FUNCTIONS

=head2 from_json

    from_json(file => $path, %options)
    from_json(fh => $fh, %options)
    from_json(%options)

Given a C<file> or an C<fh>, a source of the documents read from it,
decoded, which works out what it's reading. The input is read as one
document after another, which covers JSON Lines, also called NDJSON,
documents simply written one after another, and one document alone. If
it holds exactly one document, and that's an array, its elements are
the values; otherwise, each document is one. So a file of one array of
records gives the records, and a file of JSON Lines gives each line's.
An array alone is read whole before its first element is given, as
whether it's alone can't be known until the input ends; otherwise, the
input is read a block at a time.

A file whose name ends in C<.jsonl> or C<.ndjson> is read as JSON
Lines: each document is a value, even an array alone. C<type> can say
the same of any input, or say C<json>: one document, an array giving
its elements.

Given neither, a stage decoding each value, a JSON text, and passing on
each document in it: the one, usually, or, from a text holding JSON
Lines, each line's. An array is one value, not its elements, unless
C<type> is C<json>, when each text must be one document. A filehandle
is left open, for its opener to close; a file is opened as the run
starts, and closed once it has ended, however it ended.

=head2 to_json

    to_json(file => $path, %options)
    to_json(fh => $fh, %options)
    to_json(%options)

Given a C<file> or an C<fh>, a sink writing each value, encoded, and
giving how many. A file whose name ends in C<.jsonl> or C<.ndjson>, or
a filehandle, gets JSON Lines, each value a line; any other file one
document, an array of the values, written as they come, so a file named
C<.json> holds valid JSON. C<type> can say either of any of them. The
file is opened, emptied, as the run starts, and closed once it has
ended; a filehandle is left open.

Given neither, a stage passing on what a file of its type would hold:
by default, or with C<type> C<jsonl> or C<ndjson>, each value as one
line of text, without its newline, ready for
L<Ekorn::Pipeline::Sinks/to_file>; with C<type> C<json>, every value,
gathered, and passed on as one text, an array, once they've all come.
So C<to_json> and C<from_json> of the same type undo each other.

JSON Lines can't be indented, so C<to_json> croaks if asked for them
with an encoder that indents.

=head1 OPTIONS

=over

=item file

The path of a file to read or write.

=item fh

An open filehandle to read or write. It should be C<:raw>, as the text
is bytes, unless the encoder's C<utf8> is off.

=item type

C<json>, one document; or C<jsonl> or C<ndjson>, which are the same,
JSON Lines. See each function for what it means there, and its default.

=item json

The encoder: a hash reference of options for L<JSON::MaybeXS>'s C<new>,
such as C<< {canonical => 1, pretty => 1} >>, given over the defaults
C<utf8> and C<allow_nonref>; or an object of your own, such as a
L<Cpanel::JSON::XS> or L<JSON::PP> you've set up, used as it is. An
object reading a source has its incremental parser reset for each run,
so mustn't read two at once.

=back

=head1 DIAGNOSTICS

=over

=item Expected options as name => value pairs

A function was given an odd number of arguments.

=item Expected the options file, fh, type and json, not %s

A function was given an option it doesn't know, named after "not".

=item Expected a file or a filehandle, not both

A function was given both C<file> and C<fh>.

=item Expected an open filehandle

C<fh> was something other than an open filehandle.

=item Expected a type of json, jsonl or ndjson, not %s

C<type> was something else.

=item Expected json to be a hash reference of options, or an encoder object

C<json> was something else.

=item Expected json options the encoder knows: %s

C<json>'s options included one the encoder doesn't have; the rest of
the message is the encoder's.

=item Expected an encoder that doesn't indent, to write JSON Lines

L</to_json> was asked for JSON Lines, by its type or the file's name,
with an encoder that indents, such as with C<pretty>.

=item Can't decode JSON from %s: %s

What was read wasn't JSON: the first part is the file's path, "the
filehandle", or "a value", for a stage, and the second the decoder's
reason. It's "it ends inside a document" if the input ended part way
through one, and "it holds more than one document, and its type is json" if it
did, and its type is C<json>.

=item Can't encode a value as JSON: %s

A value couldn't be encoded, such as an object, by default; the second
part is the encoder's reason.

=item Can't read %s: %s

=item Can't write %s: %s

A file couldn't be opened, read, written or closed, or a filehandle
read or written; the second part says why.

=back

=head1 SEE ALSO

L<Ekorn::Pipeline>, L<Ekorn::Pipeline::Sources> and
L<Ekorn::Pipeline::Sinks>, for files of lines, and L<JSON::MaybeXS>.

The user guide's "Walk through a module of parts" builds this module,
step by step.

=head1 AUTHOR

Iain Campbell E<lt>cpanic@cpan.orgE<gt>

=head1 LICENSE

Copyright (c) 2026 by Iain Campbell.

This is free software; you can redistribute it and/or modify it under the
same terms as the Perl 5 programming language system itself.

=cut
