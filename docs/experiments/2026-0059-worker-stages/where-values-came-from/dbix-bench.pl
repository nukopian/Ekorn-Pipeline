use v5.36;
use Time::HiRes qw(time);
use DBIx::Squirrel;
use Ekorn::Pipeline;
use Ekorn::Pipeline::Tooling qw(:flow :batch :sinks);

# Count which of Ekorn's loops each run takes.
my %loop;
for my $name (qw(_plain_iterator _full_iterator _push_steps)) {
    no strict 'refs';    ## no critic (TestingAndDebugging::ProhibitNoStrict)
    no warnings 'redefine';
    my $orig = \&{"Ekorn::Pipeline::$name"};
    *{"Ekorn::Pipeline::$name"} = sub { $loop{$name}++; goto &$orig };
}

my $N   = 200_000;
my $dbh = DBIx::Squirrel->connect('dbi:SQLite:dbname=:memory:', '', '', {RaiseError => 1});
$dbh->do('CREATE TABLE artist (id INTEGER PRIMARY KEY, name TEXT)');
$dbh->begin_work;
my $ins = $dbh->prepare('INSERT INTO artist (id, name) VALUES (?, ?)');
$ins->execute($_, "artist $_") for 1 .. $N;
$dbh->commit;

my $sql = 'SELECT id, name FROM artist';
my %cases = (
    '1 map only'               => [sub { $_[0][1] }],
    '2 map, take'              => [sub { $_[0][1] }, take($N)],
    '3 map, batch(100)'        => [sub { $_[0][1] }, batch(100)],
    '4 map, count_items sink'  => [sub { $_[0][1] }, count_items],
    '5 map, take_last'         => [sub { $_[0][1] }, take_last],
);
for my $name (sort keys %cases) {
    my(@t, %took);
    for (1 .. 7) {
        %loop = ();
        my $s = time;
        # With a sink, iterate gives its result; otherwise an iterator.
        my $r = $dbh->iterate($sql, @{ $cases{$name} });
        my @r = ref $r ? $r->all : ($r);
        push @t, time - $s;
        %took = %loop;
    }
    @t = sort { $a <=> $b } @t;
    printf "%-26s %6.0f ns a row (median of 7)  loop: %s\n", $name, $t[3] / $N * 1e9, join ',', sort keys %took;
}
