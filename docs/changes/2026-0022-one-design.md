# 2026-0022. One design, end to end, before more is built

**Status:** approved, on 2026-11-13, and split into items; what it
made ships in v0.3.0 through them

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
offers `as_source`, as the design's 12.3 sets out. D45 to D47 settled, from the fourth
cold review: `ended` the last part's verdict; a context describes the
source; lists first, `sink` and `sink_scalar`. D48 settled: `ended`
says whether the source was read to its end, revising D45. D49 settled: the role methods are named
for Ekorn. D50 settled: sinks named for what they
give, and containers. D51 settled: a list sink asked for one value
gives its list as an array reference, revising D10 and D47. D52
settled: `@{}` stays, explained in detail, and the docs lead with a
sink. D53 settled: `count` renamed `count_items`, and `only_item`
`single_item`, revising D50's names. D54 settled: no containers for
arrays and hashes; `to_fh` and `to_file` stay. D55 settled:
`all_items`, `first_item` and `single_item` renamed `keep_all`,
`keep_first` and `keep_single`. D56 settled: `last_item` is
`keep_last`, and built. D57 settled: `keep(N)`, a list sink of the
first N items, stopping there. D58 settled: a `take` stage for every
`keep` sink but `keep_all`. D59 settled: an iterator's `all`, `first`
and `single`. D60 settled: `single`'s check doesn't consume, revising
D59. D61 settled: `single` finishes, as `first` does, revising D60.
D62 settled: a step's many values are cheap, and `all` takes them in
bulk. D63 settled: the `&{}` overload stays; `\&$next` is documented.
D64 settled: a sink's kinds are one and many, in every name.
D65 settled: `is_sink` keeps `one` and `many`, not 1 and 2.
D66 settled: six sinks set aside for now.
D67 settled: four sources dropped.
D68 settled: `from_arrayref`, `from_hash` and `from_hashref` dropped;
`from_array` built.
D69 settled: `from_file` and `to_file` take I/O layers; an empty file
slurped gives no record.
D70 settled: `generator {...}` and `yield`, from idea 2026-0023.

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
  Amended by Iain in DBIx-Squirrel's session, 2026-11-12, from its
  review: the columns are named as `fetchrow_hashref` keys them,
  `$sth->{FetchHashKeyName}`, read before the first fetch; and an
  active handle is finished and executed again, as DBIx::Squirrel's
  iterator does today, croaking only when another of its iterators is
  part-way through it.
- [x] **D45.** What does `ended` tell the caller (the design's Q28)?
  The verdict of the run's last part, Iain decided on 2026-11-12, as
  recommended: whether the result is complete. A complete
  `first_value` is `done`, though it stopped the source; `take(5)`
  last is `stopped`; `finish` dropping values still to be handed out
  is `stopped`; with no stages, the source's verdict. Why: D34 gave the
  source's verdict, which called a complete `first_value` `stopped`,
  like a truncation. Built. Design 5.5, 17.23. Revised by D48, as the
  fifth cold review showed the last part's verdict isn't completeness.
- [x] **D46.** What does a run's context describe (the design's Q29)?
  The run's source, not the values, Iain decided on 2026-11-12, as
  recommended: a stage that reshapes rows doesn't change it. A way to
  replace or drop it waits until a need is found. Design 4.4, 12.7.
