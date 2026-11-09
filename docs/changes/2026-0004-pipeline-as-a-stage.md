# 2026-0004. A pipeline given as a stage

**Status:** shipped in v0.1.3

**Decisions:** D1 settled: compose in place, as if given its stages(). D2 settled: export `is_stage`, which `new` uses too. D3 settled: by its place in each pipeline, "#2.3"; the refusal unchanged. D4 settled: v0.1.3. None open.

**Origin:** roadmap, added 2026-11-07, as an idea left over from
2026-0001, whose record has the prototype; opened on 2026-11-09, when
Iain asked what it would mean for DBIx-Squirrel

**Started:** 2026-11-09, in f7efd24badc2b42f8f7e0bb8a166283723c1fbca

**Finished:** 2026-11-09

## Background

`Ekorn::Pipeline->new` refuses a pipeline given as a stage: a pipeline
is a blessed hash that overloads `&{}`, not a code reference, so it's
"Expected stage #1 to be a code reference". Since v0.1.1, `stages()`
returns a pipeline's stages as a flat list, so `new($clean->stages,
take(10))` composes them; this item would let `new($clean, take(10))`
do the same.

2026-0001's [record](2026-0001-stages-method.md) weighed three ways of
taking a pipeline as a stage (not at all; running it once for each
value, as a wrapper does; composing it in place), and prototyped the
third on 2026-11-07, uncommitted. In brief:

- about fifteen lines in `new`, and four one-line changes so that
  `_iterator` names each stage by where it is; no change to the runner;
- `take(2)` inside, given 1 to 5, gave 2 in all, and a stop inside
  stopped the source;
- `new(new(@a), new(@b))` gave the same as `new(@a, @b)` for 36 pairs
  of stages, and all of `t/` passed;
- a nested stage was named by its place, "Pipeline stage #2.3 failed
  at", "#1.2.3" three deep; a flat pipeline's messages were as now;
- composed ran as fast as the stages listed by hand, and about 4.5
  times as fast as a wrapper.

It was left for a later version to keep the change around
DBIx::Squirrel small. `stages()` was chosen instead (2026-0001's D1),
and stays.

### What it means for DBIx-Squirrel

Looked at on 2026-11-09, against DBIx-Squirrel's `develop` at
bb218508ae7a747f8e00906c04a05b063ad8bb8d.

- **What it gets with no change of its own.**
  `DBIx::Squirrel::Pipeline` is an empty subclass of `Ekorn::Pipeline`,
  so it inherits the new `new`, and `DBIx::Squirrel::Pipeline->new($hits,
  take(1))` would work as soon as an Ekorn release within its range,
  `>= v0.1.1, < v0.2.0`, is installed.
- **What needs a change there.** The case worth having,
  `$dbh->iterate($sql, $hits)`, needs DBIx::Squirrel to see a pipeline
  at the end of a call's arguments as a stage. It looks for code
  references with Ref::Util's `is_coderef`: in `split_stages`
  (`lib/DBIx/Squirrel/Util.pm`), in `_ends_in_stages`
  (`lib/DBIx/Squirrel/Sugar.pm`), and in Sugar's check of a statement's
  definition. A pipeline fails all three, and is taken for a bind value.
  Once they accept it, the rest follows: its iterator passes its stages
  to `new` (`lib/DBIx/Squirrel/Iterator.pm`), which would compose them.
  No working code changes: a pipeline given there today is a wrong bind
  value or an error.
- **Its docs** say "Give `$hits->stages`, not `$hits`", in its
  reference and how-to, which would change.
- So DBIx-Squirrel's part is a task in its `TODO.md`, waiting on the
  Ekorn release: recognise a pipeline in those places, test it, and
  rewrite those passages. A guess at its size: S (2).

## Decisions

- [x] **D1.** Should `new` compose a pipeline given as a stage in
  place, its stages running in the outer pipeline's run as if listed
  there? The alternatives were to keep refusing it, or to run it once
  for each value, as a wrapper does, which makes `take` inside it mean
  something other than its obvious reading. The prototype found
  composing correct, as fast as listing the stages, and small.
  Composed in place, decided on 2026-11-09: a pipeline given as a stage
  means what giving its `stages()` there means, so `new($p, take(10))`
  is `new($p->stages, take(10))`. Iain: "as if we'd done
  `$pipeline->stages()`". So the two can't differ, and `stages()`
  stays.
- [x] **D2.** Should Ekorn::Pipeline export an `is_stage` test, true
  for a code reference (a `gather` stage among them) or an
  `Ekorn::Pipeline`, for DBIx::Squirrel and other modules taking stages
  off the end of their arguments? Without it, each writes its own, and
  they can drift from what `new` accepts. It would be a new public name,
  in `@EXPORT_OK`. Yes, decided on 2026-11-09: Ekorn::Pipeline exports
  `is_stage` on request, and `new` uses it too, so what it accepts and
  what others take for a stage are one definition.
- [x] **D3.** How do messages name a stage inside a nested pipeline?
  The prototype names it by its place in each pipeline, "#2.3", so the
  two DIAGNOSTICS entries with `#%d` become `#%s`, though a flat
  pipeline's messages read as now. And should the refusal of a bad
  stage say "Expected stage #%d to be a code reference or a pipeline"?
  Decided on 2026-11-09: "#2.3", as prototyped, and the refusal left as
  it is. Each pipeline keeps a name for each of its stages beside them:
  a stage given directly is named by its place, and the stages of a
  pipeline given as a stage take its place before their own names, so
  three deep is "#1.2.3", and a flat pipeline's names, and messages,
  are as now. The runner prints the name where it printed the place.
  `stages()` returns the stages without their names, so
  `new($p->stages, ...)` names them flat, as now; only `new($p, ...)`
  gives the nested names, though the two run the same (D1). Leaving the
  refusal keeps the messages a flat pipeline can give unchanged, which
  D4 turns on.
  Added on 2026-11-09, in review: whether `->stages` could carry the
  nested names too. Left flat: it returns plain code references, to go
  where only code references go, so nothing ties them to the pipeline
  they came from. Tagging or wrapping them would break `stages()`
  returning the stages as given (2026-0001) and add a call to every
  stage; a table from code reference to name can't tell which name is
  meant when one stage is in several pipelines, or twice in one; and
  spotting a pipeline's stages in a run of references is the same
  guess. With `is_stage`, functions can take the pipeline itself, so
  `->stages` is left for those that take only code references.
  Also decided then: `new` takes a given pipeline's stages from its
  `stages` method, not its internals, so `new($p)` and
  `new($p->stages)` run the same even for a subclass that overrides
  it, as D1 says. Its own names are used if the method returns the
  stages it was made with; otherwise the stages are named by their
  places in what it returns, one level deep, and a pipeline whose
  method returns something not a code reference is refused as a bad
  stage, by its own place.
