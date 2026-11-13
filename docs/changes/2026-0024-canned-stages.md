# 2026-0024. Canned stages as objects, and a take stage for each keep sink

**Status:** in progress

**Decisions:** None of its own: the design's (2026-0022's D4, for its
Q12, and D58) settle it.

**Origin:** roadmap, added 2026-11-13, split from the design approved
that day (2026-0022)

**Depends on:** 2026-0014, shipped unreleased

**Started:** 2026-11-13

## Background

The canned stages in Stages::Flow, Batch and Taps were code
references in v0.2.0. Since 2026-0014, a `gather` is a Gather object,
so those made with it, all but three, are already Elements: objects
called as code references. `take_while`, `peek` and `dump_to` are
plain closures. And `take_first`, `take_last` and `take_single`, the
stages of the `keep` sinks, were built on `pipeline-experimental`
under the design (2026-0022's D58), with their POD, tests and an entry
in `Changes` naming 2026-0022.

## Decisions

None of its own. The design's 8.1 settles both parts: each canned
stage returns an Ekorn::Pipeline::Stage or a Gather (D4, its Q12), a
v0.3.0 change said in `Changes`; and every `keep` sink but `keep_all`
has a `take` stage passing on what it would give (D58).

## The plan

As the roadmap gave it on 2026-11-13:

> The canned stages made with `gather` are Elements, as the design's
> 8.1 settles (Q12, D4), and `take_first`, `take_last` and
> `take_single`, already in Stages::Flow, join `take` as the stages of
> the `keep` sinks (2026-0022's D58). Done when the stages, their POD,
> tests and docs are in, with coverage above the floors.

Steps:

1. `take_while`, `peek` and `dump_to` return an Ekorn::Pipeline::Stage
   of their closure.
2. A test that every canned stage is an Element, an object called as a
   code reference, and not a plain code reference.
3. The modules' POD and the reference say each stage is an object,
   called as a code reference, and what that changes for code testing
   `ref` or `is_coderef`; and say which `keep` sink each `take` stage
   matches.
4. `Changes`: the change, marked "Changed", and the take stages'
   entry naming this item.

## What happened

Nothing yet.
