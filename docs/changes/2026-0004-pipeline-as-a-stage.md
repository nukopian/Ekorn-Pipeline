# 2026-0004. A pipeline given as a stage

**Status:** open

**Decisions:** D1 settled: compose in place, as if given its stages(). D2 settled: export `is_stage`, which `new` uses too. D3 settled: by its place in each pipeline, "#2.3"; the refusal unchanged. D4 open: v0.1.3 or v0.2.0.

**Origin:** roadmap, added 2026-11-07, as an idea left over from
2026-0001, whose record has the prototype; opened on 2026-11-09, when
Iain asked what it would mean for DBIx-Squirrel

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
- [ ] **D4.** v0.1.3 or v0.2.0? A change to the messages makes v0.2.0,
  under CLAUDE.md's rule, which means a task for DBIx-Squirrel to test
  it and move its range. If a flat pipeline's messages are unchanged,
  and a nested stage's name and accepting a pipeline are only
  additions, it's v0.1.3, and reaches DBIx::Squirrel's users with no
  release of its own. Rewording the refusal (D3) would argue for
  v0.2.0. Recommended: v0.1.3, keeping the refusal as it is.
