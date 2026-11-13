# 2026-0021. Ekorn::Pipeline::Factories

**Status:** in progress

**Decisions:** D1 settled: `pipeline` moves to a module of words. D2 settled: Ekorn::Pipeline::Factories, and DBIx::Squirrel::Factories. D3 settled: each word is one line over a class method taking the package; `new` stays strict. D4 settled: it exports `gather`, not `Stop`. D5 withdrawn: there are no `step` and `end`. D6 settled: `pipeline_in`. D7 settled: no.

**Origin:** roadmap, added 2026-11-11, from Iain, reviewing 2026-0020:
"`pipeline` IS behaving like a factory but the short keyword-like name
is the cosmetic point of its very existence"

**Depends on:** 2026-0011 and 2026-0020, unreleased, whose `pipeline`
it moves, and 2026-0014, the lifecycle, shipped unreleased

**Started:** 2026-11-13

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
  2026-0015's to choose. Withdrawn on 2026-11-11: the design for
  2026-0022 has `source` and `sink` take a set-up returning closures,
  as `gather` does, so there are no `step` and `end` to export.
- [x] **D6.** What's the class method called? It makes a pipeline of
  the stages given, names among them looked up in a package it's
  given. Options: `pipeline_in($package, @stages)`, the name
  2026-0011's D5 weighed for it, reading "a pipeline, in a package";
  or `new_in($package, @stages)`, reading as `new` with a package.
  Recommended: `pipeline_in`, as `new_in` suggests `new` with an
  option, when it's the one place names are read. Settled so by Iain on
  2026-11-12, as the design's Q10, in 2026-0022's D37.
- [x] **D7.** Does Ekorn::Pipeline still export `pipeline`, as a
  re-export of Factories', for code written against 2026-0011? Nothing
  has shipped, and DBIx-Squirrel, its only user, is paused, so
  recommended: no. One home for each word; a re-export from the class
  would bring back the question of which class it makes. Settled so by
  Iain on 2026-11-12, as the design's Q17, in 2026-0022's D30.

## The plan

As the roadmap gave it on 2026-11-13, with the design approved that
day (2026-0022, its 17.3, 17.4 and 20.1, and the draft reference's
Words and pipeline_in):

**What:** the words that make Ekorn's types, in
Ekorn::Pipeline::Factories, each one line over a class method:
`stage`, `source`, `generator` with `yield`, `sink_one`, `sink_many`,
`gather`, and `pipeline`, moved from Ekorn::Pipeline. It takes in
2026-0015, retired into it, and undoes 2026-0020: names belong to a
package, not a class, and Pipes' `pipeline_class` goes.

**Why:** a word is syntax, not behaviour, so a class shouldn't hold
it (D1); and with other packages using Ekorn as it is, rather than
subclassing it (the design's 17.3), names per class and
`pipeline_class` serve no one (17.4).

**Steps:**

1. Ekorn::Pipeline gains `pipeline_in($package, @stages)`, the one
   method reading names (D3, D6), and loses `pipeline` and its own
   `import`, going back to Exporter's, exporting `is_stage` and
   `is_sink` on request (D7).
2. Names go back to one per qualified name, as 2026-0011 had them:
   no lookup through a class's ancestors, and `named` keeps a name in
   its caller's package unless it's qualified, croaking at a name
   already defined for another pipeline.
3. Factories' `pipeline` is `Ekorn::Pipeline->pipeline_in(scalar
   caller, @stages)`, exported on request with the other words.
4. Pipes' `pipeline_class` goes; `pipe` and `tap` make
   Ekorn::Pipelines.
5. Tests: `t/13` and `t/14`, for `pipeline` and names, rewritten for
   Factories and names per package; Factories' words tested, the
   design's proofs for them included; coverage of Factories in full.
6. POD: Factories written in full; Ekorn::Pipeline's names per
   package, `pipeline_in`, and its sections on subclasses gone; Pipes
   without `pipeline_class`.
7. Docs: the reference's Words and `pipeline_in`, Named pipelines per
   package, and its sections on subclasses gone; the how-to's two
   recipes using `pipeline` from Factories; the examples 2026-0014
   wrote with `Source->new` and `Sink->new_sink_one` switched to the
   words. The manuals made again.
8. CLAUDE.md's factories rule says `pipeline` lives in Factories only
   (the design's D30). The records of 2026-0011 and 2026-0020 say what
   this undid or moved.
9. DBIx-Squirrel is told: its paused 2026-0009 waits on this, and it
   loses Ekorn::Pipeline's `pipeline` and Pipes' `pipeline_class`.
10. `Changes`, its line ending "(roadmap 2026-0021)".

**Done when:** the module, its tests and docs are in, with
Factories' coverage complete, and `Changes`.

## What happened

Nothing yet.
