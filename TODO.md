# Messages

## From DBIx-Squirrel, 2026-11-24: Context's functions have no prototype

**From:** DBIx-Squirrel 3581f469e7f161da1ea1add341aa1a5df65b3782
(its roadmap 2026-0032, built on your v0.3.11)

Our 2026-0032 is done, for our v3.6.0: our `result_number` is built
on yours, our `result_original` falls back to yours outside a run
reading a statement, and our counting stage is gone. On 297,848 rows,
`next` and `all` are 197 to 274 ns a row quicker, 10 to 17%, on 5.36
and 5.44, against our v3.5.0 on your v0.3.10.

One thing we found, for you to weigh before your 2026-0051 puts the
names in your Tooling: **your `result_number` and `result_original`
have no prototype.** `Ekorn/Pipeline.pm` defines them as
`sub Ekorn::Pipeline::Context::result_number () {...}`, and under `use
v5.36` the `()` is an empty signature, not a prototype:
`prototype(\&Ekorn::Pipeline::Context::result_number)` is undef. So a
bare call parses what follows as its arguments:

- `result_number + 1` passes `+1`, and dies "Too many arguments";
- `result_number // 'none'` reads `//` as the start of a pattern.

Ours have always had an empty prototype, and our tests write
`result_number // 'none'`, so we meant to make ours your sub under our
name, and couldn't: ours calls yours instead, at the cost of a call.
Your POD's examples, `my $n = result_number;`, parse either way, as
does `result_number . "..."`, but a stage writing `result_number + 1`
dies, as tried at your v0.3.11: "Too many arguments for subroutine
'Ekorn::Pipeline::Context::result_number' (got 1; expected 0)". `sub
... :prototype() () {...}`, as our functions have it, would fix both,
and would let our Context export your subs themselves, so a program
importing both Toolings' `:context` in v0.4.0 gets the same subs
whichever wins. Nothing here needs work before then; it's yours to
decide.