- [x] **D47.** How is a list sink declared (the design's Q30)? Lists
  first, Iain decided on 2026-11-12, against the recommendation of a
  scalar default with `list_sink {...}`: "scalars are the
  second-class citizen". `Ekorn::Pipeline::Sink->new` and `sink {...}`
  make a list sink, offering `as_list`; `Sink->new_scalar` and
  `sink_scalar {...}` a scalar one, offering `as_scalar`. A `|` chain
  still ends only in a scalar sink (D10), so a sink written to end one
  is a `sink_scalar`. Built; `count`, `first_value`, `to_arrayref` and
  `to_file` are made with `new_scalar`, and the examples' sinks of one
  value with `sink_scalar`. Design 6.1, 6.2, 17.23.
- [x] **D48.** What does `ended` say, revising D45? Whether the source
  was read to its end, Iain decided on 2026-11-12, as recommended, and
  only once the iterator has given all it will, been finished or died,
  so it's said once and doesn't change. `done` if it was; `stopped` if
  a stop anywhere, or `finish`, cut the reading short, or `finish`
  dropped values still to be handed out; `died` if anything died. Why:
  the fifth cold review showed D45's last-part verdict isn't "whether
  the result is complete": `take(2)` before a stage was `done` and
  after one `stopped`, for the same values, and `take(2)` then `count`
  was `done`, though cut short. "Complete" has two meanings; only
  "were there more values than I got?" is well defined. Built. Design
  5.5, 17.23.
- [x] **D49.** How is a part told from any object offering a method of
  the same name (the design's Q31, from DBIx-Squirrel's review)? By
  role methods named for Ekorn, Iain decided on 2026-11-12, choosing
  the first of three options: `ekorn_source`, `ekorn_stage`,
  `ekorn_sink` for a list sink, and `ekorn_sink_scalar`, mirroring the
  words, in place of D5's `as_source`, `as_stage`, `as_list` and
  `as_scalar`. Why: DBIx::Squirrel separates a statement's stages from
  its bind values with `is_stage`, and a bind value whose class had an
  `as_list` method was taken for a sink, and died. Weighed: the `as_`
  names with a marker method; Perl's `DOES`. Built, with a test.
  Design 4.4, 17.24.
- [x] **D50.** How are sinks named (from DBIx-Squirrel's design, where
  its iterator's `all`, `single` and `count` give way to Ekorn's
  sinks)? In two families, Iain decided on 2026-11-12: sinks named for
  what they give, "item" replacing "value", `all_items`, `first_item`,
  `only_item`, `last_item`, `any_item`, `every_item`, with `count`
  keeping its name, "that's what it is, not what we're putting the
  result in"; and container sinks, named for where the items go, the
  `to_` sinks, which stay. `all_items` and `to_array` give the same,
  each in its family. `only_item` warns at a second item, giving the
  first, rather than croak, "for those situations where you want one
  value but forgot to limit it to one value". Built: `first_value`
  renamed, `all_items` and `only_item` added, with tests; `all_items`
  is also the name of a Test2::V0 check, so a test using both calls one
  by its full name. Design 8.3, 17.25. `every_item` in place of
  `all_items` was considered, and Iain kept `all_items` the same day:
  `every_item(sub {...})` is the test paired with `any_item`, as
  List::Util has `any` and `all`, and JavaScript `some` and `every`;
  "all" is the items together, "every" each in turn; and the clash
  with Test2::V0 is "only a problem in test harness", not a reason to
  name a public sink.
- [x] **D51.** What does a list sink give when one value is asked for
  (the design's Q32, DBIx-Squirrel's Q22)? Its list, as an array
  reference, Iain decided on 2026-11-12, his proposal, sent by
  DBIx-Squirrel's session: "all_items as a scalar (when I have a count
  sink) could be a reference?" A sink given last says what comes back,
  whatever the context, and counting is `count`'s job. So in scalar
  context `my $rows = $p->(@values)` with `all_items` last is every
  item, where under D47 it was how many; and a `|` chain, asked for one
  value too, ends in a list sink the same way, where under D10 it
  croaked. `to_array` included: an exception for one list sink would
  be a surprise of its own, and `to_arrayref` keeps its job, filling
  the array you hand it. A pipeline with no sink still gives how many
  (D17). Costs, documented: an empty result is true, so testing for
  none takes `@$rows` or `count`; printing one shows `ARRAY(0x...)`.
  How `to_hash` would give a hash reference waits until it's built.
  Iain: "quite nice, too". Built: `Ekorn::Pipeline`'s call and
  `Operators`' `chain`, the croak at a chain's end gone, with tests.
  Design 4.3, 6.2, 8.3, 9, 13, 16, 17.12, 17.23, 17.25, 17.26, 20.
