# 2026-0021. Ekorn::Pipeline::Factories

**Status:** open

**Decisions:** D1 settled: `pipeline` moves to a module of words. D2 settled: Ekorn::Pipeline::Factories, and DBIx::Squirrel::Factories. D3 settled: each word is one line over a class method taking the package; `new` stays strict. D4 settled: it exports `gather`, not `Stop`. D5 settled: `step` and `end` only under a tag. D6 open: the class method's name. D7 open: whether Ekorn::Pipeline still exports `pipeline`.

**Origin:** roadmap, added 2026-11-11, from Iain, reviewing 2026-0020:
"`pipeline` IS behaving like a factory but the short keyword-like name
is the cosmetic point of its very existence"

**Depends on:** 2026-0011 and 2026-0020, unreleased, whose `pipeline`
it moves

## Background

2026-0011 put `pipeline` in Ekorn::Pipeline, exported on request: a
short way to make a pipeline whose stages can be names. 2026-0020 made
it, imported through a subclass, make that subclass, with an `import`
of Ekorn::Pipeline's own that installs a function made for the class
it was imported through. A cold review of the docs on 2026-11-11 found
what that costs: a subclass with an `import` of its own, such as
Exporter's, loses `pipeline` unless it calls
`__PACKAGE__->SUPER::import('pipeline')` from a `BEGIN` block, with
`@ISA` set in one before it; a package can have only one `pipeline`;
`DBIx::Squirrel::Pipeline::pipeline(...)` exists only if the facade
installs it; and `DBIx::Squirrel::Pipeline->pipeline(...)`, the call a
factory looks like, takes the class's name for a pipeline's.

Iain's point: `new` already makes pipelines, so `pipeline` exists only
for its short name. It's syntax, not behaviour, and the first of a
family: 2026-0015 adds `source {...} step {...} end {...}`, `stage`,
`sink`, `step`, `end` and gather's new form, each making one of
Ekorn's types, and each wanted by DBIx::Squirrel in a form making its
own. A class shouldn't hold syntax, and in a module of words each word
is one line, with no `import` tricks.

Nothing of 2026-0011's or 2026-0020's `pipeline` has reached CPAN, so
moving it costs users nothing. DBIx-Squirrel was asked on 2026-11-11
to pause its 2026-0009, which exports `pipeline`, until this is built
(DBIx-Squirrel 29ff4fa47f078dacee7b2b433b4cd620413d1368).

## Decisions

- [x] **D1.** Where does `pipeline` live? In a module of words, not in
  Ekorn::Pipeline, Iain decided on 2026-11-11, as above. Weighed and
  set aside: 2026-0010's Sugar, whose import list takes definitions,
  `use Ekorn::Pipeline::Sugar pipeline => {...}`, so `pipeline` would
  mean two things on one `use` line; and Sugar, in Perl, usually means
  definitions made as a program compiles, as DBIx::Squirrel::Sugar
  does, where these words are used in expressions as it runs.
- [x] **D2.** What's the module called? Ekorn::Pipeline::Factories,
  Iain decided on 2026-11-11: it names what every word in it does.
  2026-0015's module, planned as Blocks, becomes part of it, as
  "Blocks is a lie": `pipeline` takes no block. DBIx::Squirrel's words
  go in DBIx::Squirrel::Factories, Iain decided the same day, following
  its mapping of `Ekorn::Pipeline::X` to `DBIx::Squirrel::X`, as its
  Gather, Stop, Pipes and Stages do, rather than
  DBIx::Squirrel::Pipeline::Factories, a level deeper than the rest.
- [x] **D3.** How does a word make the right class, and read names in
  the right package? Each word is one line over a class method of the
  class it makes, which takes the package to look names up in, passed
  from the word's caller:

  ```perl
  sub pipeline (@stages) { Ekorn::Pipeline->...(scalar caller, @stages) }
  ```

  DBIx::Squirrel::Factories' `pipeline` is the same line on
  DBIx::Squirrel::Pipeline, which inherits the method, so it makes its
  own class and keeps its own names, and Ekorn makes nothing for it.
  Ekorn::Pipeline goes back to Exporter's `import`. Decided on
  2026-11-11, with D1.

  `new` stays strict, reading no names, and there's no second
  constructor that reads names in its caller's package, such as an
  `of`, weighed and set aside the same day. Names must be resolved
  where the user writes them, and `new` is called mostly by code in
  between: Pipes' `pipe`, DBIx::Squirrel's `iterate`, and any function
  taking stages from its caller, the pattern the library is for. Its
  caller is that code, so it would look `clean` up in the library's
  package, not the user's. A word is called by the user, in their own
  code, and hands `new` real pipelines. This is a stronger reason for
  2026-0011's D4 than the one it gave.
- [x] **D4.** What else does Factories export? `gather`, a factory,
  decided on 2026-11-11; it stays in Ekorn::Pipeline::Gather too. Not
  `Stop`, which throws rather than makes.
- [x] **D5.** How are `step` and `end` exported? Only under a tag, with
  the block factories, decided on 2026-11-11, so a short, common name
  like `end` is never imported alone by accident. The tag's name is
  2026-0015's to choose.
- [ ] **D6.** What's the class method called? It makes a pipeline of
  the stages given, names among them looked up in a package it's
  given. Options: `pipeline_in($package, @stages)`, the name
  2026-0011's D5 weighed for it, reading "a pipeline, in a package";
  or `new_in($package, @stages)`, reading as `new` with a package.
  Recommended: `pipeline_in`, as `new_in` suggests `new` with an
  option, when it's the one place names are read.
- [ ] **D7.** Does Ekorn::Pipeline still export `pipeline`, as a
  re-export of Factories', for code written against 2026-0011? Nothing
  has shipped, and DBIx-Squirrel, its only user, is paused, so
  recommended: no. One home for each word; a re-export from the class
  would bring back the question of which class it makes.

## The plan

Written when work starts.

## What happened

Nothing yet.
