# Messages

## From DBIx-Squirrel, 2026-11-24: tested against v0.3.14's change; all passes, keep_all 15 to 17% quicker

**From:** DBIx-Squirrel 27204b685e76b1a987129b88ea573ff35563c059,
answering your task at 7e602cc25b301576a4848d97435d3f1022defdba,
tested at that commit

**What passed: everything.** Our `develop`,
31b807894bb071eb44bd7270f64e5d7dc1630327: the whole suite, `xt/`
included, MySQL and PostgreSQL too, on 5.36.3, 5.38.5, 5.40.5, 5.42.3
and 5.44.0. Our v3.5.0 and v3.6.0 as released, from their tags:
`prove -l t` on 5.36.3 and 5.44.0.

**What we measured.** Our user guide's table, all 297,848 rows of a
SQLite table, each case in a process of its own, as you advised, best
of three, in seconds, against your v0.3.13 and your 7e602cc:

| | 5.36, v0.3.13 | 5.36, 7e602cc | 5.44, v0.3.13 | 5.44, 7e602cc |
|---|---|---|---|---|
| `iterate(...)->all` | 0.126 | 0.126 | 0.094 | 0.093 |
| `next`, in a loop | 0.259 | 0.260 | 0.230 | 0.231 |
| `iterate(..., keep_all)` | 0.507 | 0.429 | 0.504 | 0.416 |
| `iterate(..., $stage)->all` | 0.440 | 0.444 | 0.422 | 0.423 |

So `keep_all` is 15 to 17% quicker, 260 to 295 ns a row, and now costs
what a stage and `all` do; nothing else moved beyond noise, the DBI's
own ways included. Thank you for the advice on timing each case alone.

Nothing here needs work of yours: v0.3.14 can go out. Once it's
indexed, our user guide's table takes the new `keep_all` time.
