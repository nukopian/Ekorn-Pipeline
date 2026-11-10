# 2026-0010. Named pipelines at compile time

**Status:** open

**Decisions:** D1 settled: no stages after values. D2 open: whether a
named pipeline can have a source of its own, and take stages when
called without values. D3 settled: names per package, which can be
qualified. D4 settled: no pull form; `pipeline('name')->iterator`.
D5 settled: one definition can name another, in order, in an
array of pairs or a sorted hash. D6 open: what DBIx-Squirrel does
with it. D7 open: how a definition names another in the same `use`.

**Origin:** roadmap, added 2026-11-10, from Iain: the one feature
Ekorn-Pipeline lacks is something like DBIx::Squirrel::Sugar, to
make and name pipelines at compile time

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

use Ekorn::Pipeline::Sugar qw(pipeline);
pipeline(top_five => [pipeline('active_roles'), take(5)]);
```

It needs no new dependency: Ref::Util and namespace::clean are in the
`cpanfile` already, and Sugar's `_install`, with DBIx::Squirrel::Util's
`install_sub` and `is_name`, would come over, built on Sub::Util,
which is core.

## Decisions

- [x] **D1.** Can a named pipeline's function take stages after its
  values? No, decided on 2026-11-10. Values going into a pipeline can
  be code references, so a trailing stage can't be told from a value.
  More stages come by composing: `pipeline('name')` is a stage.
- [ ] **D2.** What does a named pipeline's function do when called with
  no arguments? Iain, on 2026-11-10, disagreed with returning an empty
  list: "It could be a function that takes no arguments but still
  allows result transformations." Read as: a definition can start with
  a source, a function that makes the values, as a statement makes its
  rows; its function then takes no values, so whatever it's given is
  stages, run after its own, as Sugar's statement functions take them.
  `active_roles(@users)` stays as it is for a pipeline with no source.
  Awaiting Iain's word that this is what was meant, and how a source is
  told from a first stage in a definition (a key, such as
  `source => sub {...}`, or a form of its own).
- [x] **D3.** Where do names live? In the package that defines them,
  decided on 2026-11-10, so two modules can't clash; a qualified name,
  `pipeline('My::Module::active_roles')`, reaches another package's.
- [x] **D4.** Does the named function need a pull form? No, decided on
  2026-11-10: `pipeline('name')->iterator($source)` is enough.
- [x] **D5.** Can one definition name another given in the same `use`?
  Yes, decided on 2026-11-10, and documented plainly. Definitions can
  be given as a hash, `{...}`, defined in sorted order of their names,
  or as an array of pairs, `[...]`, defined in the order given, so the
  order is deterministic either way; a definition can name only one
  defined before it.
- [ ] **D6.** What does DBIx-Squirrel do with it? Iain asked for a
  recommendation. Recommended: nothing it has to. A named pipeline is
  a pipeline, so it already works as a statement's stage in
  DBIx::Squirrel::Sugar, `artist_names => [music => $sql,
  pipeline('clean')]`, with no change there. When this ships, send
  DBIx-Squirrel a message saying so, and offering two things for its
  session and Iain to decide: that its Sugar take `_install`,
  `install_sub` and `is_name` from Ekorn rather than keep copies, and
  that its docs show a named pipeline as a statement's stages. A new
  module is an addition, so it's a v0.1.x-style change, in the range
  DBIx::Squirrel takes, needing no release of its own.
- [ ] **D7.** How does a definition name another in the same `use`?
  The import list is evaluated before `import` runs, so
  `pipeline('active_roles')` inside it would be called before
  `active_roles` exists, and before `pipeline` is imported. The options:
  - **A.** A string where a stage goes names a pipeline, looked up when
    the definition is made: `top_five => ['active_roles', take(5)]`.
    Strings are allowed only in Sugar's definitions, not in
    `Ekorn::Pipeline->new`.
  - **B.** Only in separate `use` lines, or with `pipeline(...)` at run
    time; D5 then holds only across statements.

  Recommended: A, which is what D5 asks for.
