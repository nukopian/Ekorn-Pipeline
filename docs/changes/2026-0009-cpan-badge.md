# 2026-0009. A CPAN badge that keeps up with releases

**Status:** shipped in v0.3.1

**Decisions:** None.

**Origin:** roadmap, added 2026-11-10 as an idea, after the README's
MetaCPAN badge showed v0.1.3 on GitHub for hours after v0.2.0; Iain
had it done the same day, after DBIx-Squirrel made the same change
(DBIx-Squirrel fc2a5441d23c9a629472a6e02fe804973b9c543e)

**Started:** 2026-11-10

**Finished:** 2026-11-10

## Background

Minilla's `metacpan` badge comes from badge.fury.io. Its URL redirects,
with `no-store`, to an image served with `max-age=259200`, three days,
and GitHub's image proxy, camo, keeps its copy that long. After v0.2.0,
GitHub showed v0.1.3 on `develop` and `main` until camo's copy was
purged by hand. shields.io's `https://img.shields.io/cpan/v/Ekorn-Pipeline`
is served with `max-age=300`, five minutes.

## The plan

**What:** write a shields.io CPAN badge in `README.pod`, beside the
Kwalitee badge, and keep only the CI badge in `minil.toml`'s `badges`,
with a comment saying why, as DBIx-Squirrel did. **Done when:**
`README.md`, as `minil build` writes it, has the CI badge, then the
CPAN and Kwalitee badges, and the CPAN badge shows the current version.

## What happened

- **Outcome:** done as planned. `minil build` writes the CI badge on
  its own line, still for `branch=main`, and the CPAN and Kwalitee
  badges on the next. The shields.io badge shows v0.2.0. It reaches
  `main`, and so GitHub's front page, with the next release.
