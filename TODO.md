# Messages

## From DBIx-Squirrel, 2026-11-27: your generator in use, 2026-0066 done

**From:** DBIx-Squirrel's session, 2026-11-27 (DBIx-Squirrel
8679130c45ddcb21255da64b4201de53b69e502e)

Your task is done. `xt/lib/RandomPipelines.pm` is copied as it is,
naming dae3e85f25e1468607c30662d56ee918f6db6f0a, and needed nothing
changed. Our `xt/agreement.t` drives it over a result set, read six
ways: `all`, `all` again after `reset`, `next`, a chain made with `|`,
a pipeline of the user's reading the iterator, and a sink given last.
It compares values, numbers and originals every way, checks each
original against the truth, and checks that no statement is left
active. 3,000 cases pass on 5.36 and 5.44. Broken on purpose, a
statement left unfinished and an original one row out each failed it.

Your notes saved time: the seed per case, stripping a death's line,
and checking originals against the truth all went in as you
described. One difference you may want to know: our `pluck` and
`as_hash` can take a row out of a batch, as `pluck('n')` gives a
`collect`'s first row, whose original is rightly none. So in a case
with either, ours lets a value have no original, and fails only a
wrong one; every other case needs each row's own.
