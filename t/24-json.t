use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

# Ekorn::Pipeline::JSON: from_json and to_json, each a source or a sink
# given a file or a filehandle, and a stage otherwise (roadmap
# 2026-0034). Each is run with JSON::MaybeXS's encoder and with JSON::PP's,
# given as an object.

use File::Temp qw(tempdir);

# A close that fails when asked, as one does on a full disk, in place of
# Perl's for the code compiled after it, Ekorn::Pipeline::JSON included.
our $FAIL_CLOSE;


BEGIN {
    *CORE::GLOBAL::close = sub : prototype(;*) ($fh = *ARGV) {
        my $closed = CORE::close($fh);
        return $closed unless $FAIL_CLOSE;
        $! = 28;    # No space left on device
        return 0;
    };
}

# A filehandle whose reads and writes fail, as on a failing disk.
package My::Failing::Handle {
    sub TIEHANDLE ($class)   { return bless {}, $class }
    sub READ      ($self, @) { $! = 5;  return }      # Input/output error
    sub PRINT     ($self, @) { $! = 28; return 0 }    # No space left on device
}

# An encoder of the caller's own, offering only what to_json needs.
package My::Encoder {
    sub new    ($class)        { return bless {}, $class }
    sub encode ($self, $value) { return "<$value>" }
}

use JSON::PP qw();
use Ekorn::Pipeline;
use Ekorn::Pipeline::JSON         qw(:all);
use Ekorn::Pipeline::Sinks        qw(keep_all to_file);
use Ekorn::Pipeline::Stages::Flow qw(take);

my $class = 'Ekorn::Pipeline';
my $file  = __FILE__;
my $dir   = tempdir(CLEANUP => 1);
my $n     = 0;

# Return the path of a new file in $dir, named to end in $suffix,
# holding $content, if given.
sub path ($suffix, $content = undef) {
    my $path = sprintf '%s/%d%s', $dir, ++$n, $suffix;
    if (defined $content) {
        open my $fh, '>:raw', $path or die "Can't write $path: $!";
        print { $fh } $content;
        close $fh or die "Can't write $path: $!";
    }
    return $path;
}


# Return what the file at $path holds.
sub slurp ($path) {
    open my $fh, '<:raw', $path or die "Can't read $path: $!";
    local $/ = undef;
    return scalar readline $fh;
}


# Return every value read from the JSON source made by the options given.
sub read_all (@options) {
    return [$class->new->iterator(from_json(@options))->all];
}


