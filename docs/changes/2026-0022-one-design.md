# 2026-0022. One design, end to end, before more is built

**Status:** in progress

**Decisions:** D1 settled: DBIx::Squirrel uses Ekorn as it is. D2
settled: the design ships as v0.3.0, on `pipeline-experimental` until
then. D3 settled: the design is proved by code in the core. D4
settled: Ekorn's types are Elements. D5 settled: one method per role,
`as_source`, `as_stage`, `as_scalar`, `as_list`. D6 open: when a sink and a source are told how the run ended. D7
open: what a stage asks about its run. D8 open: `|` opt-in for the
program, or for the code. D9 open: a reusable source of a sink's
result.

**Origin:** roadmap, added 2026-11-11

**Started:** 2026-11-11, in 82f609762895ff4e74c249cdb9a6678d301f36f3

## Background

The work for sources, sinks, words and names had been split into
roadmap items, here and in DBIx-Squirrel, each designed on its own.
Decisions made one at a time kept turning out to bite later: one name
registry for every class, Ekorn's Sugar making DBIx::Squirrel's
pipelines, a facade's `import` losing `pipeline`. So development was
paused while one design was written for all of it, in `docs/design/`.
The design's own open questions are numbered Q1 and on, in its section
16; this record keeps the decisions about the item itself.

## Decisions

- [x] **D1.** How does DBIx::Squirrel build on Ekorn? It uses Ekorn as
  it is, as any package would, Iain decided on 2026-11-12: it delivers
  sources, sinks and stages that keep Ekorn's protocols, and runs them
  in Ekorn's own pipelines, subclassing and wrapping nothing; Ekorn
  makes that pattern possible for any package, and changes nothing for
  one. Why: the facade of subclasses it replaces had coupled the two
  designs, and did nothing a database needs. The design's principles 2
  and 3, and its 17.3, have the rest.
- [x] **D2.** Which release? v0.3.0, Iain decided on 2026-11-12, and
  everything stays on `pipeline-experimental` until then. The design's
  section 13.
- [x] **D3.** Where is the code that proves the design built? In the
  core, on `pipeline-experimental`, Iain decided on 2026-11-12, so that
  it proves the design fits today's run loop, stops and gathers, not
  only itself. Whether it's kept once the design is split into items
  is the design's Q19.
- [x] **D4.** Blessed code references, or classes? Classes, Iain
  decided on 2026-11-12: each type a class on a base,
  Ekorn::Pipeline::Element, a hash overloading `&{}` as Ekorn::Pipeline
  always was, and a plain code reference given to a pipeline made a
  Stage, so a pipeline is made of Elements, and `stages` returns them.
  Why: blessed code references have no fields, so their state lived in
  address-keyed hashes, and the closure trap of finding 8 came with
  them. The design's principle 6 and 17.13.

- [x] **D5.** How does a part declare its role, so that a package's
  own parts can take any role Ekorn's can, without being Ekorn's
  classes? By one method per role, Iain decided on 2026-11-12:
  `as_source`, to be read from; `as_stage`, to pass values through,
  with an end; and, to be a sink, `as_scalar`, its result one value,
  or `as_list`, its result a list. A part offers at most one of the
  two sink methods, which is an error caught when the pipeline is
  made. The role a part is given in decides which method is called,
  so one object can offer several, as a table read from and written
  to. A sink's step's return is ignored; a stage's goes on, which
  settles finding 13. A code reference offers none, and takes the role
  it's given in, with no end. What each method returns waits on D6,
  and, for `as_source`, on D7. Why: from the cold review's S1,
  `for_run` served every role, and the core told them apart by Ekorn's
  classes and by position, so a package's own parts couldn't take
  every role; and `|` needs to know whether a sink gives a value or a
  list. Weighed: `for_run` with a `role` method; the role decided by
  position, unchecked; `as_sink` with a `gives_list` flag. The
  design's 4.4, 5.2 and 17.14.
- [ ] **D6.** When are a sink and a source told how the run ended?
  From S2: a sink's end gives its result and is told `done` when its
  own stream ends, so a stage dying after it leaves it committed.
  Separating "give your result" from "the run has ended, and how" is
  the direction.
- [ ] **D7.** What does a stage ask, to know about its run? From S3:
  `run_source()` gives the source object, shared by all its runs, not
  the run. A context for the run, from the source's set-up, is the
  direction. Q21 waits on it.
- [ ] **D8.** Is `|` opt-in for the program, or for the code that
  loads Operators? From S4: overloading belongs to a class, so loading
  Operators gives `|` everywhere. Saying so plainly is the
  recommendation.
