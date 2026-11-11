# 2026-0020. pipeline() through a subclass makes the subclass

**Status:** shipped, unreleased

**Decisions:** D1 settled: Ekorn::X is the ancestor of DBIx::Squirrel::X, so Ekorn makes the class it was reached through. D2 settled: `pipeline`, imported through a subclass, is made for it. D3 settled: Pipes asks `pipeline_class`. D4 settled: names are kept per class, inherited one way. D5 settled: a subclass can override an ancestor's name. None open.

**Origin:** a TODO task from DBIx-Squirrel's session, 2026-11-11
(DBIx-Squirrel b42762959e467286e7406c2f86c4b944a9b101a6), for its
2026-0009

**Depends on:** 2026-0011

**Started:** 2026-11-11, in f9fe05315716be59936136817e484192900e557b

**Finished:** 2026-11-11

## Background

`pipeline`, from 2026-0011, made `__PACKAGE__->new`, so a pipeline made
with it was always an Ekorn::Pipeline, never DBIx::Squirrel::Pipeline,
the subclass where DBIx::Squirrel changes how its pipelines behave. A
wrapper of DBIx::Squirrel's couldn't fix it: `pipeline` looks names up
in the package that calls it, so a wrapper's package would be
searched, and the lookup, `_resolved`, is private. `named` was already
right, calling `new` on its invocant.

## Decisions

- [x] **D1.** What's the general rule? Ekorn::X is the non-database
  ancestor of DBIx::Squirrel::X, Iain decided on 2026-11-11, so Ekorn
  never names its own class where it makes something, but the class
  it was reached through. CLAUDE.md has the rule. Weighed against
  separate fixes for each case, which is how this went wrong.
- [x] **D2.** How does `pipeline` make a subclass? Imported through
  it, decided on 2026-11-11 with D1: Ekorn::Pipeline's `import`, which
  a subclass inherits, installs a function made for that subclass,
  reading its caller when it's called, so a module can export it again
  and names are still looked up in its users' packages. Weighed and
  set aside: `Subclass->pipeline(...)`, which can't be told from
  `pipeline('My::Pipeline', ...)`, a valid qualified name; and a public
  `pipeline_in($package, @stages)`, which every subclass would have to
  wrap, passing `scalar caller` itself. 2026-0011's D5 set
  `pipeline_in` aside, and nothing here needs it.
- [x] **D3.** What else breaks the rule today? Pipes, whose `pipe` and
  `tap` made Ekorn::Pipelines; fixed here with `pipeline_class`, as D1
  asks. `Stop` throws Ekorn::Pipeline::Stop, but it's a one-line
  wrapper over `throw`, a class method, so DBIx::Squirrel's Stop
  facade can make its own whenever its subclass needs it. `gather`
  blesses its own class, and no subclass of Gather is planned.
- [x] **D4.** Whose are the names? The class's they were defined
  through, inherited one way, Iain decided on 2026-11-11, after this
  record's first commit: "anything created in the DBIx::Squirrel::
  namespace needs to remain there. We mustn't cross the streams." One
  registry for every class let `DBIx::Squirrel::Pipeline->named('clean')`
  be found by Ekorn's own `pipeline('clean')`. Now a class sees its own
  names and its ancestors', never its descendants'; a subclass can't
  define a name it already sees, and an ancestor can define one its
  descendant has, each then seeing its own. Weighed: strictly separate
  registries, simpler to explain, but a subclass would lose the
  pipelines its ancestor names, which the notional class and subclass
  should keep.
- [x] **D5.** Can a subclass override a name its ancestor has? Yes,
  Iain decided on 2026-11-11, correcting D4 as first built, which
  croaked "already defined" for it, while letting an ancestor define a
  name its subclass had. That was lopsided, and unlike methods, which a
  subclass overrides as a matter of course. It had been meant to keep
  2026-0011's D6, that a pipeline once made never finds a name it used
  means something else; but a name is resolved when a pipeline is
  made, so a pipeline made before an override keeps what it found,
  and D6 holds. Now:
  - a class can't define the same name twice ("A pipeline named %s is
    already defined");
  - a subclass can define a name its ancestor has, and it and its own
    subclasses then get its pipeline, while the ancestor keeps its own;
  - an ancestor can define a name its subclass has, and each keeps its
    own;
  - an ancestor never sees a subclass's names.
  The cost is timing: code that looks a name up for a subclass before
  the subclass overrides it gets the ancestor's, and the subclass's
  after. The docs say to define names before using them, as Sugar
  will, at compile time. Iain asked the same day that the rules be
  spelled out in plain English, in full: the reference and the POD
  have a section of their own, Named pipelines and subclasses, with an
  example showing each.