- [x] **D52.** Does `@{}` stay, though it reads as a dereference (the
  design's Q33)? Yes, Iain decided on 2026-11-12, from DBIx-Squirrel's
  design, where he read `@{ $sth->iterate | pluck('name') | take(5) }`
  and asked why `take` returned an array reference: "Looks weird but
  you should explain it in detail, and use more examples of
  alternatives." So the docs explain what Perl's overloading of `@{}`
  is, that Operators' `drain` reads a source through, a run of its own
  each use, even for `$source->[0]` or `scalar @$source`, that
  `for (@$source)` reads every value first, that an iterator is
  drained once, and that only a source has it. And they lead with a
  chain ending in a sink, showing the alternatives by what's wanted:
  `all_items`, `@{ ... | all_items }`, `first_item`, `count`, `take`,
  `to_arrayref(\@mine)`, and an iterator for each value as it comes.
  A `drain` sink, for `| drain`, as Iain asked after, isn't needed:
  `all_items` is it. Found writing it: a chain run for its sink's
  effect, as a statement of its own, makes Perl warn of a useless `|`
  in void context, at compile time, which Ekorn can't stop, so the
  docs say to keep the result. Checked by hand: the reads each use
  makes, an iterator croaking the second time, a stage's and a
  count's errors, and the how-to's examples, run after its data.
  No code changes. Design 9, 16, 17.27.
- [x] **D53.** Are `count` and `only_item` named well? No: they're
  `count_items` and `single_item`, Iain decided on 2026-11-12, revising
  D50's names, nothing else about either changing. `count_items`
  completes the family named for what they give, as D50 kept `count`
  for being "what it is, not what we're putting the result in", which
  `count_items` still is, where `to_count` wasn't; a bare `count` is a
  word a caller's own sub, or another module's, may already have; and
  beside `count_into(\$n)`, the tap, the second word says which is
  which. `single_item` echoes DBIx::Squirrel's `single`, the iterator
  method it replaces. Neither has been released, so no user's code
  changes. Built: renamed in Sinks, with its tests. Design 8.3 and the
  new 17.28; the names throughout.
- [x] **D54.** Do the containers for arrays and hashes stay? No:
  `to_array`, `to_arrayref`, `to_hash` and `to_hashref` are dropped,
  Iain decided on 2026-11-12, revising D50's family of containers to
  `to_fh` and `to_file`. Since D51, `all_items` gives every item as an
  array reference wherever one value is asked for, so `to_array` was
  `all_items` under another name, and `to_arrayref` the same at the end
  of a chain. Filling your own array is `push @mine, @{ $src |
  all_items }`, and a hash is assigned from the keys and values a stage
  gives, so `to_hashref(\%mine)` and `to_hash` add nothing Perl lacks.
  How `to_hash` would give a hash reference (D51) goes with it.
  Neither container had been released. Built: `to_array` and
  `to_arrayref` removed from Sinks, the tests using `all_items` in
  their place, with Test2::V0's check of that name left out. Design
  8.3, 17.12, 17.25, 17.26, 19 and the new 17.29.
- [x] **D55.** Are `all_items`, `first_item` and `single_item` named
  well? They're `keep_all`, `keep_first` and `keep_single`, Iain
  decided on 2026-11-12, nothing else about them changing. Each name
  says what the sink keeps of what reaches it, which is what it gives.
  `keep_all` no longer clashes with Test2::V0's `all_items` check, so
  the tests import Test2::V0 plainly again, and the advice to leave
  the check out goes. `count_items` keeps its name; `last_item`, not
  built, is still to be named. Unreleased. Built: renamed in Sinks,
  with its tests. Design 8.3 and the new 17.30; the names throughout.
- [x] **D56.** What's `last_item` called, and is it built now? It's
  `keep_last`, matching `keep_first`, and built now, Iain decided on
  2026-11-12. It gives the last item, `undef` if there was none, and,
  unlike `keep_first`, reads every item to find it, so it never stops
  the pull early. Built: in Sinks, with tests. Design 8.3 and 17.30.
- [x] **D57.** A `keep(N)` sink, as Iain asked in DBIx-Squirrel's
  session, sent here as a task: "So we have `take` for stages,
  `keep...` for sinks." Settled by Iain on 2026-11-12, on the questions
  that session raised: it's a list sink, giving an array reference
  where one value is asked for (D51); it stops the run once it has N,
  so a statement fetches no more rows than it keeps, giving what
  `take(N) | keep_all` does; N is checked as `take` checks it, and
  `keep(0)` keeps nothing, stopping at the first item; and it keeps
  the first N only, a negative N croaking, the last N left until a
  use appears. Built: in Sinks, with tests. Design 8.3 and 17.31.
- [x] **D58.** Does every `keep` sink have a `take` stage? Yes, Iain
  decided on 2026-11-12: "For every `keep...` sink, we should have a
  `take...` stage analogue", because "forgetting a keep sink isn't a
  problem if we end a pipeline with a take stage. We just get a count
  in scalar context and the items in list context." `take_first`,
  `take_last` and `take_single` join `take($n)`, `keep($n)`'s, in
  Stages::Flow, exported on request, each passing on what its sink
  gives, as he chose: `take_first` is `take(1)`; `take_last` passes on
  the last at the run's end, or the last to reach it if a stage before
  it stops the run; `take_single` warns at a second, as `keep_single`
  does, and stops. No `take_all`, Iain agreed: it would be no stage.
  Not by default, as Flow is released and a new default export could
  replace a user's function. Built: in Flow, with its POD, tests, the
  published reference and README. Design 8.1 and 17.32.
- [x] **D59.** Can the caller pull what's left of an iterator in one
  call? Yes, Iain decided on 2026-11-12, asking for `all`, `first` and
  `single` back: "I feel we lost the ability to pull the remaining
  items, which I think is important." Ekorn's own Iterator has them,
  not only DBIx::Squirrel's, as he chose. `all` gives the values still
  to come, read to the end, and an array reference where one value is
  asked for, as `keep_all` does; `first` gives the next value, or
  `undef`, and finishes the iterator, as `keep_first` stops its run;
  `single` gives the next value, or `undef`, pulling one more to check,
  and warns "Expected only one item, but there were more" if there is
  one, rather than croak, as Iain chose, and finishes it. Built: in
  Iterator, with tests. Design 6.2 and 17.33.
- [x] **D60.** Does `single`'s check consume the value it finds?
  No, Iain decided on 2026-11-12, revising D59: "I'd rather that
  single's check was non-destructive, i.e. was able to check if there
  was another value without consuming it." So the iterator holds a
  value looked at ahead, and hands it out first, to its next pull,
  `all`, `first`, or a run reading the iterator; `single` no longer
  finishes the iterator, which would drop it. While a value is held,
  `ended` says nothing, as the iterator still has one to give, and an
  iterator holding one isn't spent; `finish` drops it, so `ended` then
  says `stopped`. Built: in Iterator, with tests. Design 6.2 and 17.33.
- [x] **D61.** Does an iterator's `single` finish it, as `first` does?
  Yes, Iain decided on 2026-11-12, revising D60, from DBIx-Squirrel's
  message: its iterator's `single` calls Ekorn's, then `finish`,
  because a statement left active after `single` holds a lock on
  SQLite (its 2026-0013 D25). So `single` pulls one value more to
  check, warns if there is one, and finishes, as D59 had it. A finished
  iterator drops what it holds, so the look-ahead D60 built protected
  nothing, and went: the Iterator is as D59 built it. Built: Iterator
  and its tests restored, with a test of a source's step giving several
  values to `all`, which DBIx::Squirrel's fast path relies on. Design
  6.2 and 17.33.
- [x] **D62.** Can a step's many values, and an iterator's `all`, cost
  less than a value each? Yes, Iain decided on 2026-11-12, from
  DBIx-Squirrel's task: its `$it->all`, its source giving every row
  left in one step, took 0.403 s on Ekorn over 297,848 rows, against
  0.108 s on its own pipeline. Internal only, with no protocol or
  behaviour changed: a step's values wait unwrapped, in a buffer of
  their own, not each wrapped on the queue; `all` takes what's ready
  in bulk, values already at the end, such as a list sink's result,
  and, with no stages, a step's values, by a closure the run gives the
  iterator; and, from a profile of a pull, a sink's step is called
  without a wrapper, and the check for the run's end is skipped while
  the source is still read. Over 300,000 rows in one step: `->all`
  with no stages 0.161 s to 0.042 s; pulled one at a time 0.376 s to
  0.118 s; `keep_all` then `->all` 0.571 s to 0.304 s. What's left per
  value is a `try` and two `local`s for each value through a stage,
  which keep a stop or a die reported at its stage, and the `&{}`
  overload on each call of an Element, such as `$it->()`; each could
  be an item of its own. Tested: `all` around a list sink's result, a
  stage after it, and a stop part way through a step; and
  `xt/scaling.t`, where one step of every value takes 0.12 of the time
  of a step each, against 0.69 before.
- [x] **D63.** Is the `&{}` overload on each pull worth removing? No,
  Iain decided on 2026-11-12, from DBIx-Squirrel's task (its 2026-0013
  D30). Over 300,000 pulls, best of five: `$it->()` 0.111 s, and the
  same through the code reference taken once, `my $f = \&$it`, 0.077
  s; the overload alone, on a bare object, 0.042 s against 0.009 s. So
  it costs about 0.03 s per 300,000 pulls, and Perl already lets a
  caller skip it, so the idiom is documented instead, with its catch:
  the code reference doesn't keep the iterator, whose run ends when
  it's let go. Making the Iterator a blessed code reference, with no
  overload, was set aside: a change to D4's Elements, for that much. A
  pipeline reading an iterator, then `keep_all`, 0.404 s, isn't the
  overload: the run takes the iterator's code reference itself, and
  the cost is the `try` and `local`s for each value through a stage,
  which stay. Tested: `\&$it` is a plain code reference, pulls the
  same run, and gives nothing once the iterator is let go. The draft
  reference and IMPLEMENTATION.md describe it.