- [ ] **D9.** How is a sink's result had as a source that can run more
  than once? From S5: an Iterator is one run, and gives nothing to a
  second. A Source made from a pipeline and a source, making an
  iterator for each run, is the direction.

## The plan

As the roadmap gave it on 2026-11-11:

> Development is paused, here and in DBIx-Squirrel's work touching
> Ekorn, as Iain decided on 2026-11-11, while one design is written for
> everything planned in both repositories, in `docs/design/`: the
> concepts as a whole (sources, stages, gathers, sinks, pipelines, runs
> and their ends, names, subclasses, factories), the modules on both
> sides, how DBIx::Squirrel builds on Ekorn, what's compatible, and the
> questions still open; with drafts of the sections the reference and
> the how-to would gain. Why: the work had been decomposed into items
> whose decisions, made one at a time, kept turning out to bite later,
> here or in DBIx-Squirrel. DBIx-Squirrel reviews it, as Ekorn's first
> user, and sends its view as messages. Done when Iain has approved the
> design, and only then is it decomposed into items, which replace or
> rewrite those below. What's on `pipeline-experimental` (2026-0011,
> 0020) is provisional until then.

## What happened

- **Changes from the plan:** the design is proved by code before it's
  approved (the design's section 19), and DBIx::Squirrel uses Ekorn as
  it is (D1), so "subclasses" left the concepts.

### The prototype, 2026-11-12

Built in the core, on `pipeline-experimental`, to section 19.3: the
lifecycle in `_iterator`; Stage, Source, Sink and Iterator classes;
`stage`, `source`, `sink` and `gather` in Factories; `from_file` and
`from_arrayref`; `to_file`, `to_array`, `count` and `first_value`; and
`|` from a source. `t/15-proofs.t` runs the proofs.

- **Every proof holds,** on Perl 5.36, 5.38, 5.40, 5.42 and 5.44,
  under yath and prove: a source joined directly to a sink copies,
  record for record, and both are told how the run ended, the source
  last, whether it ran out, was stopped by `first_value`, or died; a
  complete pipeline used as a source ends its inner run at the first
  pull, and a stop or a die in the outer run doesn't reach it; without
  a sink, the inner run is pulled only as needed, and told `stopped`
  by the outer stop; an abandoned iterator ends its run. Q5 and Q6
  behave as recommended. All the existing tests pass unchanged.
- **The pattern of D1 works,** with a package outside Ekorn's
  namespace standing for DBIx::Squirrel: a source class of its own,
  with `for_run` and a `columns` method, and a stage of its own asking
  `Ekorn::Pipeline::run_source()` for the columns (Q21's recommended
  answer), composed with Ekorn's `take` and `to_array`, pulled or with
  `|`. Nothing of Ekorn's is subclassed or wrapped.

What the prototype found, for the design to take in:

1. **The source's end runs as soon as no end is left,** not when the
   last value has been handed out. Otherwise a pipeline ending in
   `to_array`, used as a source, would end its run only at its last
   value, not at the first pull, as 19.2 says. Section 5.4 should say
   when the source's end runs.
2. **An iterator used as a source is ended through it.** An outer run
   tells its source how it ended; an iterator, a run already, needs a
   way to be told: here, a `finish($how)` method, which is also what
   its `DESTROY` calls. Section 4.4's protocols should include it.
3. **A sink that stops the run is told `done`,** and its end gives
   the result, as section 8.3 says for `first_value`. The core does it
   by calling the stopping stage's end, if it's a sink, rather than
   passing over it as a stop does a gather's.
4. **An operator must know whether a sink gives a list,** to give one
   value or an array reference (section 9). The prototype marks it
   when the sink is made, `Ekorn::Pipeline::Sink->new($setup, list =>
   1)`; `sink {...}` makes one giving one value. The design should say
   how a list-giving sink is declared.
5. **`iterator` takes any object made for a run,** not only a code
   reference, so a package's own source class works as it is. That
   answers Q13 without an `is_source`.
6. **A package's own source class gets `|` by overloading it with
   Ekorn's function,** `use overload '|' =>
   \&Ekorn::Pipeline::Operators::chain`. That uses Ekorn as it is, and
   section 9 should say so.
7. **A source's and a sink's set-up run when the iterator is made,**
   as a gather's do today, so `from_file` opens its file then, not at
   the first pull. An iterator let go unpulled still closes it. Whether
   set-ups should wait for the first pull is for the design to say.
8. **A blessed code reference must be a closure.** Perl gives every
   call of an anonymous sub that closes over nothing the same code
   reference, so every sink was one object, until the Q6 tests caught
   it. Each class's code reference now closes over what it was made
   with.
9. **A source given as a stage croaks,** "Expected stage #%d to be a
   stage, not a source", as a source made with `source {...}` was
   then a code reference, as a stage is.
10. **A source called as a plain code reference,** outside a run,
    makes a run of its own, which is never ended. The design says
    every type works where a code reference does; for a source, that
    means no end.
11. **`to_file` in paragraph mode** writes a blank line after each
    record, as `chomp` took off all the newlines there were.

### The implementation document, 2026-11-12

`docs/design/IMPLEMENTATION.md` describes what's built, with examples
that run, and sets the design beside the code, part by part. Writing
it found three more things:

12. **An iterator ended from outside didn't stop.** After `finish`, or
    once let go, its run's source had been told it ended, but calling
    the iterator again went on pulling from it: for `from_file`, a
    closed file. Ended from outside, a run now also stops, and
    `t/15-proofs.t` tests it.
13. **What a sink's step returns goes on,** as any stage's does; the
    draft reference says it's ignored. Ekorn's sinks return nothing,
    so they're unaffected; a `sink {...}` whose step returns values is
    a stage made for a run, with an end that always runs. The design
    should decide which it means.
14. **A sink is told `stopped` only when its run is ended from
    outside.** It holds back every value, so a stop after it can't
    come while the source has values, and one before it leaves it
    after the stop. Section 5.3 of the design should say so.

### Elements, 2026-11-12

Built to D4: Element, with `call`, `&{}` and `goes_as_stage`; Stage,
Gather, Source, Sink, Iterator and Ekorn::Pipeline on it; `new` making
a Stage of each plain code reference, and a run calling its code as it
is; `is_stage` asking an Element whether it goes where a stage goes;
chains keeping what they're made of in their own hash. The
address-keyed hashes, and the closure each class needed, are gone.
Two existing tests changed with it, as v0.3.0 changes: a gather is no
longer a code reference to `is_coderef`, and `stages` returns Stages
of the code given. Everything else passed unchanged.

15. **An object made for a run is taken as a source unless it's an
    Element or a code reference.** Both a package's source and a
    package's sink have `for_run`, so a package's own sink must be one
    or the other to go where a stage goes. Section 4.4 of the design
    should say how a source is told from a stage made for a run.

### The cold review, 2026-11-12

A fresh reviewer read the design, the drafts, IMPLEMENTATION.md, the
code and the proofs, with none of this session's conclusions, and ran
what it doubted. Its verdict: mostly coherent. The run model holds for
Ekorn's own types, with no reference cycles, but it found five
structural problems, each now an open decision above:

- **S1, D5:** a part's role is decided by Ekorn's classes and its
  position, not a protocol. A package's own blessed-code source given
  as a stage was taken for a sink, and crashed; its own sink under `|`
  gave a chain that never runs; its hash-based sink was refused; and
  Ekorn's Sink was accepted as a source. So principle 3 doesn't yet
  hold, and finding 15's answer, "be an Element or a code reference",
  contradicts D1 and brings finding 8's trap back in the package's
  code. Findings 2, 4, 5, 9, 13, 14 and 15 are symptoms of it.
- **S2, D6:** a sink commits before the run has ended. With a stage
  dying after a sink, both the sink and the source were told `done`,
  and then the run died: checked again by hand. Findings 1 and 14 are
  symptoms of it.
- **S3, D7:** `run_source()` gives the shared source object. Two runs
  of one source at once each saw the other's columns.
- **S4, D8:** loading Operators changes `|` for the whole program,
  against principle 1 and 17.11's reason.
- **S5, D9:** nothing reusable gives a sink's result: an Iterator
  given to a second run gives nothing, with no error.

It also found the docs out of step in places, fixed in the commit
that records the review: the design's contents link to section 12;
8.1, 12.8 and 13 still written for blessed code references; 6.1 calling
`pipeline_in` the only method that reads names; section 9 chaining
stages to stages, which made a pipeline, which has no operators, and
the reference's `|=` changing a pipeline in place; the reference's
words section pointing to the old subclass model; 19.1 saying both are
told `died` when a sink can't be set up; and Q6 marked built, though
the warning doesn't say which end. And code-level points, listed in
IMPLEMENTATION.md's section 10.2: errors from a source's end handled
three ways; a `Stop` thrown by a source escaping as an object;
`Stage->new` taking a Gather.

- **What's left:** coverage is below the floors (branch 86%, condition
  73%, POD 55%), from the new modules' error paths and their
  placeholder POD; CI doesn't run on `pipeline-experimental`. Each item
  the design is split into brings its part up to the floors. The
  findings above go into the design.
