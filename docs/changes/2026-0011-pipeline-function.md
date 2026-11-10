# 2026-0011. A pipeline() function, and named pipelines

**Status:** open

**Decisions:** D1 settled: every argument is a stage, a code
reference, a pipeline or a name. D2 settled: a pipeline given last is
stages. D3 settled: `named`, on the class to define from stages, and
on a pipeline to name it. None open.

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
