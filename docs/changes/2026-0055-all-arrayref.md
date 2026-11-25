# 2026-0055. An iterator's all_arrayref

**Status:** in progress

**Decisions:** D1 settled: `all_arrayref`, the name. D2 settled: `all`
stays as it is.

**Origin:** roadmap, added 2026-11-25

**Started:** 2026-11-25

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
- [x] **D2.** Does `all` keep its array reference in scalar context?
  Yes, as Iain decided on 2026-11-25. Taking it away would change
  behaviour users' code depends on, a v0.5.0, with a task for
  DBIx-Squirrel, for no gain: `all_arrayref` is the spelling that
  doesn't depend on context, and `all`'s POD points to it.

## The plan

**What:** a method, `all_arrayref`, on Ekorn::Pipeline::Iterator,
returning every value still to come as an array reference, in any
context, reading the run to its end as `all` does.

**Why:** `all` gives a reference only in scalar context, so a caller
who wants one in a hash constructor, an argument list or a sub's
return has to write `scalar`, or gets a flattened list without a
word (Background).

**Steps:**

1. `lib/Ekorn/Pipeline/Iterator.pm`: `sub all_arrayref ($self) {
   return scalar $self->all }`, after `all`, so it keeps `all`'s
   taking at once of values already waiting at the end of the stages;
   in the POD, a `=head2 all_arrayref` after `all`, `all`'s entry
   pointing to it, and a line in the SYNOPSIS.
2. Tests in `t/15-proofs.t`, beside `all`'s: in list context, in a
   hash constructor and as an argument, it gives one reference; with
   no values, an empty array reference, not an empty list; with
   values already waiting, from a sink of many, the same values as
   `all`; after it, the iterator's `ended` is `done`, and it's spent.
3. `lib/Ekorn/Pipeline/Operators.pm`: `drain` calls `all_arrayref`
   in place of `scalar ...->all`.
4. `docs/REFERENCE.md`, under Iterators: `all_arrayref` beside `all`,
   with an example building a hash; `scripts/manuals` run, and
   `xt/manuals.t` passing.
5. `Changes`, under Unreleased: a precis naming roadmap 2026-0055,
   and the entry; the item leaves `ROADMAP.md` in the same commit.
6. A message for DBIx-Squirrel, in its `TODO.md`, once it's
   committed: the method, why it's named so, and that its own
   iterator, which wraps a run, needs its own to match.

**Done when:** the method, its tests and its POD are in; the
reference and `Changes` say so; `yath test` passes on 5.36 and 5.44,
coverage stays above its floors, perlcritic and perltidy are clean;
and DBIx-Squirrel has the message.
