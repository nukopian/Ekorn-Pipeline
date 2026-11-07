# 2026-0003. A pipeline in scalar context

**Status:** open

**Origin:** roadmap, added 2026-11-07, from a review of the docs before
v0.1.0

## Background

Called in scalar context, `my $n = $p->(@values)`, a pipeline returns
how many results came out. The how-to and the reference document it,
as "Count the results"; changing it after v0.1 would be a v0.2.0.

| Call                     | In scalar context, returns                  |
|--------------------------|---------------------------------------------|
| `$p->(@values)`          | how many results, as `my $n = @list` would  |
| `$object->pipe(@stages)` | the first result, or `undef`                |
| `$next->()`, an iterator | the next result, or `undef` at the end      |

The count isn't a design of its own: the pipeline ends `return
@results`, and Perl gives an array's length in scalar context. `pipe`
differs on purpose, as a method on an object that usually gives one
thing back. DBIx::Squirrel follows the same rule in its own functions:
its iterator's remaining results, and the functions in its Sugar
module, return how many in scalar context.

## Decisions

- [ ] **D1.** What does a pipeline return in scalar context?
  - **A.** Keep the count, and promise it: Perl's own rule for a list,
    documented already, and what DBIx::Squirrel does; it differs from
    `pipe`.
  - **B.** The first result, as `pipe` does: one rule for both, but a
    function returning `$p->(...)` would change meaning for its
    callers, and it's a code change, tests and docs.
  - **C.** The last result, as a list in scalar context would, written
    `(...)[-1]`: rarely what anyone wants, and the same costs as B.
  - **D.** Leave it unpromised: the count, undocumented. No commitment,
    but it's documented already, so taking it out only hides it.

  Recommended: A. It's what a Perl programmer expects of a call
  returning a list, what DBIx::Squirrel's own functions do, and what
  the docs say already; the difference from `pipe` is documented beside
  `pipe` in the reference. Nothing changes for DBIx::Squirrel, and no
  new trial is needed.
