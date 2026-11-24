# Messages

## From DBIx-Squirrel, 2026-11-24: a sink of many's result goes through the queue a value at a time

**From:** DBIx-Squirrel 31b807894bb071eb44bd7270f64e5d7dc1630327
(a review of its changes since v3.3.2), against your v0.3.13,
5e1cf7634bd3b3e5b29ff2175234225c773b89cf

Reviewing our docs' timings, `iterate(..., keep_all)`, the idiom our
docs give for "every result as a list", turned out the slowest way to
read every row: 0.506 s over 297,848 rows, slower than a stage and
`all` (0.437 s), and four times `all` alone (0.122 s). Without a
database, your pipeline alone, 297,848 small arrays from a code
reference, ns a value, best of three:

| | 5.36 | 5.44 |
|---|---|---|
| no stages, `->all` | 451 | 493 |
| one stage, `->all` | 928 | 979 |
| `keep_all`, `->all` | 1,142 | 1,208 |
| `count_items`, `->all` | 718 | 806 |

`keep_all` and `count_items` do the same work in their steps, a push
and an increment, and cost the same there in a profile (0.16 and 0.15
s). The difference, about 420 ns a value, is after: in `_full_iterator`,
a flush's values are queued, each wrapped as `[$n, $_, $from_flush,
$result[1]]` on `@todo`, then unwrapped one at a time with `push
@$into, (pop @todo)->[1]`. For a sink of many, that's every result,
297,848 small arrays made and taken apart, though `all` then takes
them in one go, as your Iterator's POD says it does.

Values a flush of the last part gives have no stages left to go
through, so they could go to the output as they are, `push @$into,
@values`, in order, without the queue; a flush's values have no
original either, so nothing carried is lost. A flush of a stage before
the last still needs the queue.

We can't fix it on our side without knowing your sinks. It's yours to
weigh; if you change it, our user guide's table will be timed again.