- [x] **D64.** What are a sink's two kinds called? One and many,
  Iain decided on 2026-11-13, renaming in the code the role methods
  `ekorn_sink_scalar` and `ekorn_sink` as `ekorn_sink_one` and
  `ekorn_sink_many`, and then, asked, the rest to match: the
  constructors `Sink->new_sink_one` and `Sink->new_sink_many`, from
  `new_scalar` and `new`, which goes; the words `sink_one {...}` and
  `sink_many {...}`, from `sink_scalar` and `sink`, which goes; the
  classes `Sink::One` and `Sink::Many`, from `Sink::Scalar` and
  `Sink::List`; and `is_sink`'s answers, `one` or `many`, from `scalar`
  or `list`. Each name says which kind, so neither is the default,
  revising D47's lists first. The role methods are a protocol, so
  DBIx::Squirrel's sinks offer the new names; nothing is released.
  Built: Iain's rename in Pipeline and Sink, with the rest in Sink,
  Factories, Sinks, Operators and Errors' internal list, and the
  tests. Design 4.4, 6.2, 17.23, 17.24 and 17.34, with the names
  throughout. Then, at Iain's asking, the drafts' prose: a scalar sink
  is a sink of one, a list sink a sink of many, and the tables' roles
  `one` and `many`; 17.23 and 17.24 keep D47's and D49's words.
