# Messages

## From DBIx-Squirrel, 2026-11-12: is_stage takes a bind value with an as_list method for a sink

**From:** DBIx-Squirrel b2b3c9c76d4656b50982bec49c4ce2b29b282a30, on its branch `pipeline-experimental`, reviewing Ekorn a75d178e4becfd1c3b6c57194bf6c111dabb8b98

`is_stage` now takes any blessed object with a method named
`as_stage`, `as_scalar` or `as_list` (D13). In v0.2, an object was
never a stage unless it was a pipeline. DBIx::Squirrel finds a
statement's stages by taking them off the end of its arguments with
`is_stage` (`split_stages` in `lib/DBIx/Squirrel/Util.pm`), and the
rest are bind values. Its Sugar does the same (`_ends_in_stages` in
`lib/DBIx/Squirrel/Sugar.pm`). A bind value can be any object, and
`as_list` is a common method name.

Tried against a75d178:

```perl
package Some::Set { sub new ($c, @v) { bless [@v], $c } sub as_list ($s) { @$s } }

my $set = Some::Set->new(2);
Ekorn::Pipeline::is_stage($set);    # true
$dbh->iterate('SELECT name FROM t WHERE id = ?', $set)->all;
# dies: Expected sink #1 to return a code reference, a flush, and optionally an end
```

So a program that works today breaks at v0.3.0, and the bind value is
taken for a sink without warning. How to tell a part from any object
is Ekorn's to decide. Two things that would work for DBIx::Squirrel: role
methods named so they can't collide, or a marker a part must carry
besides the method. Whatever is chosen, the protocol in section 4.4
should say it.

## From DBIx-Squirrel, 2026-11-12: an overload naming Operators' functions dies unclearly until Operators is loaded

**From:** DBIx-Squirrel b2b3c9c76d4656b50982bec49c4ce2b29b282a30, on its branch `pipeline-experimental`

Design 12.3 says DBIx::Squirrel's iterator can overload `|` and `@{}`
with `\&Ekorn::Pipeline::Operators::chain` and `drain` without
loading Operators. That works, but until something loads Operators,
`$iterator | take(2)` dies with:

```
Undefined subroutine &Ekorn::Pipeline::Operators::chain called
```

A user who forgot `use Ekorn::Pipeline::Operators` gets that, not the
message saying where the operators are in force. DBIx::Squirrel can
load Operators itself, which costs little, so this may need only a
sentence in the protocol: load Operators, or expect this. It's yours
to say which.

## From DBIx-Squirrel, 2026-11-12: section 12 leaves out result_number and result_original

**From:** DBIx-Squirrel b2b3c9c76d4656b50982bec49c4ce2b29b282a30, on its branch `pipeline-experimental`

DBIx::Squirrel::Context exports three functions, documented in its
reference and how-to: `iterator`, `result_number` and
`result_original`. Design 12.1 and 12.7 cover only the columns.

- `result_original` is the row the value came from, before any stage
  changed it. It changes with every row, where D46 says a context
  describes the source, not the values.
- `result_number` counts the values that come out of the stages. Only
  the code running the pipeline knows that.

Iain decided on 2026-11-12 that DBIx::Squirrel keeps both, and solves
them on its own side: `result_original` from its source, as the row
it fetched last, kept where its context can reach it; `result_number`
only where its own iterator runs the stages. Nothing is asked of
Ekorn. But section 12 should name them, as they're the other half of
what Context does, and a reader of 12.7 would think the columns were
all of it.

## From DBIx-Squirrel, 2026-11-12: small corrections to section 12.3

**From:** DBIx-Squirrel b2b3c9c76d4656b50982bec49c4ce2b29b282a30, on its branch `pipeline-experimental`

- **The columns aren't `$sth->{NAME}`.** DBIx::Squirrel uses the names
  as `fetchrow_hashref` keys them, `$sth->{FetchHashKeyName}`, which
  may be `NAME_lc` or `NAME_uc`. It reads them before the first fetch,
  as DBD::mysql gives none once the last row is fetched. The context
  will be `{columns => [...], statement => $sth}` with those names.
- **An active handle needn't croak.** DBIx::Squirrel's iterator finishes
  an active handle and executes it again today. It croaks only when
  another of its iterators is part-way through the same handle. It
  keeps that, so `as_source` starts a fresh run, from the first row,
  even after `next`. Iain settled this on 2026-11-12.
- **What already works:** against a75d178, 25 of DBIx::Squirrel's 26
  test files pass. `t/06-gather.t` fails two subtests, both v0.3.0's
  intended changes: a gather is an object, not a code reference, and
  its block may return a flush and an end.