- [x] **D4.** v0.1.3 or v0.2.0? A change to the messages makes v0.2.0,
  under CLAUDE.md's rule, which means a task for DBIx-Squirrel to test
  it and move its range. If a flat pipeline's messages are unchanged,
  and a nested stage's name and accepting a pipeline are only
  additions, it's v0.1.3, and reaches DBIx::Squirrel's users with no
  release of its own. Rewording the refusal (D3) would argue for
  v0.2.0. v0.1.3, decided on 2026-11-09: with the refusal left as it
  is (D3), no message a pipeline gives today changes, and the rest,
  taking a pipeline as a stage, nested names and `is_stage`, only adds.
  DBIx-Squirrel's range takes it as it stands; its task is only to use
  it.

## The plan

**What:** `Ekorn::Pipeline->new` takes a pipeline where a stage goes,
composing its stages in place (D1), and names each stage by its place
in each pipeline, "#2.3" (D3). `is_stage`, exported on request, is true
for a code reference or an `Ekorn::Pipeline`, and `new` uses it (D2).
No message a pipeline gives today changes, and it ships in v0.1.3 (D4).

**Why:** `new($clean, take(10))` reads as what's meant, where
`new($clean->stages, take(10))` needs the reader to know `stages()`; a
message can say which stage inside a pipeline died; and DBIx::Squirrel,
and any module taking stages off the end of its arguments, can take a
pipeline there with one test, the same as `new`'s.

**Steps:**

1. In `lib/Ekorn/Pipeline.pm`: `is_stage`, in `@EXPORT_OK`; `new`
   checks each stage with it, splices a pipeline's stages in, and keeps
   a name for each stage beside them; `_iterator` takes the names, and
   its two messages print a stage's name where they printed its place.
   The refusal of a bad stage is unchanged.
