# 2026-0010. Named pipelines at compile time

**Status:** open

**Decisions:** revisited on 2026-11-14, against the design of 2026-0022
and the items since. D1 settled: stages after values, as a pipeline
given last. D2 settled: no source of its own; 2026-0012 was dropped.
D3 settled: names per package, which can be qualified. D4 settled: no
pull form; `pipeline('name')->iterator`. D5 settled: one definition
can name any other in the same `use`, in a hash or an array of pairs,
defined in the order they need. D6 settled: a public `import_into`,
which DBIx::Squirrel's Sugar can use for a `pipeline` key. D7 settled:
a string where a stage goes names a pipeline. D8 settled: names
checked, and clashes reported, as DBIx::Squirrel::Sugar does, with
the helpers kept private. D9 settled: in v0.3.0. D10 settled: plain
Ekorn::Pipelines, as DBIx::Squirrel's are now. D11 settled: called
Ekorn::Pipeline::Sugar. None open.

**Origin:** roadmap, added 2026-11-10, from Iain: the one feature
Ekorn-Pipeline lacks is something like DBIx::Squirrel::Sugar, to
make and name pipelines at compile time

**Depends on:** 2026-0011, which makes `pipeline(...)` and keeps the
names

## Background

To reuse a pipeline, a program keeps a `my $p` in scope, or writes a
sub around `Ekorn::Pipeline->new`. DBIx::Squirrel::Sugar
(DBIx-Squirrel 17a685b027e1a7c84a53893fdbb48ad63ba9ee06) names
databases and statements: `use DBIx::Squirrel::Sugar statement =>
{...}` gives the package a function of each name, and `statement(...)`
does the same as the program runs. Its statement functions take bind
values, then stages, told apart by `is_stage`, which works because a
bind value is never a code reference.

The same shape for pipelines:

```perl
use Ekorn::Pipeline::Sugar pipeline => {
    active_roles => [sub { $_->{active} ? $_ : () }, sub ($u) { @{ $u->{roles} } }],
    shout        => [sub { uc }],
};

my @roles = active_roles(@users);           # values in, a list out
my @loud  = shout(active_roles(@users));

use Ekorn::Pipeline qw(pipeline);
Ekorn::Pipeline->named(top_five => 'active_roles', take(5));
my $next = pipeline('top_five')->iterator($source);
```

As first sketched, Sugar also exported `pipeline`, to fetch a named
pipeline and define one as the program runs; 2026-0011 moved both to
Ekorn::Pipeline, as `pipeline(...)` and `named`.

It needs no new dependency: Ref::Util and namespace::clean are in the
`cpanfile` already, and Sugar's `_install`, with DBIx::Squirrel::Util's
`install_sub` and `is_name`, would come over, built on Sub::Util,
which is core.

## Decisions

- [x] **D1.** Can a named pipeline's function take stages after its
  values? Yes, as a pipeline given last, decided on 2026-11-10:
  `active_roles(@users, pipeline(sub { uc }))`, as 2026-0011's D2
  says. Earlier the same day it was no, as a code reference given last
  can't be told from a value; 2026-0011's `pipeline(...)` makes stages
  that can.
- [x] **D2.** Can a named pipeline have a source of its own? Moved to
  roadmap idea 2026-0012, as Iain decided on 2026-11-10. He had
  disagreed with a call with no arguments returning an empty list: "It
  could be a function that takes no arguments but still allows result
  transformations." The transformations are settled by D1:
  `recent(pipeline(take(5)))`. Left for 2026-0012: whether a
  definition can start with a source, a function that makes the
  values, so that a call with no values has something to give, and
  how a source is told from a first stage, such as by a key, `recent
  => [source => sub {...}, @stages]`. Until then, a function covers
  it: `sub recent (@stages) { pipeline(@stages)->(load_recent()) }`.
  **Revisited on 2026-11-14:** 2026-0012 was dropped by 2026-0022's
  D35 ("if there's a need, it'll be found again"), so a named pipeline
  has no source of its own, and the function above is the way.
- [x] **D3.** Where do names live? In the package that defines them,
  decided on 2026-11-10, so two modules can't clash; a qualified name,
  `pipeline('My::Module::active_roles')`, reaches another package's.
- [x] **D4.** Does the named function need a pull form? No, decided on
  2026-11-10: `pipeline('name')->iterator($source)` is enough.
- [x] **D5.** Can one definition name another given in the same `use`?
  Yes, any other, decided on 2026-11-10. Definitions can be given as a
  hash, `{...}`, or as an array of pairs, `[...]`, Iain's suggestion,
  so they can be read in order. Either way, each is defined once the
  names it uses from the same `use` are, so the order they're given in
  doesn't matter: every name a definition uses is a string, seen
  before anything is defined. A cycle croaks, as does a name defined
  nowhere, when the `use` is compiled, as 2026-0011's D1 wants. The
  docs say so in a sentence: a definition can name any other in the
  same `use`.

  Decided first, the same day: a hash defined in sorted order, and an
  array in the order given, each definition naming only one before
  it. It was deterministic, but a trap: `top_five => ['active_roles',
  ...]` works, as `a` sorts before `t`, and renamed `all_five` it
  fails, with nothing else changed.
