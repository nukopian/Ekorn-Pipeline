# 2026-0055. An iterator's all_arrayref

**Status:** open

**Decisions:** D1 settled: `all_arrayref`, the name. D2 open: `all`
keeps its array reference in scalar context.

**Origin:** roadmap, added 2026-11-25

## Background

Ekorn::Pipeline::Iterator's `all` returns every value still to come:
as a list, or, in scalar context, as an array reference. Where the
context isn't the caller's to see, the list is what they get:

- in a hash or array constructor, as `{ rows => $next->all }`, which
  flattens the values into the hash, with an "Odd number of elements"
  warning at best, and keys and values out of step at worst;
- as an argument, as `report($next->all, $title)`;
- returned from a sub, as `return $next->all`, which gives a list or a
  reference as the sub's caller decides.

Ekorn's own `drain`, in Ekorn::Pipeline::Operators, writes `scalar
...->all` to be sure of a reference. A method that always gives one
says what the caller means, and takes the context out of it.

DBIx::Squirrel::Iterator has an `all` of its own, the same in both
contexts, which wraps an Ekorn run (`$self->{run}`) rather than
inheriting from Ekorn's iterator, so it won't gain the method from
Ekorn, and needs its own to match.

## Decisions

- [x] **D1.** What's it called? `all_arrayref`, as Iain decided on
  2026-11-25. Plain `arrayref` was proposed first, but DBI's
  `fetchrow_arrayref` gives one row as an array reference, and
  DBIx-Squirrel's runs carry rows, which are often array references,
  so `$next->arrayref` could be read as the next row. `all_arrayref`
  sits beside `all`, follows DBI's `fetchall_arrayref` and
  `selectall_arrayref`, and can't be taken for one row.
- [ ] **D2.** Does `all` keep its array reference in scalar context?
  Recommended: yes. Taking it away would change behaviour users' code
  depends on, a v0.5.0, with a task for DBIx-Squirrel, for no gain:
  `all_arrayref` is the spelling that doesn't depend on context, and
  `all`'s POD points to it.
