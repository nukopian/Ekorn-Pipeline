use v5.36;
use Test2::V0;
use Test2::Plugin::NoWarnings;

# A subclass of Ekorn::Pipeline as its descendant: pipeline, imported
# through it, makes it, and Pipes makes the class it's told to
# (roadmap 2026-0020).

use Ekorn::Pipeline qw(pipeline);
use Ekorn::Pipeline::Stages::Flow;

my $file = __FILE__;

# A subclass, as DBIx::Squirrel::Pipeline is, with a name of its own to
# export.
package My::Pipeline {
    our(@ISA, @EXPORT_OK);
    BEGIN { @ISA = 'Ekorn::Pipeline'; @EXPORT_OK = qw(helper) }
    sub helper () { 'helped' }
}

# A module re-exporting the subclass's pipeline to its users, as
# DBIx::Squirrel does.
package My::Module {
    BEGIN { My::Pipeline->import(qw(pipeline)) }
    use Exporter qw(import);
    our @EXPORT_OK;
    BEGIN { @EXPORT_OK = qw(pipeline) }
}

# Its user, with pipelines named in its own package.
package My::User {
    BEGIN { My::Module->import(qw(pipeline)) }
    Ekorn::Pipeline->named(doubled => sub { $_ * 2 });
    sub make (@stages) { pipeline(@stages) }
}

subtest 'pipeline, imported through a subclass, makes the subclass' => sub {

    package My::Direct {
        BEGIN { My::Pipeline->import(qw(pipeline helper)) }
        use Test2::V0;
        my $p = pipeline(sub { $_ + 1 });
        isa_ok $p, 'My::Pipeline';
        is [$p->(1, 2)], [2, 3],   'which runs as any pipeline does';
        is helper(),     'helped', 'and the subclass\'s own names are exported too';
    }
};

subtest 'It looks names up in the package that calls it' => sub {
    my $p = My::User::make('doubled', take(1));
    isa_ok $p, 'My::Pipeline';
    is [$p->(3, 4)], [6], 'after being re-exported, in its user\'s package';
    like dies { My::User::make('nowhere') },
        qr( \A No\ pipeline\ named\ My::User::nowhere\  )x,
        'and not in the module that re-exported it';
};

# A subclass with an import of its own, as a facade exporting other
# names would have, which asks for pipeline itself.
package My::Facade {
    use Exporter qw(import);
    our(@ISA, @EXPORT_OK);
    BEGIN { @ISA = ('Ekorn::Pipeline') }
    BEGIN { __PACKAGE__->SUPER::import('pipeline') }
    BEGIN { @EXPORT_OK = qw(pipeline) }
}

package My::Facade::User {
    BEGIN { My::Facade->import(qw(pipeline)) }
    My::Facade->named(quiet => sub { lc });
    sub make (@stages) { pipeline(@stages) }
}

subtest 'A subclass with its own import asks for pipeline itself' => sub {
    like dies {

        package My::Exporting
        { use parent -norequire, 'Ekorn::Pipeline'; use Exporter qw(import) }
        My::Exporting->import(qw(pipeline));
    },
        qr( "pipeline" \ is\ not\ exported\ by\ the\ My::Exporting\ module )x,
        'without it, its import refuses pipeline';
    my $p = My::Facade::User::make('quiet');
    isa_ok $p, 'My::Facade';
    is [$p->('LOUD')], ['loud'],
        'with SUPER::import, its Exporter exports one making the subclass, looking names up in its user\'s package';
};

subtest 'Ekorn::Pipeline\'s own pipeline is unchanged' => sub {
    is ref(pipeline()), 'Ekorn::Pipeline';
    ref_is \&pipeline, \&Ekorn::Pipeline::pipeline, 'and is the same function';
};

subtest 'A subclass still croaks on a name it doesn\'t export' => sub {

    like
        dies { package My::Croaked; My::Pipeline->import(qw(pipeline nothing)) },
        qr( "nothing" \ is\ not\ exported\ by\ the\ My::Pipeline\ module )x;
};

