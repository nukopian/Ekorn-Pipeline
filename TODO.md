# Planned work

## A run's set-up costs 13 to 18 µs before a value moves

**From:** DBIx-Squirrel's session, 2026-11-15 (DBIx-Squirrel
725e62332f67d0943199d8c7829b7e838b68cf89, its roadmap 2026-0028, whose
record, `docs/changes/2026-0028-handles-gains.md`, has the
measurements in full)
**Waiting on:** nothing; DBIx-Squirrel's v3.0.3 would like what comes
of it, but doesn't wait for it

DBIx-Squirrel's 2026-0028 profiles the handles for v3.0.3, and leads
the optimisation for both repositories, as its D4 says: what's found to
be Ekorn's comes here as a task, and Ekorn's session makes the change.

**What was found.** A DBIx::Squirrel iterator reading one row by
primary key costs 43 to 50 µs more than an `execute` and a fetch on
the same handle, on SQLite, PostgreSQL and MySQL alike. About 27 µs of
that is Ekorn's run, from `iterator` to `finish`. With no stages, on
Ekorn v0.3.2 (6e86271), per call, the best of five runs:

| | Perl 5.36.3 | Perl 5.44.0 |
|---|---|---|
| `Ekorn::Pipeline->new` | 1.2 µs | 1.1 µs |
| `$p->iterator($source)`, a `source { ... }` of one value, let go | 17.5 µs | 16.0 µs |
| the same, read with `all` | 20.0 µs | 18.3 µs |
| `$p->iterator($code)`, a code reference, let go | 14.7 µs | 13.3 µs |
| `_source_run`, `_make_run` (no stages), `_end_all` (one end) | 1.9, 0.3, 0.6 µs | 1.8, 0.3, 0.6 µs |
| a model: 12 closures over 20 lexicals | 4.8 µs | 4.6 µs |
| `try {} catch {}` around nothing | 0.1 µs | |

**Where NYTProf puts it,** by line, in `lib/Ekorn/Pipeline.pm`, for
`$p->iterator($code)` let go:

- **Making `_iterator`'s closures,** about a third: `$next` (ending at
  :785) the largest, then `$finish` (:611), `$end_run` (:812), `$all`
  (:800), the smaller ones (:525, :576, :582, :618, :623, :634, :643),
  and the call making the `Ekorn::Pipeline::Iterator` with two more
  (:813 to :822, 11.5% alone).
- **Leaving scopes,** about as much again: the `return`s of `$finish`
  (:610, 6.1%), `$end_run` (:811, 4.8%), `_end_all` (:423, 4.7%) and
  `_make_run` (:503, 4.4%), and the call at :268.
- `_is_source`'s `blessed` and `can` (:61, :302), about 11% together.

**What might be done,** for this session to judge, each kept only if
it measures as a gain: closures that capture fewer variables, or
fewer closures, such as the run's state in one structure the
iterator's methods share; a run with no stages, flushes or ends of
its stages taking a shorter way, which is DBIx::Squirrel's commonest
case; and `_end_all` skipping its loop and `try` when there's only
the source's end, or none.

**How to check it.** Time `$p->iterator($code)` let go, and
`$p->iterator(source { ... })->all`, with no stages, before and after,
on 5.36 and 5.44, as the table above does. Done when they're faster
beyond the noise between runs, Ekorn's tests pass, and DBIx-Squirrel's
tests pass against this working copy; or when this session finds
nothing worth changing, and says why in a message to DBIx-Squirrel.
