# 2026-0011. A pipeline() function, and named pipelines

**Status:** open

**Decisions:** D1 settled: every argument is a stage, a code
reference, a pipeline or a name. D2 settled: a pipeline given last is
stages. D3 settled: `named`, on the class to define from stages, and
on a pipeline to name it. D4 settled: names are read only by
`pipeline`, `named` and Sugar; `is_stage` stays false for a string. D5
settled: another package's names by qualifying them; no new API. D6
settled: a name is resolved when the pipeline is made, as the docs
say. D7 settled: it ships in a v0.2.x. None open.

**Origin:** roadmap, added 2026-11-10, from Iain, while settling
2026-0010's questions: an exported `pipeline(sub {...} => sub {...})`
returning a new pipeline, so that functions taking code references as
arguments can tell arguments from stages; then that it could answer
`pipeline('name')` too

## Background

A function that takes stages from its caller, as its last arguments,
tells them from its other arguments with `is_stage`. That fails when
its values can be code references themselves: a callback is a value,
and a stage, and nothing tells them apart. 2026-0010 hit this, as the
function of a named pipeline takes values, and couldn't take stages
after them (its D1, at first).

A Pipeline object is never mistaken for a value by convention: a
function can take one given last as its stages. Making one with
`Ekorn::Pipeline->new(...)` at every call is long, so an exported
function makes it short:

```perl
use Ekorn::Pipeline qw(pipeline);

my @out = apply_all(@callbacks, pipeline(sub { $_->() } => take(3)));
```

Named pipelines (2026-0010) need a way to fetch a pipeline by its
name, which the record had as `pipeline('name')`. Rather than a second
meaning, a name is a third kind of stage, alongside a code reference
and a pipeline, so `pipeline('name')` is a pipeline of one stage. So
the names are kept here, in Ekorn::Pipeline, and 2026-0010's Sugar
fills them as the program compiles.

## Decisions

- [x] **D1.** What does `pipeline(...)` take? Stages, decided on
  2026-11-10, each a code reference, a pipeline, or the name of a
  pipeline, and returns a new pipeline of them:

  ```perl
  pipeline(sub { uc } => take(5))              # new, from stages
  pipeline('active_roles')                     # the named one
  pipeline('active_roles' => take(5))          # it, then more
  pipeline('My::Module::clean' => sub {...})   # another package's
  ```

  A name is looked up in the caller's package, unless it's qualified,
  as 2026-0010's D3 says, when the pipeline is made, so a name not
  defined fails then, not when it runs. One rule, rather than a
  function with several meanings; and it settles 2026-0010's D7, a
  definition naming another in the same `use`.
- [x] **D2.** How does a function tell stages from values that may be
  code references? A pipeline given last is stages, decided on
  2026-11-10: `active_roles(@users, pipeline(sub { uc }))`. The how-to
  and the reference show it as the way for an author whose values
  can be code references, beside taking code references with
  `is_stage` for one whose values can't.
- [x] **D3.** How is a named pipeline defined as the program runs?
  With `named`, decided on 2026-11-10, in two forms, each returning
  the pipeline:

  ```perl
  Ekorn::Pipeline->named(clean => @stages);          # define from stages
  Ekorn::Pipeline->new(@stages)->named('clean');     # name one you have
  ```

  On the class, it makes a pipeline of the stages after the name,
  which follow D1's rule, so they can name other pipelines; on a
  pipeline, it names that one. The name goes in the caller's package,
  unless it's qualified. A name already defined croaks, unless it's
  the same pipeline again, as DBIx::Squirrel::Sugar does.

  Weighed and set aside:
  - **`new('name' => @stages)`:** under D1 a string where a stage goes
    is a name to look up, so `new` would read a leading string one
    way and `pipeline()` another, and a constructor that registers a
    name as a side effect surprises.
  - **`name`:** `$obj->name` usually asks an object its name, so a
    setter would do two jobs. `name` is left free for a getter, which
    a later item could use in messages, "Pipeline stage #2 of clean
    failed": a change to the messages, so a v0.2.0.
  - **`$p->name(clean => @stages)`:** the pipeline named wouldn't be
    the one it was called on.
  - **A function of its own,** such as `define_pipeline`: a second
    name beside `pipeline` for what a method does.
- [x] **D4.** Where is a name read as a stage? Only by `pipeline(...)`,
  `named` and Sugar's definitions, decided on 2026-11-10, from
  a message from DBIx-Squirrel, 2026-11-10 (DBIx-Squirrel 60dd1af8f11b7661b4e47decadf9885d3e22a2d3). `is_stage` stays false for a string, so DBIx::Squirrel's
  `split_stages` never takes a bind value such as `'clean'` for a
  stage, and the reference says so, for callers to rely on. `new`
  doesn't read names either: its message, "Expected stage #%d to be a
  code reference or a pipeline", would have to change, which is a
  v0.3.0. `pipeline` has a message of its own for a stage it can't
  read.
- [x] **D5.** How does code look names up on another package's behalf,
  as DBIx::Squirrel::Sugar would for its caller? By qualifying them,
  decided on 2026-11-10, from the same message: `"${package}::clean"`,
  as D1 allows. The docs show it as the way. A helper,
  `pipeline_in($package, @stages)`, was weighed and left out, as
  qualifying needs nothing new; it's cheap to add later, since
  `import_into` (2026-0010's D6) needs the same lookup inside.
- [x] **D6.** When is a name resolved? When the pipeline is made, not
  when it runs, decided on 2026-11-10, and the docs say so plainly, as
  the same message asked: DBIx::Squirrel::Sugar finds a database by its
  name when a statement runs, so in one `use` the two differ. A name
  can't be defined again, as D3 says, so a pipeline already made never
  sees a different one.
- [x] **D7.** What version does it ship in? A v0.2.x, decided on
  2026-11-10, from the same message: it only adds, and with D4 changes
  no message, so it reaches DBIx::Squirrel's users within its range,
  `>= v0.2.0, < v0.3.0`, with no release there.
