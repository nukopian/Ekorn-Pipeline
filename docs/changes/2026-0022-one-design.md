# 2026-0022. One design, end to end, before more is built

**Status:** in progress

**Decisions:** D1 settled: DBIx::Squirrel uses Ekorn as it is. D2
settled: the design ships as v0.3.0, on `pipeline-experimental` until
then. D3 settled: the design is proved by code in the core. D4
settled: Ekorn's types are Elements. D5 settled: one method per role,
`as_source`, `as_stage`, `as_scalar`, `as_list`. D6 settled: a sink's result is
separate from its end, and every end waits for the run to end. D7
settled: a source gives a context for each run, which a stage asks
`run_context()` for. D8 and D9 settled, as D32 and D41. D10 settled:
`to_arrayref` ends a chain, and `to_array` croaks there. D11 to D17
settled, from the second cold review: the source's end first; a flush
and an end for everything made for a run; `is_stage` by the role
methods; a chain starts with a typed source; a run ends when nothing
in it can act; the unanswered cases answered; a scalar sink's result
in scalar context. D18 settled: the operators stay. D19 to D25
settled, from the third cold review: one stage-place method; `done`
for a part whose input ran out; set-ups when the run starts; ends
wait, nothing run early; chains of stages; no context in a pushed
run; a scalar sink always gives one value. D26 settled: the stream
concept applied to functions is what Ekorn is for. D27 settled: an end
dying during a die warns, naming the end. D28 settled: an
abandoned iterator ends its run. D8 and D9 moved into the design as
its Q23 and Q24. D29 settled: DBIx-Squirrel's CI
tests against `pipeline-experimental`. D30 settled: Ekorn::Pipeline
doesn't re-export `pipeline`. D31 settled: DBIx::Squirrel keeps
re-exporting Ekorn's functions, for now. D32 settled: `|` is in force
lexically. D33 settled: a pipeline holds no
source. D34 settled: the caller asks an
iterator how its run ended. D35 settled: named sources, Q11,
dropped. D36 settled: a statement's definition
names pipelines by string, as a chain of names. D37 settled: the name-reading class
method is `pipeline_in`. D38 settled: no strict `is_stage`, for
now; `is_sink` is the design's Q27. D39 settled: the prototype is kept
where it holds. D40 settled: a pipeline's name in its
stages' errors joins v0.3.0. D41 settled: a spent iterator croaks
as a source; a reusable source of a sink's result dropped. D42 settled: each type, called directly,
does what its role means. D43 settled: `is_sink`. D44 settled: DBIx::Squirrel's iterator
offers `as_source`, as the design's 12.3 sets out.

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
  was the design's Q19, settled as D39.
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
- [x] **D6.** When are a sink and a source told how the run ended?
  A sink's set-up returns three closures, Iain decided on 2026-11-12:
  its step; its result, called when its input runs out, whose return
  goes on; and, optionally, its end, called once the run has ended,
  told how. Every end, a source's and a stage's too, waits for the run
  to end, and the source's is still last. What the words mean, defined
  with it: `died`, the run died, anywhere, before it ended; `stopped`,
  the part's input was cut short, by a stop at or after it or by the
  run being ended from outside; `done`, its input ran out, and the run
  didn't die; a sink that stops the run itself is told `done`. Why:
  from the cold review's S2, a sink's one end gave its result and was
  told `done` as its input ran out, so a stage dying after it left it
  committed. Weighed: one end called only when the run has ended,
  which needs a sink to be last; keeping it and calling a part's
  verdict final, which leaves `insert_into` committing before a die.
  What it costs: a complete pipeline pulled as a source keeps its
  source open until its run ends, not only until its first value. It
  changes the design's 19.2: an outer run's stop or die now reaches the
  inner run's ends, as they wait for it. The design's 5.3, 5.4 and
  17.15. Since revised: D11 put the source's end first, and D15 ends a
  run when nothing in it can act, so a complete pipeline pulled as a
  source ends its run at the first pull again, and 19.2 is as it was.
