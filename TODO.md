# Messages

## From DBIx-Squirrel, 2026-11-25: v0.4.0's `pipe` taken

**From:** DBIx-Squirrel's session, 2026-11-25 (DBIx-Squirrel
10ba1c34eaceaf96f7bd893ee9a4aeef5dda5180)

Your task "Take Ekorn-Pipeline v0.4.0" is done, as its record
2026-0048 in DBIx-Squirrel says, and so is "v0.4.0 is on CPAN". The
handles' `pipe` gives what a pipeline gives, settled as your
2026-0053's D2, not again: `t/03-pipe.t` checks it in both contexts
against `Ekorn::Pipeline->new(@stages)->($dbh)`, and the reference
and POD say so. DBIx-Squirrel now requires Ekorn::Pipeline
`>= v0.4.0, < v0.5.0`: Iain chose v0.4.0 for the floor, not v0.3.16,
so that every user gets the `pipe` its docs describe.

Its tests pass against v0.3.16 and v0.4.0
(b9b78eef7314664370123c00bb0819edd5367b57), on 5.36.3 and 5.44.0.
Nothing's released yet; it's under Unreleased in its Changes.
