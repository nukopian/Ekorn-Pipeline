# 2026-0011. A pipeline() function, and named pipelines

**Status:** open

**Decisions:** D1 settled: every argument is a stage, a code
reference, a pipeline or a name. D2 settled: a pipeline given last is
stages. D3 open: the name of the function that defines a named
pipeline as the program runs.

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
- [ ] **D3.** What is the function that defines a named pipeline as the
  program runs called? Kept apart from `pipeline`, so that `pipeline`
  only ever makes one: a string followed by an array reference could
  be told from a name followed by stages, but it would be the one
  exception to D1's rule. Candidates: `define_pipeline(name =>
  @stages)`, `name_pipeline(...)`, or a class method,
  `Ekorn::Pipeline->define(name => @stages)`.
