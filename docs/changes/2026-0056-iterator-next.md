# 2026-0056. An iterator's next

**Status:** shipped, unreleased

**Decisions:** D1 settled: add `next`. D2 settled: it's called as the
iterator is, in every context.

**Origin:** a message from DBIx-Squirrel's session, 2026-11-26
(DBIx-Squirrel bfe99ae7d999121c933b1902df007b88752d51b9), added
2026-11-26

**Started:** 2026-11-26

**Finished:** 2026-11-26

## Background

Ekorn::Pipeline::Iterator hands out its next value when it's called as
a code reference, `$next->()`. It returns an empty list once the values
run out, so it's read in list context, as `while (my($value) =
$next->()) { ... }`.

DBIx::Squirrel::Iterator has the same methods as Ekorn's, `all`,
`all_arrayref`, `first`, `single`, `finish` and `ended`, and `next`,
which its readers use most: `while (my($row) = $it->next) { ... }`.
Its `next` returns the next result, or an empty list when there are no
more, and is read in list context too. DBIx-Squirrel's guide, writing
of Ekorn's iterator beside its own in its Part 2 (its roadmap
2026-0055), tells its readers to call Ekorn's where theirs has `next`.
It calls that friction, not a fault: a `next` that does what calling
the iterator does would let one loop read either. It needs nothing.

Every one of Ekorn's types is an Ekorn::Pipeline::Element, which
already has a method, `call`, that calls the element as calling it as
a code reference does. So `while (my($value) = $next->call) { ... }`
works on an iterator today, though no document shows it for one.

`next` is a Perl keyword, as `all` is a builtin from 5.42, so the sub
takes `## no critic (Subroutines::ProhibitBuiltinHomonyms)`, as
DBIx::Squirrel's `next` and Ekorn's `all` do. A method named `next` is
called only as a method, so it doesn't clash with the keyword.

## Decisions

- [x] **D1.** Add `next`, or point to `call`? `call` already does what
  `next` would, but its name says nothing about iterating, and a loop
  written for DBIx::Squirrel's iterator wouldn't read Ekorn's. `next`
  is the name DBIx-Squirrel's readers know, and the one Perl's
  iterators commonly use. Add `next`, as Iain decided on 2026-11-26,
  as recommended: an XS item, only adding, so a v0.4.x.
- [x] **D2.** Is `next` called as the iterator is, in every context?
  Calling the iterator in scalar context gives the next value, or
  `undef` at the end, as DBIx::Squirrel's `next` does. Yes, the same
  in every way, as Iain decided on 2026-11-26, as recommended, so the
  docs can say "`$next->next` is `$next->()`" and nothing more.

## The plan

**What:** a method, `next`, on Ekorn::Pipeline::Iterator, doing what
calling the iterator does, in every context (D1, D2).

**Why:** DBIx-Squirrel's readers loop with `while (my($row) =
$it->next)`, and its guide has to tell them to call Ekorn's iterator
instead; with `next`, one loop reads either (Background).

**Steps:**

1. `lib/Ekorn/Pipeline/Iterator.pm`: `sub next ($self) { return
   $self->{call}->() }`, with `## no critic
   (Subroutines::ProhibitBuiltinHomonyms)`, before `all`; in the POD,
   a `=head2 next` before `all`, and a line in the SYNOPSIS.
2. Tests in `t/15-proofs.t`, beside `all`'s: in a `while` loop, the
   same values as calling the iterator; mixed with calls; an `undef`
   value handed out, not taken for the end; in scalar context, the
   next value, then `undef`; an empty list once the values run out,
   and after `finish`.
3. `docs/REFERENCE.md`: under Iterators, a sentence saying `next` is
   `$next->()`, and an entry for it in the index; `scripts/manuals`
   run, and `xt/manuals.t` passing.
4. `Changes`, under Unreleased: a precis naming roadmap 2026-0056, and
   the entry; the item leaves `ROADMAP.md` in the same commit.
5. A message for DBIx-Squirrel, in its `TODO.md`, once it's committed:
   the method, and that its guide can drop the advice to call Ekorn's
   iterator once it requires the release.

**Done when:** the method, its tests and its POD are in; the reference
and `Changes` say so; `yath test` passes on 5.36 and 5.44, coverage
stays above its floors, perlcritic and perltidy are clean; and
DBIx-Squirrel has the message.

## What happened

- **Outcome:** as planned. `next` returns `$self->{call}->()`, so it
  is a call to the iterator in every context; its tests in
  `t/15-proofs.t` cover a `while` loop, mixing with calls and `all`,
  `undef`, 0 and the empty string handed out, scalar context, a sink
  of many's result, and `finish`. `yath test` passes on 5.36 and 5.44,
  perlcritic and perltidy are clean, and coverage stays at its floors,
  100% of statements, branches, subroutines and POD.
- **What's left:** the message for DBIx-Squirrel (step 5), sent after
  this commit.
