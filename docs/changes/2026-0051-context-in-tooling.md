# 2026-0051. Ekorn::Pipeline::Context's functions in Tooling

**Status:** shipped, unreleased

**Decisions:** D1 settled: a v0.3.x, not the v0.4.0 first planned. D2
settled: a `:context` tag, and in `:all`.

**Origin:** 2026-0046's D5 ([record](2026-0046-context.md)), added to
the roadmap 2026-11-24

**Depends on:** 2026-0052, shipped in v0.3.13

**Started:** 2026-11-24

**Finished:** 2026-11-24

## Background

2026-0046 put `result_number` and `result_original` in
Ekorn::Pipeline::Context in v0.3.11, but left them out of
Ekorn::Pipeline::Tooling. DBIx::Squirrel::Tooling exports functions of
the same names, and DBIx-Squirrel v3.5.0's `t/28-tooling.t`, which
ships in its tarball, fails when both Toolings export different subs by
one name. As its range took every v0.3.x, v3.5.0 would have failed its
tests once Ekorn's Tooling exported them, so this item was planned for
the first v0.4.0, which its range excludes.

Since then, DBIx::Squirrel's `result_number` became Ekorn's own, in its
v3.6.0, and, with 2026-0052's source part, its `result_original` too,
in its v3.6.1, released 2026-11-24 (DBIx-Squirrel
c8d16af8fd1b66ec4234055d1216849bedce9d10), whose floor is v0.3.14. Its
`t/28-tooling.t` and `xt/ekorn-tooling.t`, from that tag, pass against
a copy of Ekorn's Tooling with `:context` added; v3.6.0's
`t/28-tooling.t` fails, on `result_original`.

## Decisions

- [x] **D1.** Which version? A v0.3.x, Iain decided on 2026-11-24.
  v0.4.0 was planned to keep DBIx-Squirrel v3.5.0's tests passing,
  but its latest release, v3.6.1, passes with the names in Tooling,
  and a v0.4.0 would now break it: its range is `< v0.4.0`, and CPAN's
  index serves only the latest Ekorn, so a fresh install of v3.6.1
  would fail until DBIx-Squirrel released a range taking v0.4.0. A
  v0.3.x is inside v3.6.1's range, and only adds, which Tooling's POD
  allows for a name in a tag. DBIx-Squirrel's v3.5.0 and v3.6.0 would
  fail their own `t/28-tooling.t` if installed explicitly beside it,
  as older releases than the one CPAN's index gives.
- [x] **D2.** Which tag? `:context`, DBIx::Squirrel::Tooling's name
  for its own, holding both names, and both in `:all`, as 2026-0046's
  D5 first had it, so the two Toolings agree on every tag and name.

## The plan

**What:** D1 and D2: Tooling exports `result_number` and
`result_original` in `:context` and `:all`, and its POD, the
reference, the how-to, the README and Context's POD say so, in place
of saying they're left out.

**Steps:**

1. Tooling and `t/23-tooling.t`.
2. The docs: Tooling's and Context's POD; the reference's Tooling
   table, its index entries for Tooling and Context, and its "Which
   result" section; the how-to's table of tags and its recipe; the
   README's list; the manuals; `Changes`.
3. Every check, and DBIx-Squirrel v3.6.1's tooling tests against the
   working copy.
4. A task for DBIx-Squirrel to test against `develop` before the
   release, and a word that its 2026-0047, which waited for this at
   v0.4.0, no longer needs to.

**Done when:** the tests pass on 5.36 to 5.44, coverage holds its
floors, and DBIx-Squirrel's message says its suite passes against
`develop`.

## What happened

Done as planned, on 2026-11-24.

- Tooling takes Ekorn::Pipeline::Context's `:all`, and its `:context`
  tag holds both names, as do `:all` and `@EXPORT_OK`;
  `t/23-tooling.t` checks the tag holds what the module exports.
- The docs that said the functions were left out, and why, now say
  where they are: Tooling's and Context's POD, the reference's Tooling
  table, its "Which result" section and its index entries for Tooling
  and Context, the how-to's table of tags and its recipe, which no
  longer imports Context itself, as `:all` gives it, and the README.
- DBIx-Squirrel v3.6.1's `t/28-tooling.t` and `xt/ekorn-tooling.t`,
  from its tag, pass against the working copy, run with `prove`.
- Every check passed on 5.36 to 5.44, with coverage at its floors.

DBIx-Squirrel's test against `develop`, at
3f18f252191f19ecaa6969e92d0598cf7fe5094b (its message of 2026-11-24,
DBIx-Squirrel f1f048430a390b5cf88a09ad219850c41d312fd7): its
`develop`, v3.6.1's code, passed its whole suite, MySQL and PostgreSQL
included, on 5.36 to 5.44, and v3.6.1 as released passed on 5.36 and
5.44. As expected, v3.6.0 and v3.5.0 from their tags fail their
`t/28-tooling.t`, so installing either by name beside v0.3.15 is
refused by its tests; v3.6.1, which CPAN's index gives, installs. Iain
chose to release it as built, both names in `:context` and `:all`,
rather than keep them out of `:all` to spare the older releases.
DBIx-Squirrel keeps its 2026-0047, reworded, to take Ekorn's first
v0.4.0, whenever there is one; a task from here then starts it, as
docs/MAINTAINING.md has for any v0.4.0.
