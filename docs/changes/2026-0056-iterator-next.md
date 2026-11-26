# 2026-0056. An iterator's next

**Status:** open

**Decisions:** D1 open: add `next`, or point to `call`. D2 open: is it
called as the iterator is, in every context.

**Origin:** a message from DBIx-Squirrel's session, 2026-11-26
(DBIx-Squirrel bfe99ae7d999121c933b1902df007b88752d51b9), added
2026-11-26

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

- [ ] **D1.** Add `next`, or point to `call`? `call` already does what
  `next` would, but its name says nothing about iterating, and a loop
  written for DBIx::Squirrel's iterator wouldn't read Ekorn's. `next`
  is the name DBIx-Squirrel's readers know, and the one Perl's
  iterators commonly use. Recommendation: add `next`, an XS item,
  only adding, so a v0.4.x.
- [ ] **D2.** Is `next` called as the iterator is, in every context?
  Calling the iterator in scalar context gives the next value, or
  `undef` at the end, as DBIx::Squirrel's `next` does. Recommendation:
  yes, the same in every way, so the docs can say "`$next->next` is
  `$next->()`" and nothing more.