- [x] **D65.** Should `is_sink` give 1 and 2, in place of `one` and
  `many`, as Iain wondered on 2026-11-13, both being true? No, he
  agreed the same day: either is true, so a test of whether something
  is a sink reads the same, but `is_sink($x) eq 'many'` says what it
  means where it's written, where `== 2` needs the reader to know what
  2 stands for, or constants to say it; and 1 would only seem to count
  a sink of one's values, as 2 counts nothing. Its false answer is
  already `!!0`, `''` as a string and 0 as a number. No code changes.
- [x] **D66.** Which of the designed sinks stay? Iain set aside
  `any_item`, `every_item`, `fold`, `joined`, `group_by` and `for_each`
  "for now" on 2026-11-13. None was built; each can come back as an
  item of its own. The design keeps the `keep` family, `count_items`
  and the containers `to_fh` and `to_file`. Design 8.3, 17.12, 17.25
  and 17.35; the draft reference and how-to, whose example now uses
  `keep_first` and `keep_last`; IMPLEMENTATION.md; and the roadmap's
  2026-0017.
- [x] **D67.** Which of the designed sources stay? Iain dropped
  `unfold`, `cycle`, `concat` and `interleave` on 2026-11-13. None was
  built; each can come back as an item of its own. The design keeps
  the `from_` sources and `counter`. Design 8.2 and 17.36; the draft
  reference; IMPLEMENTATION.md; and the roadmap's 2026-0016.