- [x] **D7.** What does a stage ask, to know about its run? A context
  for the run, Iain decided on 2026-11-12: `as_source` may return a
  third value, after its step and its end, anything the source knows
  about this run, such as a statement's columns; a stage asks for it
  with `Ekorn::Pipeline::run_context()`. Each run has its own; an
  iterator used as a source passes on the context of the run inside
  it; a pushed run has none. Why: from the cold review's S3,
  `run_source()` gave the source object, shared by every run, so two
  runs at once saw each other's columns, and behind an iterator a
  stage got the iterator. Weighed: values that carry it; the stage
  given it. It settles Q21. The design's 4.4, 12.7 and 17.16.
- [x] **D8.** Is `|` opt-in for the program, or for the code that
  loads Operators? Settled as D32. From S4: overloading belongs to a class, so loading
  Operators gives `|` everywhere. Moved into the design as its Q23, at
  Iain's request, where it's discussed and recommended.
- [x] **D9.** How is a sink's result had as a source that can run more
  than once? From S5: an Iterator is one run, and gives nothing to a
  second. Moved into the design as its Q24, at Iain's request, and
  settled there as D41.
- [x] **D10.** What does `to_array` give from `|`? Nothing: it
  croaks, Iain decided on 2026-11-12, as its list can't be given where
  one scalar must be. `to_arrayref` gives an array reference of every
  value, of the array it's given, filled, or of a new one, and is what
  ends a chain; `to_hash` and `to_hashref` likewise. Why: `to_array`
  gave an array reference from `|`, its name saying one thing and its
  result another, and `to_arrayref` pushed onto your array and gave how
  many, which its name didn't say either. The design's 8.3, 9 and
  17.12.

D11 to D17 came from the second cold review, settled by Iain on
2026-11-12 as recommended, when he asked that what needed a fix be
fixed; each can be reopened.

- [x] **D11.** Where does the source's end run among the ends? First,
  then the stages', first stage first, so a source failing to close is
  known before any sink commits, and tells the ends after it `died`.
  Why: with every end waiting for the run (D6), Q5's reason for last
  went, and a source's end dying after a sink had committed left the
  run dead and the sink committed. Settles Q5. Design 5.4, 17.17.
- [x] **D12.** How many kinds of end? Two: a flush, called when a
  part's input runs out normally, its values going on, which a gather
  has as v0.2.0's end and a sink as its result; and an end, told how,
  once the run has ended. Everything made for a run is a step, a
  flush and an end, each part using what it needs. Why: under D6, a
  sink's result was a gather's end under another name. Design 5.4,
  17.7, 17.9.
- [x] **D13.** What does `is_stage` take? A code reference, a
  pipeline, or anything offering `as_stage`, `as_scalar` or
  `as_list`; Element's `goes_as_stage` goes. Why: it still asked
  Elements, so a package's own sink was refused, and there were two
  ways of saying what a part can be. Design principle 6, 6.1.
- [x] **D14.** What can start a `|` chain? A typed source: an object
  whose class overloads `|`, Ekorn's sources and chains, or a
  package's class overloading it with Operators' `chain`, which is
  part of the protocol. Why: Perl overloads by class, so a plain code
  reference on the left is ORed, and 17.14 claimed `|` asked only the
  role methods. Design 9, 17.14.
- [x] **D15.** When has a run ended? As soon as nothing in it can still
  act on a value: the source run out or stopped, every flush called,
  every value still to be handed out past the last stage; or when it's
  ended from outside, or dies. So a pulled sink last commits as its
  result is ready, not when its iterator is let go, when a failing
  commit was only a warning; and a complete pipeline pulled as a
  source ends its run at the first pull again. Design 5.4, 17.15,
  17.17, 19.2.
- [x] **D16.** The cases the design didn't answer: a sink that stops
  the run itself has its flush called, and is told `done`;
  `ending()` is true for every flush's values, a sink's result
  included; a stop from a source ends its values, what it carries
  going through as its last, and it's told `done`; from a flush, it's
  a stop at that stage; from an end, an error; and a run with no
  context of its own, such as one pushed inside a stage, sees the
  context of the run it's in. Design 5.4, 5.6, 12.7. Since revised: D24
  gives a pushed run no context, and D16's "a part that stops the run"
  means a sink, as a gather that stops isn't flushed.