2. Tests in a new `t/10-pipeline-as-stage.t`, from the prototype's
   checks in 2026-0001's record: composing gives what `stages()` gives;
   a stop inside stops the source; state is per run; ends run in order;
   a stop's values go on; `ending()` inside; nested names in messages,
   three deep, and for a bad `gather` inside; an empty pipeline; `pipe`
   and `tap`; a subclass; `is_stage` for each kind of thing.
3. The POD's `new`, `stages` and DIAGNOSTICS, and a section for
   `is_stage`; the same in `docs/REFERENCE.md` and `docs/HOWTO.md`
   (whose "A pipeline isn't a stage itself" goes), the manuals made
   again, and the README's example if it reads better.
4. `Changes`, under Unreleased, with a precis naming 2026-0004.
5. A task in DBIx-Squirrel's `TODO.md`, waiting on Ekorn-Pipeline
   v0.1.3: use `is_stage` in `split_stages`, `_ends_in_stages` and
   Sugar's check of a statement's definition, test
   `iterate($sql, $pipeline)`, and rewrite "Give `$hits->stages`, not
   `$hits`" in its reference and how-to.

**Done when:** the tests pass on each Perl from 5.36 to 5.44, and under
`prove`; coverage stays above its floors; perlcritic and perltidy are
clean; the docs' changed examples print what they say; and the task is
in DBIx-Squirrel's `TODO.md`.

## What happened

- **Outcome:** done as planned. `new` composes a pipeline given as a
  stage, names a stage inside it "#2.3", and uses `is_stage`, which is
  exported on request. The tests pass with yath on 5.36.3, 5.38.5,
  5.40.5, 5.42.3 and 5.44.0, and under `prove`; coverage is at its
  floors (statement, branch, subroutine and pod 100%, condition 96.9%);
  perlcritic and perltidy are clean; the changed examples in the
  how-to and the reference print what they say. DBIx-Squirrel's task
  is in its `TODO.md`.
- **Changes from the plan:**
  - In review, `new` was changed to take a given pipeline's stages from
    its `stages` method rather than its internals, as the prototype
    did, so `new($p)` and `new($p->stages)` can't differ for a subclass
    that overrides it. Its names are kept only if the method returns
    the stages it was made with, and are its places in what it returns
    otherwise; something not a code reference is refused by the
    pipeline's own place, with the existing message. D3 has the why.
  - Whether `->stages` could carry the nested names was asked in
    review, and it was left flat (D3).
  - The prototype's composing test compared stages doing arithmetic on
    the array references `batch` and `collect` pass on, which compared
    addresses; the test's stages leave references alone.
- **Measurements:** none taken; the prototype's (2026-0001) found
  composing as fast as listing the stages, and nothing in the runner's
  loop changed since.
- **Wash-up, 2026-11-09:** a review of everything since v0.1.2 found
  `stages()` still described as returning the stages "as given to
  `new`", which a pipeline given as a stage makes untrue; "the same
  pipeline" for two that differ in their messages; the refusal's
  DIAGNOSTICS entry missing an overridden `stages` method; and a
  redundant check in the tests. `_composed` now checks that the stages
  are code references only when the method's list isn't the one the
  pipeline was made with, which `new` has checked already. DBIx-Squirrel's
  tests, 1431 assertions, passed against `develop` on 5.36.3 and
  5.44.0.
- **What's left:** the release, v0.1.3, which Iain gated on 2026-11-09
  on DBIx-Squirrel's sign-off, a task in its `TODO.md`, to try
  `develop` with its own use of `is_stage` first; and DBIx-Squirrel's
  move to v0.1.3 after it. Both are in `TODO.md`.
- **Found in a full check, 2026-11-09:** exporting `is_stage` gave
  Ekorn::Pipeline an `import` method, from Exporter, which a subclass
  inherits: `use My::Subclass qw(name)` now croaks unless the subclass
  exports `name`, where v0.1.2 ignored the list. It's in `Changes`, and
  DBIx-Squirrel's task 1 notes it for `DBIx::Squirrel::Pipeline`. A
  `gather` block's stage must still be a code reference; the docs now
  say a pipeline isn't accepted there.