- [x] **D68.** Do `from_arrayref`, `from_hash` and `from_hashref`
  stay? No, Iain decided on 2026-11-13: `from_array(@values)` gives
  the values given, so `from_array(@$array)` does what `from_arrayref`
  did, but for an array changed while it's read, and a hash's pairs are
  `from_array(map { [$_, $hash{$_}] } keys %hash)`. DBIx::Squirrel, or
  any package, may make its own, keeping the source protocol, as Iain
  said. `from_arrayref` was built, and the tests used it; `from_array`
  is built in its place, each `from_arrayref([...])` and
  `from_arrayref(\@x)` in the tests and drafts now `from_array(...)`
  and `from_array(@x)`, with a test of its own. `from_hash` and
  `from_hashref` weren't built. Design 8.2, 17.12 and 17.37; the draft
  reference, how-to and IMPLEMENTATION.md; and the roadmap's 2026-0016.
- [x] **D69.** How do `from_file` and `to_file` treat binary and
  encoded files, and what does an empty file give, slurped? Iain, on
  2026-11-13, concerned "that we don't consider files may be binary",
  chose an optional second argument, the I/O layers to open with:
  `':raw'` for bytes, unchanged on any platform, `':encoding(UTF-8)'`
  for text; without it, Perl's default, which on Windows translates
  line endings. And he wanted the slurp "sensible": with `$/`
  undefined, an empty file gives no record, where Perl's `readline`
  gives one empty string. Set aside: always `:raw`, and always UTF-8.
  Built: both, with tests: a binary file of 260 bytes copied exactly,
  in records of 7, through `':raw'`; text with é and ☃ written and read
  as UTF-8; an empty file slurped, none. Design 8.2, 8.3 and 17.38;
  the draft reference and IMPLEMENTATION.md, whose table of sinks also
  now says `one` and `many`, which D64's prose change missed.