- [x] **D17.** What does a pushed run give in scalar context? How many
  values came out, as in v0.2.0, unless its last stage is a scalar
  sink, when it gives that sink's result: `my $n = $p->(@values)` with
  `count` last is the count. Why: `as_scalar` is named for Perl's
  scalar context, and gave 1, the number of results. No v0.2.0 code
  has a sink, so nothing that works changes. Design 4.3.
- [x] **D18.** Do the operators stay? Yes, Iain decided on 2026-11-12:
  a chain tells its story visually; other syntax may be explored
  beside it. The second review had suggested deferring them. Design 9.

D19 to D25 came from the third cold review, settled by Iain on
2026-11-12 as recommended.

- [x] **D19.** An object offering a stage's method and a sink's? It
  offers at most one of `as_stage`, `as_scalar` and `as_list`, checked
  when the pipeline is made, as they'd be called in the same place;
  `as_source` goes with any. Design 4.4, 17.18.
- [x] **D20.** A part whose input ran out before a stop? It's told
  `done`, whatever follows it: the definition in 5.3 wins over its
  table, which the code followed or not by what came downstream.
  Design 5.3.
- [x] **D21.** When do set-ups run? When the run starts, as a gather's
  always have: when the iterator is made, or a pipeline called. D7's
  context through an iterator depends on it. Design 5.2.
- [x] **D22.** What does D15's ending mean for values still waiting?
  The ends wait while they go through the stages, as they're pulled,
  and nothing is run early; `finish` drops what's still to be handed
  out, and a run that ended by itself hands out what's left. Design
  5.4, 5.5.
- [x] **D23.** Do stages chain with `|`? Yes: `$trim | $lowercase` is a
  pipeline of a subclass that has `|`, going wherever a pipeline does;
  a chain starts with a typed source or stage, and a package's source
  class gets `|` from `chain` and `@{}` from `drain`. Why: section 9's
  own example chained stages, which D14 forbade, and a chain of stages
  tells the story the operators are kept for. Design 9.
- [x] **D24.** Does a pushed run see the context of the run it's in?
  No, reversing that part of D16: only an iterator used as a source
  passes its context on. Why: `pluck` in a pushed run fed other values
  would read the statement's columns and give wrong fields, silently.
  Design 12.7.
- [x] **D25.** What does a scalar sink give with no values? One value,
  `undef`, as its flush always gives one. So a result of one value is
  a source of one value, and scalar context (D17) gives `undef`, not
  nought. Design 4.4, 5.4.

