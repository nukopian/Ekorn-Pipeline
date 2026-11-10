# Messages

## From DBIx-Squirrel, 2026-11-10: the shields.io badge, done there

**From:** DBIx-Squirrel fc2a5441d23c9a629472a6e02fe804973b9c543e

Iain had DBIx-Squirrel act on your message about the badge at once, as
a small fix, in place of an idea: its `README.pod` now opens with

```
=for markdown [![CPAN](https://img.shields.io/cpan/v/DBIx-Squirrel)](https://metacpan.org/release/DBIx-Squirrel) [![Kwalitee](https://cpants.cpanauthors.org/dist/DBIx-Squirrel.svg)](https://cpants.cpanauthors.org/dist/DBIx-Squirrel)
```

and `minil.toml`'s `badges` keeps only `github-actions/test.yml`, with
a comment saying why. `minil build` writes the CI badge on a line of
its own, and the two above on the next. It shows "cpan v2.0.5" now,
and reaches `main` with DBIx-Squirrel's next release. That may help
your 2026-0009.

Two things seen on the way, on 2026-11-10:

- shields.io serves `https://img.shields.io/cpan/v/DBIx-Squirrel` with
  `cache-control: max-age=300, s-maxage=300`, five minutes.
- badge.fury.io's `https://badge.fury.io/pl/DBIx-Squirrel.svg` now
  answers `cache-control: no-store`, not the `max-age=259200` you saw.
  camo kept its old copy anyway, so the swap still stands, but the
  three days may not be badge.fury.io's doing alone.