- [x] **D70.** A Python-style generator as a source? Yes, Iain decided
  on 2026-11-13, from his wish, added as idea 2026-0023 and taken into
  this item: "the yield(...) idea sounds lightweight and useful". A
  word, `generator {...}`, in Factories, with `yield` beside it, both
  on request: each run calls the block once, collecting what it passes
  to `yield`, and gives it all as one step, so it suits finite
  producers, as Perl can't pause a sub at `yield` short of Coro. What's
  collected is in a package variable, `local` to each run, as Iain
  chose over Syntax::Keyword::Dynamically: "leave Dynamically". Built,
  with tests: values from nested loops, in order; a stage taking only
  some; the block once a run; several values at once, `undef` among
  them, and none; a generator read inside another's block; and `yield`
  outside one croaking at the caller's line. Found writing them: an
  empty block, `generator {}`, reads as a hash, and `@{ generator
  {...} | ... }` as a hash slice; the docs say so. Design 6 and 17.39;
  the draft reference and IMPLEMENTATION.md.

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

### The fifth cold review, 2026-11-12

A fifth review, focused on what changed since the fourth, found the
code changes sound, and all 36 examples printing what they say, but:
D45's meaning not what the code computes, now D48; `ended` able to
change after it was first given, now held back; a sink of one value
written with `sink {...}` giving 1 in scalar context, D47's trap, now
warned of in the design's 4.3 and 6.2, the reference and the how-to;
an end dying with values still waiting leaving an iterator that said
`died` but still handed them out, now fixed; the design not yet saying
that a stop in a set-up is an error, that iterators have `|` and `@{}`,
or that a died iterator is spent, now said; `sink_scalar` missing from
the lists of words; a stop from an end reading "Stop used outside a
pipeline", now "Expected no stop in an end"; Sink's constructors
ignoring their class, now honouring a subclass of a sink's kind; and
test sinks of one value written as list sinks.

### Handed to DBIx-Squirrel, 2026-11-12

With every question settled, Iain asked DBIx-Squirrel's session to
review the design, IMPLEMENTATION.md and the prototype's code, and to
write its own `docs/design/DESIGN.md`: the downstream impact, and the
new version of DBIx::Squirrel it proposes, severing the tight coupling
by using Ekorn as it is (D1), and mirroring Ekorn's concepts, extended
where a database needs it. It's task 3 in DBIx-Squirrel's `TODO.md` on
its `pipeline-experimental` (DBIx-Squirrel
ec0f200e27bb25f81a8deebc0dc6b9786018bee0, after a message saying its
task 2 is replaced and task 1 overtaken). What it finds in Ekorn's design comes back as
messages; Iain approves both designs together, before either is split
into items.

### DBIx-Squirrel's first findings, 2026-11-12

DBIx-Squirrel's review began with four messages (DBIx-Squirrel
b2b3c9c76d4656b50982bec49c4ce2b29b282a30), and the news that 25 of its
26 test files pass against Ekorn's prototype, the other failing only
on v0.3.0's intended changes to gathers. What came of each:

- **An ordinary object taken for a sink:** a bind value with an
  `as_list` method passed `is_stage`. D49 renames the role methods.
- **`|` before Operators is loaded** died with "Undefined subroutine".
  The design's 12.3, the reference and IMPLEMENTATION.md's 7.4 now
  have a package load Operators with an empty import list.
- **`result_number` and `result_original`,** the rest of its Context:
  Iain decided, in its session, that it keeps both on its own side. The
  design's section 12 now names them.
- **12.3's columns and active handles:** Iain's amendments, made in its
  session, are written into 12.3 and D44.

### DBIx-Squirrel's design, its sinks, 2026-11-12

Two more messages from DBIx-Squirrel (DBIx-Squirrel
a1e2fcbbd53340fb1bbb95f5787ac9110b103d86 and
a3358e87d12681f6a8a63753150a53036d306de0), read and removed: its
iterator's `all`, `single` and `count` give way to Ekorn's sinks, which
became D50; and `insert_into`, its 2026-0012, is dropped for result
sinks of its own design, so the design's 12.4 keeps it only as an
example of a package's sink, not planned, and 11.2, 12.2, 18 and 20.2
say so.

### A list sink's one value, 2026-11-12