# Return an error's message without the place it was raised.
sub message ($error) {
    return ($error // '') =~ s( \ at \ \S+ \ line \ \d+ \. \n \z )()xr;
}

# The encoders each subtest is run with: JSON::MaybeXS's, by default, and
# JSON::PP's, given as an object.
my @encoders = (
    ['JSON::MaybeXS' => sub { () }],
    [
        'JSON::PP' =>
            sub { (json => JSON::PP->new->utf8->allow_nonref->canonical) },
    ],
);

subtest 'Nothing is exported by default' => sub {

    package My::Plain {
        use Ekorn::Pipeline::JSON;
    }
    ok !My::Plain->can($_), "not $_" for qw(from_json to_json);
};

for my $encoder (@encoders) {
    my($name, $json) = @$encoder;

    subtest "$name: from_json reads a file, working out what it holds" => sub {
        is read_all(file => path('.json', qq([{"a":1},{"a":2}]\n)), $json->()),
            [{a => 1}, {a => 2}], 'one array: its elements';
        is read_all(file => path('.json', qq({"a":1}\n)), $json->()),
            [{a => 1}], 'one object: itself';
        is read_all(
            file => path('.json', qq({"a":1}\n{"a":2}\n[3,4]\n)),
            $json->(),
            ),
            [{a => 1}, {a => 2}, [3, 4]], 'JSON Lines: each, arrays too';
        is read_all(file => path('.json', qq([1] [2])), $json->()),
            [[1], [2]], 'documents one after another, on one line';
        is read_all(file => path('.json', qq(1\n2\n3)), $json->()),
            [1, 2, 3], 'scalars, the last with no newline';
        is read_all(file => path('.json', ''), $json->()), [],
            'an empty file: none';
        is read_all(file => path('.json', qq([]\n)), $json->()), [],
            'an empty array: none';
        is read_all(file => path('.json', " \n\t\n"), $json->()), [],
            'only whitespace: none';
    };

    subtest "$name: from_json's type, and a file's name, say how to read it" =>
        sub {
            my $array = qq([1,2]\n);
            is read_all(file => path('.jsonl', $array), $json->()), [[1, 2]],
            '.jsonl: as it is';
            is read_all(file => path('.NDJSON', $array), $json->()), [[1, 2]],
            '.ndjson, in any case';
            is read_all(file => path('.txt', $array), type => 'jsonl', $json->()),
            [[1, 2]], 'type jsonl';
            is read_all(file => path('.txt', $array), type => 'ndjson', $json->()),
            [[1, 2]], 'type ndjson';
            is read_all(file => path('.jsonl', $array), type => 'json', $json->()),
            [1, 2], 'type json, over the name';
            is read_all(file => path('.txt', qq({"a":1})), type => 'json', $json->()),
            [{a => 1}], 'type json: an object, itself';
            like dies {
                read_all(file => path('.json', qq(1\n2\n)), type => 'json', $json->())
            },
            qr(\ACan't decode JSON from \S+: it holds more than one document, and its type is json at \Q$file\E line),
            'type json: more than one document croaks';
        };

    subtest "$name: from_json reads a block at a time, never cutting a document" =>
        sub {
            local $Ekorn::Pipeline::JSON::BLOCK = 3;
            my @rows    = map { {n => $_, text => 'x' x $_} } 1 .. 20;
            my $encoder = JSON::PP->new->canonical;
            my $lines   = join '', map { $encoder->encode($_) . "\n" } @rows;
            is read_all(file => path('.json', $lines), $json->()), \@rows, 'JSON Lines';
            is read_all(file => path('.json', $encoder->encode(\@rows)), $json->()),
            \@rows, 'one array, on one line';
            is read_all(
                file => path('.json', $encoder->pretty->encode(\@rows)),
                $json->(),
            ),
            \@rows, 'one array, over many lines';
            is read_all(file => path('.json', "12345\n678\n9"), $json->()),
            [12345, 678, 9], 'numbers, each whole';
        };

    subtest "$name: from_json reads a source only as it's pulled" => sub {
        my $lines = join '', map { "$_\n" } 1 .. 10;
        is [$class->new(take(2))
                ->iterator(from_json(file => path('.jsonl', $lines), $json->()))
                ->all],
            [1, 2], 'a stop ends the reading';
        my $next = $class->new->iterator(
            from_json(file => path('.jsonl', $lines), $json->()));
        is [$next->(), $next->()], [1, 2], 'one at a time';
    };

    subtest "$name: from_json reads a filehandle, and leaves it open" => sub {
        open my $fh, '<:raw', path('.json', qq({"a":1}\n{"b":2}\n)) or die $!;
        is read_all(fh => $fh, $json->()), [{a => 1}, {b => 2}], 'each document';
        ok defined fileno($fh), 'still open';
        close $fh;
    };

    subtest "$name: from_json reads each run afresh" => sub {
        my $source = from_json(file => path('.json', qq([1,2]\n)), $json->());
        is [$class->new->iterator($source)->all], [1, 2], 'the first run';
        is [$class->new->iterator($source)->all], [1, 2], 'the second';
        my $broken = from_json(file => path('.json', qq({"a":)), $json->());
        ok dies { $class->new->iterator($broken)->all }, 'a run that dies';
        is read_all(file => path('.json', qq([3]\n)), $json->()), [3],
            'leaves nothing behind';
    };

    subtest "$name: from_json as a stage gives each document in each text" => sub {
        my $stage = $class->new(from_json($json->()));
        is [$stage->(q({"a":1}), "1\n2\n", '[5,6]', '')], [{a => 1}, 1, 2, [5, 6]],
            'one, or each line of JSON Lines; an array is one value; none from none';
        is [$class->new(from_json(type => 'json', $json->()))->('[5,6]', '{"a":1}')
            ],
            [5, 6, {a => 1}], 'type json: one document, an array its elements';
        like
            dies { $class->new(from_json(type => 'json', $json->()))->('[1] [2]') },
            qr(Can't decode JSON from a value: ), 'type json: more than one croaks';
        like dies { $stage->('{"a":1}}') }, qr(Can't decode JSON from a value: \S),
            'malformed';
        like dies { $stage->('{"a":') },
            qr(Can't decode JSON from a value: it ends inside a document), 'incomplete';
        is [$stage->('[7]')], [[7]], 'and the next run is afresh';
    };

    subtest
        "$name: to_json as a stage passes on what a file of its type would hold" =>
        sub {
            is [$class->new(to_json($json->()))->({a => 1}, [2], 3)],
            ['{"a":1}', '[2]', '3'],
            'each value, one line';
            is [$class->new(to_json(type => 'ndjson', $json->()))->([1])], ['[1]'],
            'type ndjson';
            is [$class->new(to_json(type => 'json', $json->()))->(1, 2, 3)],
            ['[1,2,3]'],
            'type json: every value, as one array';
            is [$class->new(to_json(type => 'json', $json->()))->()], ['[]'],
            'none: an empty array';
            is [
                $class->new(
                    to_json(type => 'json', $json->()), from_json(type => 'json', $json->()),
                )->({a => 1}, [2])
            ],
            [{a => 1}, [2]], 'and from_json of the type undoes it';
            is [$class->new(to_json($json->()), from_json($json->()))->({a => 1}, [2])],
            [{a => 1}, [2]], 'as their defaults do';
            like dies {
                $class->new(to_json($json->()))->(sub { })
            },
            qr(Can't encode a value as JSON: \S), 'a value that cannot be encoded';
        };

    subtest "$name: to_json writes a file, by its name or its type" => sub {
        my $values    = [{a => 1}, [2], 'three'];
        my $json_file = path('.json');
        is scalar $class->new(to_json(file => $json_file, $json->()))->(@$values),
            3,
            'gives how many';
        is slurp($json_file), qq([{"a":1},[2],"three"]\n),   '.json: one array';
        is read_all(file => $json_file, $json->()), $values, 'read back';

        my $lines_file = path('.jsonl');
        $class->new(to_json(file => $lines_file, $json->()))->(@$values);
        is slurp($lines_file), qq({"a":1}\n[2]\n"three"\n),   '.jsonl: JSON Lines';
        is read_all(file => $lines_file, $json->()), $values, 'read back';

        my $ndjson = path('.ndjson');
        $class->new(to_json(file => $ndjson, $json->()))->(1);
        is slurp($ndjson), qq(1\n), '.ndjson: JSON Lines';

        my $typed = path('.json');
        $class->new(to_json(file => $typed, type => 'jsonl', $json->()))->(1, 2);
        is slurp($typed), qq(1\n2\n), 'type, over the name';

        my $empty = path('.json');
        is scalar $class->new(to_json(file => $empty, $json->()))->(), 0, 'none';
        is slurp($empty), qq([]\n), 'an empty array';

        my $stopped = path('.json');
        $class->new(take(2), to_json(file => $stopped, $json->()))->(1, 2, 3);
        is slurp($stopped), qq([1,2]\n), 'a stop before it still closes the array';
    };

    subtest
        "$name: to_json writes a filehandle, as JSON Lines unless its type is json"
        => sub {
            my $out = '';
            open my $fh, '>:raw', \$out or die $!;
            is scalar $class->new(to_json(fh => $fh, $json->()))->(1, [2]), 2,
            'gives how many';
            is $out, qq(1\n[2]\n), 'JSON Lines';
            ok defined fileno($fh) || 1, 'left open';
            print { $fh } 'more' or die $!;
            $class->new(to_json(fh => $fh, type => 'json', $json->()))->(3);
            is $out, qq(1\n[2]\nmore[3]\n), 'type json: one array';
            close $fh;
        };
}

subtest 'to_json indents an array of values, if its encoder does' => sub {
    my $path = path('.json');
    $class->new(to_json(file => $path, json => {pretty => 1, canonical => 1}))
        ->({a => 1}, [2]);
    is slurp($path), <<~'JSON', 'each value indented in the array';
        [
           {
              "a" : 1
           },
           [
              2
           ]
        ]
        JSON
    is read_all(file => $path), [{a => 1}, [2]], 'read back';
    is [$class->new(to_json(type => 'json', json => {pretty => 1}))->(1, 2)],
        ["[\n   1,\n   2\n]"],
        'the stage, as the encoder makes it, without its newline';
};

subtest 'json: options over the defaults, or an object as it is' => sub {
    is [$class->new(to_json(json => {canonical => 1}))->({b => 1, a => 2})],
        ['{"a":2,"b":1}'],
        'options';
    is [$class->new(to_json)->("\x{e9}")], [qq("\xc3\xa9")],
        'UTF-8 bytes by default';
    is [$class->new(to_json(json => {utf8 => 0}))->("\x{e9}")], [qq("\x{e9}")],
        'characters, with utf8 off';
    is [$class->new(from_json)->(qq("\xc3\xa9"))], ["\x{e9}"],
        'decoding UTF-8 bytes';
    my $object = JSON::PP->new->allow_nonref->canonical->space_after;
    is [$class->new(to_json(json => $object))->({b => 1, a => 2})],
        ['{"a": 2,"b": 1}'],
        'an object';
};

subtest 'A source given a filehandle is closed only by its opener' => sub {
    my $path   = path('.json', qq([1]\n));
    my $source = from_json(file => $path);
    my $next   = $class->new->iterator($source);
    is [$next->all], [1], 'read';
    ok lives { unlink $path }, 'and the file let go';
};

subtest 'Mistakes are reported at the caller\'s line' => sub {
    my %error = (
        'Expected options as name => value pairs'                => [qw(file)],
        'Expected the options file, fh, type and json, not flie' => [flie => 1],
        'Expected the options file, fh, type and json, not a, b' =>
            [b => 1, a => 2],
        'Expected a file or a filehandle, not both' => [file => 'x', fh => \*STDIN],
        'Expected an open filehandle'               => [fh   => undef],
        'Expected a type of json, jsonl or ndjson, not yaml' => [type => 'yaml'],
        'Expected json to be a hash reference of options, or an encoder object' =>
            [json => [1]],
    );
    for my $function (\&from_json, \&to_json) {
        for my $expected (sort keys %error) {
            is message(dies { $function->(@{ $error{$expected} }) }), $expected,
                $expected;
        }
        like dies { $function->(json => {nonsense => 1}) },
            qr(\AExpected json options the encoder knows: \S.* at \Q$file\E line \d+\.\n\z),
            'an option the encoder does not know';
    }
    like dies { to_json(file => path('.jsonl'), json => {pretty => 1}) },
        qr(\AExpected an encoder that doesn't indent, to write JSON Lines at \Q$file\E line),
        'JSON Lines, indented: by the name';
    like dies { to_json(json => {pretty => 1}) },
        qr(\AExpected an encoder that doesn't indent), 'by default, as a stage';
    ok lives { to_json(type => 'json', json => {pretty => 1}) },
        'but not of type json';
};

subtest 'Files that cannot be read or written' => sub {
    my $missing = "$dir/missing/x.json";
    like dies { read_all(file => $missing) },
        qr(\ACan't read \Q$missing\E: \S.* at \Q$file\E line), 'read';
    like dies { $class->new(to_json(file => $missing))->(1) },
        qr(\ACan't write \Q$missing\E: \S.* at \Q$file\E line), 'write';
    like dies { read_all(file => path('.json', '{"a":1}}')) },
        qr(\ACan't decode JSON from \S+: \S.* at \Q$file\E line), 'malformed';
    like dies { read_all(file => path('.json', '[1,')) },
        qr(\ACan't decode JSON from \S+: it ends inside a document at \Q$file\E line),
        'incomplete';
    open my $fh, '<:raw', path('.json', '{') or die $!;
    like dies { read_all(fh => $fh) },
        qr(\ACan't decode JSON from the filehandle: it ends inside a document),
        'a filehandle';
};

subtest 'Reads, writes and closes that fail' => sub {
    tie *FAILING, 'My::Failing::Handle';
    like dies { read_all(fh => \*FAILING) },
        qr(\ACan't read the filehandle: \S.* at \Q$file\E line), 'a read';
    like dies { $class->new(to_json(fh => \*FAILING))->(1) },
        qr(Pipeline stage #1 failed .*\n\s+Can't write the filehandle: \S.* at \Q$file\E line),
        'a write';
    my $path = path('.json');
    local $FAIL_CLOSE = 1;
    like dies { $class->new(to_json(file => $path))->(1) },
        qr(Pipeline end of stage #1 failed .*\n\s+Can't write \Q$path\E: \S.* at \Q$file\E line),
        'a close';
};

subtest 'An encoder of your own needs only encode, to write' => sub {
    is [$class->new(to_json(json => My::Encoder->new))->(1, 2)], ['<1>', '<2>'],
        'one that cannot say whether it indents is taken not to';
};

subtest 'In a chain, with Ekorn::Pipeline::Sinks' => sub {
    my $path = path('.jsonl');
    $class->new(to_json(json => {canonical => 1}), to_file($path))
        ->({a => 1}, {b => 2});
    is slurp($path), qq({"a":1}\n{"b":2}\n), 'the stage, written by to_file';
    is [$class->new(keep_all)->iterator(from_json(file => $path))->all],
        [{a => 1}, {b => 2}], 'read back';
};

done_testing;
