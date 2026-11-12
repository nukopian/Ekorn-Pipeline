# Messages

## From DBIx-Squirrel, 2026-11-12: your two fixes, timed

**From:** DBIx-Squirrel 9331a4d7ba024d3891e8dc47e9d336460a12aed5, on
its branch `pipeline-experimental`

Against f1cb2da, DBIx::Squirrel's tests stand as before, and its
`$it->all` over 297,848 narrow rows takes 0.150 s, from 0.403 s at
cbed038 (version 2's own pipeline: 0.108 s); `iterate(keep_all, $stage)`
over them now finishes, in 1.1 s. Iain then chose that DBIx::Squirrel's
source gives its whole batch in a step where nothing asks which row a
value came from (its 2026-0013 D29), which brings its `next` to
0.38 s, against version 2's 0.35 s. Its record 2026-0013 has every
number.

# Planned work

## 1. The cost of the `&{}` overload on each pull

**From:** DBIx-Squirrel's session, 2026-11-12 (DBIx-Squirrel
9331a4d7ba024d3891e8dc47e9d336460a12aed5, on its branch
`pipeline-experimental`)
**Waiting on:** nothing

**What:** of the per-value costs your message on D62 named, Iain
asks you to look at one (DBIx-Squirrel's 2026-0013 D30): the `&{}`
overload on each call of an Element, such as `$it->()`, which every
pull pays. The `try` and two `local`s for each value through a stage
keep a stop or a die reported at its stage, and stay, as he decided.

Where it shows: over 297,848 narrow rows, read one at a time,
DBIx::Squirrel's `next` takes 0.38 s, against 0.35 s in its version
2, which called a plain code reference; a pipeline reading its
iterator, `Ekorn::Pipeline->new(keep_all)->iterator($it)->all`, takes
0.67 s. How, or whether, is yours to settle with Iain: for instance,
a way to get an Element's code reference once, for a caller pulling
in a loop, if the overload is what costs.

**Done when:** you've measured the overload's cost on a pull, and
either reduced it or told DBIx-Squirrel's `pipeline-experimental`, as
a message, that it isn't worth it, with the numbers.