- [x] **D26.** Do sources, sinks and operators belong in Ekorn (the
  design's Q1)? Yes, Iain decided on 2026-11-12: "a more complete and
  coherent design is emerging", the stream concept applied to
  functions, which has "an elegant symmetry", and he wants to run with
  it. Any function that hands out values is a source; stages carry the
  values, a sink consumes them, and the pipeline is where they meet,
  either way round: a function taking its caller's stages, or a caller
  pulling a function's values through a pipeline of their own. It
  stays opt-in. The design's section 2, and the roadmap's 2026-0016 and
  0017, no longer a change of scope to weigh.
- [x] **D27.** An end that dies while the run is already dying (the
  design's Q6)? A warning, naming the end, and the first error kept,
  Iain decided on 2026-11-12, as recommended. Why: a second error must
  not hide the first, which is the one that ended the run, and the
  warning is no use if it doesn't say which end failed. Design 5.4.
- [x] **D28.** Does `iterator` return an Iterator whose `DESTROY`
  ends an abandoned run (the design's Q7)? Yes, Iain decided on
  2026-11-12, as recommended: an iterator read only in part, and let
  go, closes what its run opened, with no call to remember. Ekorn's side
  was built with D4 and D15; DBIx-Squirrel, which keeps its iterator
  in a field, is told when it reviews the design. Design 5.5, 17.10.
- [x] **D29.** Does DBIx-Squirrel's CI test against Ekorn's
  `pipeline-experimental` (the design's Q16)? Yes, Iain decided on
  2026-11-12: `pipeline-experimental` is a sandbox, so a CI run against
  it costs nothing that matters, and finds where the two drift. It's
  DBIx-Squirrel's to set up, told when it reviews the design.
- [x] **D30.** Does Ekorn::Pipeline still re-export `pipeline` (the
  design's Q17, 2026-0021's D7)? No, Iain decided on 2026-11-12, as
  recommended: `pipeline` is a word, and words live in Factories only
  (principle 4), so there's one place to import it from.
- [x] **D31.** Does DBIx::Squirrel keep exporting Ekorn's functions as
  they are (the design's Q20)? Yes, for now, Iain decided on
  2026-11-12, as recommended: as plain re-exports, so its users' code
  keeps working. It's DBIx-Squirrel's to revisit.
- [x] **D32.** Is `|` opt-in for the whole program, or only for the code
  that loads Operators (the design's Q23, D8)? Lexically, Iain decided
  on 2026-11-12, if it could be done, and it can: `use
  Ekorn::Pipeline::Operators` marks its scope in `%^H`, and `chain` and
  `drain` croak where the hints of the line using them don't have it.
  So `|` written outside a scope that asked for it croaks rather than
  quietly ORing two addresses. Design 9, 17.11.
- [x] **D33.** Can a pipeline start with a source, as well as end with
  a sink? No, Iain decided on 2026-11-12: a source is a free-standing
  concept, and a pipeline holding one would be coupled to it. A
  pipeline is a list of stages, a sink among them, and a source is
  given as it runs; a source joined to a pipeline is a source, and the
  whole, kept, is Q24's. Design 4.2, 17.19.
- [x] **D34.** Can the caller ask how a run ended (the design's Q25)?
  Yes, Iain decided on 2026-11-12, as recommended, to be built at once:
  `$next->ended` gives nothing while the run goes, then `done` if the
  source's values ran out, `stopped` if the reading was cut short, or
  `died` if anything in it died, an end included. Why: the caller saw a
  die as an error, but couldn't tell a complete result from one
  `take(5)` cut short. Iterators only: a pushed run leaves no object to
  ask. Design 5.5, 17.20; built, with `t/15-proofs.t` testing each
  verdict.
- [x] **D35.** Named sources (the design's Q11, roadmap idea
  2026-0012): now, or later? Neither: dropped, Iain decided on
  2026-11-12. If there's a need, it'll be found again. The idea leaves
  the roadmap with it. Design 7.
- [x] **D36.** Can a statement's definition in DBIx::Squirrel's Sugar
  name a pipeline by a string (the design's Q15)? Yes, Iain decided on
  2026-11-12, written as a chain of names, `clean => trim => top5 =>`:
  "name1 => name2 => name3 => ... has a beautiful ring to it", reading
  as the values' path. `=>` always quotes the bareword on its left, so
  every name is followed by one, the last included, and none needs
  quotes; Perl allows the trailing `=>`, which adds nothing. How
  a name is told from the rest of a definition is DBIx-Squirrel's to
  design, taking this in when it reviews. Design 12.5.
- [x] **D37.** The name-reading class method, `pipeline_in` or `new_in`
  (the design's Q10, 2026-0021's D6)? `pipeline_in`, Iain decided on
  2026-11-12, as recommended, once it was checked still to be needed:
  Factories' `pipeline` and Ekorn's Sugar each look names up in a
  package they're given, and a public method serves both, where a
  private one would be reached into from another module. `new_in`
  would read as `new` with an option. Design 6.1.
- [x] **D38.** A strict `is_stage` (the design's Q18, roadmap
  2026-0019)? Not now, Iain decided on 2026-11-12, as recommended:
  pipeline-last answers the need, and plain code references stay
  stages. He asked whether an `is_sink` beside it, telling a scalar
  sink from a list sink, had real value: it does, for a function
  taking its caller's stages, so it's the design's Q27.
- [x] **D39.** The code that proves the design: kept, or written again
  item by item (the design's Q19)? Kept where it holds, Iain decided on
  2026-11-12, as recommended: each item the design is split into takes
  in its part of the prototype and finishes it, with its tests, its
  documentation, and coverage back to the floors. Design 19.
- [x] **D40.** Does a pipeline's name in its stages' errors (roadmap
  2026-0013) join v0.3.0 (the design's Q22)? Yes, Iain decided on
  2026-11-12, as recommended: it changes a message, and v0.3.0 is the
  release that may, the next a long way off. DBIx-Squirrel changes its
  tests and its copies of the message with the task that moves its
  range. Design 13, 18.
- [x] **D41.** Is Q24 still relevant: a complete pipeline kept as a
  reusable source of its result, and an iterator given to a second
  run? Narrowed, Iain decided on 2026-11-12, as recommended: the
  reusable source is dropped, as a few lines of `source {...}` make
  one, and it'll be found again if needed; and a spent iterator, one
  that has handed out all it will, or was finished, croaks when given
  as a source, rather than give nothing. Being spent counts, not the
  run's having ended, so a list sink's result still flows (D22).
  Built, with `t/15-proofs.t` testing each case. Design 4.2, 17.21.
- [x] **D42.** What does each type do when called directly (the
  design's Q26)? What its role means, Iain decided on 2026-11-12, as
  recommended: a Sink called with values pushes them through itself
  and gives its result, as a pipeline of the one sink would, and "this
  makes it testable": `is count->(1, 2, 3), 3`, with no source or
  pipeline to set up. A Source called directly croaks, as a run of its
  own would never be ended. Stage, Pipeline, Iterator and Gather are as
  they were. Built. Design principle 6, 17.22.
- [x] **D43.** Should Ekorn export `is_sink` (the design's Q27)? Yes, on
  request, beside `is_stage`, Iain decided on 2026-11-12, as
  recommended: `'scalar'` or `'list'`, both true, or false; a pipeline
  by the sink it ends in. So a function taking its caller's stages can
  honour a sink at their end. Built, and used by `|` and by scalar
  context in place of their own checks. Design 11.1, 17.22.
- [x] **D44.** How does DBIx::Squirrel::Iterator offer `as_source` (the
  design's Q14, DBIx-Squirrel's question)? As the design's 12.3 sets
  out, Iain decided on 2026-11-12: its set-up executes the statement,
  its step fetches in batches, its end finishes the handle, and its
  context is the statement's columns; its own stages are run by an
  Ekorn iterator whose source it hands on; and one run of a handle at
  a time. "If DBIx-Squirrel has an issue, we will re-visit the design."

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

### The second cold review, 2026-11-12

A second fresh reviewer read everything again after D5 to D7 and D10,
told that the code lags the design on purpose and that
IMPLEMENTATION.md's section 10 is meant to account for the gap. Its
verdict: the design mostly coherent, the settled model hanging
together better than the prototype; the implementation and its
document mostly accurate, every runnable example printing what it
says. Its structural points became D11 to D17, and the operators, which
it would have deferred, D18. It found stale text from the day's
decisions, now fixed: the reference's set-up of two closures; the
design's 4.4, 6.1 and 6.2 on what the role methods and words return;
5.5 and the reference saying an iterator let go tells every part
`stopped`; IMPLEMENTATION.md saying the existing tests are unchanged,
and section 10 marking as built what D6 changed. And four drifts
section 10.2 missed, now listed: a run ended from outside tells parts
`stopped` whose input had run out; `finish` takes any verdict, so
`finish('done')` commits a partial run; `finish` from inside a stage
calls the sink's step again; and an error from a source's end shows an
empty stage name. Section 10 is rewritten whole.

### The third cold review, 2026-11-12

A third fresh reviewer found the design mostly coherent and improved on
both earlier reviews, and the implementation and its document accurate,
all 33 runnable examples printing what they say. Its structural points
became D19 to D25. It also found: D16's "a part that stops the run"
broader than meant; the reference and how-to lagging the day's
decisions, their sections for package authors never naming the role
methods, `run_context()` or `chain`, now rewritten around them; wording
from before D12 in the design's 5.2 and 17.6; D6 not marked where D11
and D15 revised it; the operators' traps of precedence and of sinks
without an empty prototype; and three drifts section 10.2 missed, now
listed. The open questions are tidied: Q3, Q4, Q8, Q9, Q12 and Q13
settled by decisions since, beside Q2, Q5 and Q21, and Q14 and Q18
restated.

### Reconciled, 2026-11-12

The prototype was brought up to every settled decision, so that the
code, the design and IMPLEMENTATION.md agree: the role methods (D5,
D13, D19); a flush and an end for every part (D6, D12); the source's
end first (D11); a run ending when nothing in it can act (D15, D22);
the verdicts (D16, D20); a context for each run (D7, D24); scalar
context (D17); `to_arrayref`, and a list sink croaking at the end of a
chain (D10); a scalar sink always giving one value (D25); a warning
naming the end that died (D27); chains of stages and `drain` (D14,
D23); and `|` in force lexically (D32). `t/15-proofs.t` is rewritten
to the settled design, and three earlier test files change only where
v0.3.0 changes what they checked. IMPLEMENTATION.md is rewritten whole,
every example run. The design gains section 20, the knock-on effects
on every other document, for the plan it's split into.

Building it found one thing: `|` binds more loosely than `+`, so
`$src | count + 10` is `$src | (count + 10)` whatever `count`'s
prototype; the design had said an empty prototype made it read as
`($src | count) + 10`. Section 9 now says to parenthesise, and the
empty prototype only makes `count + 10` read as a call and a sum.

Left as they are, as the design says they're built when it's split
into items: names per class, `pipeline` in Ekorn::Pipeline, and Pipes'
`pipeline_class`; and v0.2.0's wording of two messages, listed in
section 20 to revise. Q24 is still open, so an iterator given to a
second run still gives nothing. (Since settled as D41: a spent iterator croaks.)

Writing IMPLEMENTATION.md's section 5.3, on how the code keeps track
of who's done, found a gap in D20: at a stop, nothing was marked, so a
stage after a sink, stopping on the last value the sink gave, was told
`stopped`, though its input had run out. Now, at a stop with nothing
more to come from upstream, each stage up to it is marked `done` until
one still has a value waiting, or a flush before it still to come;
`t/15-proofs.t` tests both sides.

### The fourth cold review, 2026-11-12

A fourth fresh reviewer, after D19 to D44, found the design and the
implementation mostly coherent, and better than at the third review:
the structural problems it had raised gone, its own findings edge
paths and leftover wording; all 31 runnable examples printing what they
say. It found five bugs, where the code broke a settled decision, now
fixed and tested: a stop from an end, or a set-up, escaped as a raw
stop, which could quietly stop a run around it (D16); iterators, being
sources, had no `|` or `@{}`, so `|` silently ORed (D32); an iterator
that died wasn't spent (D41); a pipeline made with `new` chained when
the right side was typed (section 9); and a sink's code reference died
with the sink, as the sink held itself weakly (D42). Stale wording is
fixed: "proposed" labels in a settled design, `$sth->source` after
D44, 5.3's table against D11, 12.5's lookup, which needs `pipeline_in`
with the user's package, "without loading Ekorn" against the
examples, the drafts' status notes, section 20's roadmap bullet, and
section 13's missing rows. Two behaviours are stated in the design: a
gather's pipeline as its step is Ekorn's own, not a protocol; and
`finish` from inside a stage runs every end while that stage is still
running. Three questions are opened, Q28 to Q30: what `ended` tells
the caller, what a context describes, and how a list sink is declared.

- **What's left:** coverage is below the floors (branch 86%, condition
  73%, POD 55%), from the new modules' error paths and their
  placeholder POD; CI doesn't run on `pipeline-experimental`. Each item
  the design is split into brings its part up to the floors. The
  findings above go into the design.