## The plan

**What:** an `import` for Ekorn::Pipeline, exporting as Exporter does,
but making `pipeline`, asked for through a subclass, for that
subclass; and `pipeline_class` for Pipes.

**Steps:**

1. The code, in `lib/Ekorn/Pipeline.pm` and
   `lib/Ekorn/Pipeline/Pipes.pm`.
2. Tests, in `t/14-subclass.t`: the subclass made, names looked up in
   a user's package after a module re-exports it, Ekorn::Pipeline's own
   `pipeline` unchanged, a name a subclass doesn't export still
   croaking, and Pipes making the class `pipeline_class` names.
3. The POD, the reference and `Changes`; the rule in CLAUDE.md; this
   record's look ahead.
4. A message to DBIx-Squirrel saying how to use it, and the task gone
   from `TODO.md`.

**Done when:** a subclass can offer its users a `pipeline` that makes
the subclass and resolves names in the user's package, with a test,
on `pipeline-experimental`, with coverage at its floors; and
DBIx-Squirrel has its message.

## Looking ahead

Iain asked, on 2026-11-11, that the rule be checked against the work
planned in both repositories:

- **DBIx::Squirrel's facades:** Pipeline inherits `import`, so `use
  DBIx::Squirrel::Pipeline qw(pipeline)` needs nothing of it. Pipes
  can override `pipeline_class`. Stop, as D3 says.
- **2026-0010, Sugar:** at first a `pipeline_class` was asked of it,
  so DBIx-Squirrel's Sugar could hand its `pipeline` key on and get its
  own class back; D4 settles it otherwise. DBIx::Squirrel's Sugar
  defines its own pipelines, with `DBIx::Squirrel::Pipeline->named`,
  and Ekorn's makes only Ekorn::Pipelines. Its D10.
- **2026-0013, a pipeline's name in its errors:** a getter; unaffected.
- **2026-0014, the lifecycle hook:** objects as stages; unaffected.
- **2026-0015, Blocks:** each factory makes its type with a class
  method, so a subclass can wrap its own. Noted on the roadmap.
- **2026-0016 and 2026-0017, sources and sinks:** functions, not
  types; unaffected. DBIx-Squirrel's `insert_into`, its 2026-0012, is
  built from Ekorn's sink outside Ekorn's namespace, which
  `t/09-stage-modules.t` already covers for stages.
- **2026-0018, operators:** `|` makes the class of its operand, never
  one it names. Noted on the roadmap.
- **2026-0019, a strict is_stage:** tests with `isa`, so subclasses
  pass; unaffected.

## What happened

- **Outcome:** done as planned. The tests pass on 5.36.3 to 5.44.0
  under yath, and under `prove`; coverage holds at 100%; the
  reference's new example prints what it says.
- **Names per class (D4)** came after the first commit,
  3404072a86c6a10c4e80c7f6b6326a8ad0f6bd4e, in a second: `named` keeps
  a name under its invocant's class, and the lookup walks the class's
  linear `@ISA`, with `mro::get_linear_isa`, nearest first. Tested in
  `t/14-subclass.t`, a grandchild included. D5 came in a third commit:
  `named` checks only its class's own names for one already defined,
  not every name the class sees.
- **Changes from the plan:** the first `import` passed the rest to
  Exporter with `goto &Exporter::import`, which warns in a sub with a
  signature, as it passes `@_`; it calls `Exporter::export` with the
  caller instead, needing no `@_`. Iain asked, the same day, for
  `&{...};` in place of `goto` tail calls, which aren't cheap; the one
  left, in `croakf`, was tried as `&Carp::croak;` and reverted, as
  `croakf`'s frame then stays, and a module outside Ekorn's namespace
  has its errors reported at its own line, not its caller's
  (`t/09-stage-modules.t` and `t/12-documented.t` fail). It runs only
  when croaking.
- **The test packages and the example** set `@ISA` with `use parent
  -norequire`, at compile time, as an `import` called from a `BEGIN`
  block finds no inherited `import` in an `@ISA` set at run time.
- **What's left:** nothing; 2026-0010's D10 is settled by D4.