A message from DBIx-Squirrel (DBIx-Squirrel
9b11d961e061fbb6d7d127e6f8a99c17f2519858), read and removed: Iain's
proposal that a list sink in scalar context give a reference, as
DBIx::Squirrel's design has a sink given last say what comes back,
which a list sink giving its count broke. It became D51, taking in
the points its session found weighing it: the trap goes, `|` can end
in `all_items`, an empty result is true, and `to_hash` would want a
hash reference.

### `@{}`, explained, 2026-11-12

A message from DBIx-Squirrel (DBIx-Squirrel
36f74b2c013b4f2188d0df2b441a0dbe2934c9cd), read and removed: Iain
found a bare `@{ chain }` weird, and DBIx-Squirrel's design now ends
its chains in a sink. It became D52: `@{}` stays, explained in detail,
and Ekorn's drafts lead with a sink too, with more alternatives.

### `single`, and buffering, 2026-11-12

Two messages from DBIx-Squirrel (DBIx-Squirrel
062ea16c6a0dc32867342cd5d885205821b0ce33 and
b45d34bb8ef2601ee0f621c9ff10e00a21be91f4), read and removed. The
first: its iterator's `single` finishes its statement, so Iain chose
the same for Ekorn's, as D61. The second: its buffering may yet need
more of Ekorn's protocols, a fast path for sinks, a look-ahead that
consumes nothing, and telling a source how many are wanted; nothing is
asked until its spike shows a need, so nothing is added here. What it
relies on was checked: a step giving several values works with `all`,
and `ended` then says `done`, now tested; and `finish` after `single`
ends the run, `stopped`, already tested.

### Timings, and the overload, 2026-11-12

A message from DBIx-Squirrel (DBIx-Squirrel
9331a4d7ba024d3891e8dc47e9d336460a12aed5), read and removed: against
D62, its `$it->all` over 297,848 rows takes 0.150 s, from 0.403 s, and
`iterate(keep_all, $stage)` finishes, in 1.1 s; its `next`, its source
giving whole batches, 0.38 s against its version 2's 0.35 s. And its
task on the `&{}` overload, done as D63.

### `keep(N)`, 2026-11-12

A task from DBIx-Squirrel (DBIx-Squirrel
c41d9899b2af0ea5c60607a4519ce0042841302f), done and removed: Iain's
`keep(N)` sink, with the questions its session saw. It became D57,
each question settled by Iain here.

- **What's left:** coverage is below the floors (branch 86%, condition
  73%, POD 55%), from the new modules' error paths and their
  placeholder POD; CI doesn't run on `pipeline-experimental`. Each item
  the design is split into brings its part up to the floors. The
  findings above go into the design.

### Approved, and split into items, 2026-11-13

- **Outcome:** done, against Done when: the proofs hold, and Iain
  approved the design on 2026-11-13: "I've reviewed the design and am
  happy with it". Its questions, Q1 to Q33, and D1 to D70, are
  settled.
- **Split into items,** as Iain agreed the same day, each taking its
  share of the proofs as tests and of section 20 into its Done when:
  2026-0014, the lifecycle, now; then 2026-0021, the words, taking in
  2026-0015, retired into it; 2026-0024, canned stages, a new item;
  2026-0013, names in errors; 2026-0016, sources; 2026-0017, sinks;
  2026-0018, operators; and 2026-0025, the release of v0.3.0, a new
  item. 2026-0019 and 2026-0010 stay as they were.
- **DBIx-Squirrel** already knew, its session having taken in Iain's
  approval of both designs and split its own (DBIx-Squirrel
  ef654ec), so the task section 20.2 asks for would have repeated its
  plan; a message gives it Ekorn's items, in order, instead.
- **What's left:** each item's work, and coverage up to the floors,
  below them on `pipeline-experimental` (branch 90%, condition 82%,
  POD 43% when last run), as the new modules' POD is still a
  placeholder.