- [x] **D6.** What does DBIx-Squirrel do with it? Nothing yet, decided
  on 2026-11-10. A named pipeline is a pipeline, so it already works as
  a statement's stage in DBIx::Squirrel::Sugar. Iain is considering
  having DBIx::Squirrel::Sugar take a `pipeline` key, handed on to this
  module, so one `use` names databases, statements and pipelines:

  ```perl
  use DBIx::Squirrel::Sugar
      database  => { music => [...] },
      statement => { artist_names => [music => $sql, 'clean_names'] },
      pipeline  => { clean_names => [sub { $_->[0] }, sub { s( \s+ \z )()xr }] };
  ```

  Called from DBIx::Squirrel::Sugar's `import`, this module's would
  see DBIx::Squirrel::Sugar as its caller, and define the names and
  install the functions there. So `import` is a thin wrapper around a
  public `import_into($package, @args)`, which DBIx::Squirrel::Sugar
  calls with its caller:

  ```perl
  Ekorn::Pipeline::Sugar->import_into($package, pipeline => $definitions);
  ```

  rather than a `goto &import`, or Import::Into, a dependency. When
  this ships, a message tells DBIx-Squirrel so, and that:
  - a statement naming a pipeline needs the `pipeline` key defined
    first, which its Sugar, defining keys in the order given, would
    have to see to;
  - its Sugar could take `install_sub` and `is_name` from here, rather
    than keep copies;
  - its docs could show a named pipeline as a statement's stages.

  Whether to do any of it is for DBIx-Squirrel's session and Iain.

  **Revisited on 2026-11-14:** D10 had set this aside, as
  DBIx::Squirrel then made its own pipelines. Since 2026-11-12
  DBIx::Squirrel uses Ekorn as it is, so its pipelines are
  Ekorn::Pipelines, and handing a `pipeline` key to this module is
  again the simple way. So `import_into($package, pipeline => {...})`
  is public, as Iain decided, documented for any module that adds to
  the sugar, which fits the rule that Ekorn adds only what any package
  could use; `import` is a thin wrapper around it. When it ships, a
  message tells DBIx-Squirrel it can, and that a statement naming a
  pipeline from the same `use` needs the `pipeline` key defined
  first. Whether to use it is for DBIx-Squirrel's session.
- [x] **D7.** How does a definition name another in the same `use`?
  By a string where a stage goes, decided on 2026-11-10, as
  2026-0011's D1 makes a name a stage everywhere:
  `top_five => ['active_roles', take(5)]`. The import list is
  evaluated before `import` runs, so `pipeline('active_roles')` in it
  would be called before `active_roles` is defined.
- [x] **D8.** How alike is it to DBIx::Squirrel::Sugar? Exactly, where
  they meet, decided on 2026-11-10, from a message from DBIx-Squirrel, 2026-11-10 (DBIx-Squirrel 60dd1af8f11b7661b4e47decadf9885d3e22a2d3): `is_name` is
  `m( \A [^\W\d] \w* \z )x`, and a clash croaks "Expected no
  function of the name in %s already (%s)". So one `use` naming
  databases, statements and pipelines reports mistakes alike, and
  DBIx::Squirrel can take `install_sub` and `is_name` from here with
  no change its users see.

  **Revisited on 2026-11-14:** alike, but not shared, as Iain decided.
  The rule for a name and the clash message match DBIx::Squirrel's,
  so mistakes read alike, but `install_sub` and `is_name` stay
  private: they aren't about pipelines, and exported, they'd be part
  of Ekorn's contract with other packages, its protocols, which a
  change would make a new middle version.
- [x] **D9.** What version does it ship in? A v0.2.x, decided on
  2026-11-10, as 2026-0011's D7: it only adds. **Revisited on
  2026-11-14:** v0.2.x has passed; it ships in v0.3.0, as Iain
  decided, which now depends on it.
- [x] **D10.** What class are its pipelines made with?
  Ekorn::Pipeline, always, decided on 2026-11-11 with 2026-0020's D4,
  that DBIx::Squirrel's things stay in its namespace. This module
  doesn't make, name or hold pipelines for DBIx::Squirrel, so
  DBIx::Squirrel::Sugar's `pipeline` key, its 2026-0010, defines its
  own with `DBIx::Squirrel::Pipeline->named`, rather than through
  `import_into` as D6 had it. D6's `import_into` stays, for other
  modules adding to this one's sugar. If DBIx::Squirrel wants this
  module's ordering of definitions and its cycle check (D5), they can
  be a function that makes nothing, which its Sugar calls before
  defining its own; that's for when it asks. Weighed and set aside the
  same day: a `pipeline_class` method on this module, overridden by a
  subclass of DBIx::Squirrel's, and a class passed to `import_into`;
  both would have this module make DBIx::Squirrel's pipelines.
  **Revisited on 2026-11-14:** `DBIx::Squirrel::Pipeline` is gone;
  since 2026-11-12, DBIx::Squirrel uses Ekorn as it is, so its
  pipelines are Ekorn::Pipelines too, and this holds with nothing to
  set aside. D6's `import_into` is how its Sugar would define them.
- [x] **D11.** What's the module called? **Ekorn::Pipeline::Sugar,**
  Iain decided on 2026-11-14, as the item has it, matching
  DBIx::Squirrel::Sugar, so a `use` of either reads alike. Its
  `import` isn't a word, so it's a module of its own, not part of
  Factories.
