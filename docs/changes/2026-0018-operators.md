# 2026-0018. Operators: `|`, `|=` and `@{}`

**Status:** in progress

**Decisions:** None of its own: the design's section 9 (2026-0022's
D14, D18, D23, D32, D51 and D52) settles it.

**Origin:** roadmap, added 2026-11-10 from DBIx-Squirrel's grammar of
sources, stages, gathers and sinks, rewritten from the design approved
on 2026-11-13 (2026-0022)

**Depends on:** 2026-0016 and 2026-0017, shipped unreleased

**Started:** 2026-11-13

## Background

The prototype built Ekorn::Pipeline::Operators as the design's
section 9 has it: `|` joining a source, stages and a sink, `|=`, and
`@{}` reading a source through, in force lexically, with `chain` and
`drain` for a package's own source class. Its POD is a placeholder,
and its conditions aren't all tested.

## Decisions

None of its own.

## The plan

As the roadmap gave it on 2026-11-13:

> Ekorn::Pipeline::Operators, as the design's section 9 has it: `|`
> joining a source, stages and a sink, `|=`, and `@{}` reading a source
> through, in force lexically, with `chain` and `drain` for a package's
> own source class. Every stage in a chain is a `stage {...}` or a
> ready-made part, as `|` between two code references ORs their
> addresses, and the docs say so loudly. Done when the module, its
> POD, tests and docs are in, with coverage above the floors.

Steps: tests for what coverage misses; the module's POD in full; the
reference's Operators section, from the draft, and Delivering parts'
`|` for your sources; the how-to's part on chaining, from the draft;
Changes.

## What happened

Nothing yet.