subtest 'Names are kept per class, inherited one way' => sub {

    package My::Grandchild {
        use parent -norequire, 'My::Pipeline';
    }

    package My::Streams {
        BEGIN { My::Pipeline->import(qw(pipeline)) }
        sub mine   (@stages) { pipeline(@stages) }
        sub theirs (@stages) { Ekorn::Pipeline::pipeline(@stages) }
    }
    Ekorn::Pipeline->named('My::Streams::base' => sub { "base $_" });
    My::Pipeline->named('My::Streams::own' => sub { "own $_" });

    is [My::Streams::mine('base')->('x')], ['base x'],
        'a subclass sees the names defined through its ancestors';
    is [My::Streams::mine('own')->('x')], ['own x'],
        'and its own';
    like dies { My::Streams::theirs('own') },
        qr( \A No\ pipeline\ named\ My::Streams::own\  )x,
        'but an ancestor never sees its descendants\'';

    Ekorn::Pipeline->named('My::Streams::shared' => sub { "ekorn $_" });
    my $before = My::Streams::mine('shared');
    My::Pipeline->named('My::Streams::shared' => sub { "mine $_" });
    is [My::Streams::mine('shared')->('x')], ['mine x'],
        'a subclass can override a name its ancestor has';
    is [My::Streams::theirs('shared')->('x')], ['ekorn x'],
        'which the ancestor keeps';
    is [$before->('x')], ['ekorn x'],
        'and a pipeline made before the override keeps what it found';
    like dies {
        My::Pipeline->named('My::Streams::shared' => sub { $_ })
    },
        qr( \A A\ pipeline\ named\ My::Streams::shared\ is\ already\ defined\  )x,
        'but a class can\'t define a name it has defined itself';
    ok lives {
        Ekorn::Pipeline->named('My::Streams::own' => sub { "base's $_" })
    },
        'though an ancestor can define one its descendant has';
    is [My::Streams::mine('own')->('x')], ['own x'],
        'and the descendant still sees its own';
    is [My::Streams::theirs('own')->('x')], ["base's x"],
        'as the ancestor does';

    My::Grandchild->named('My::Streams::grand' => sub { "grand $_" });
    my $all
        = My::Grandchild->named('My::Streams::all' => map { "My::Streams::$_" }
            qw(base own grand),);
    is [$all->('x')], ['grand own base x'],
        'and down the line, each class sees its ancestors\' names';
    like dies { My::Streams::mine('grand') },
        qr( \A No\ pipeline\ named\ My::Streams::grand\  )x,
        'and not its descendants\'';

    my $p = Ekorn::Pipeline->new(sub { $_ });
    $p->named('My::Streams::plain');
    ok lives { My::Streams::theirs('plain') },
        'a pipeline named on itself is its own class\'s';
};

subtest 'Pipes: pipe and tap make the class pipeline_class names' => sub {

    package My::Piped {
        use parent -norequire, 'Ekorn::Pipeline::Pipes';
        sub new ($class) { bless {}, $class }
    }

    package My::Piped::Own {
        our @ISA = 'My::Piped';
        our @made;
        sub pipeline_class ($self) { 'My::Pipeline::Counted' }
    }

    package My::Pipeline::Counted {
        our @ISA = 'Ekorn::Pipeline';


        sub new ($class, @stages) {
            push @My::Piped::Own::made, $class;
            return $class->SUPER::new(@stages);
        }
    }
    require Ekorn::Pipeline::Pipes;

    is My::Piped->new->pipeline_class, 'Ekorn::Pipeline', 'by default';
    my $own = My::Piped::Own->new;
    is [$own->pipe(sub { 'piped' })], ['piped'], 'pipe, with a subclass\'s';
    ref_is $own->tap(sub { 1 }), $own, 'tap too';
    is \@My::Piped::Own::made,
        ['My::Pipeline::Counted', 'My::Pipeline::Counted'],
        'each made with the class it names';
};

done_testing;
