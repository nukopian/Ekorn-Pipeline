# Docs and builds

Part of the working rules in [CLAUDE.md](../../CLAUDE.md), kept here
as only some tasks need them: building and releasing the distribution, the manuals made from `docs/`, and checking the docs' examples.

## Minilla and the manuals

- **Minilla** builds and releases the distribution. It's opinionated,
  and that's why it was chosen over Dist::Zilla, whose configuration is
  a tax on an occasional release: the repository is the distribution,
  with the `Build.PL` and `META.json` it generates committed and a
  `cpanfile` listing the dependencies, so CI and `cpanm` from GitHub
  need nothing else. Follow its conventions rather than work around
  them. Three settings in `minil.toml` part from its defaults, as
  DBIx-Squirrel's do:
  - **The README is written by hand in `README.pod`.** Minilla always
    writes `README.md` from POD, so it's generated from that file, not
    from the main module. Edit `README.pod`, never `README.md`.
  - **`Changes` keeps its "Unreleased" heading** (`manage_changes =
    false`), edited by hand at a release, rather than `{{$NEXT}}`.
  - **The git steps of a release are ours.** `minil release` makes its
    own commit and an unsigned tag, and pushes both, so releases don't
    use it: `minil prepare VERSION` sets the version, we commit, move
    `main` and sign the tag, `minil dist --skip-prepare` builds the
    tarball, and `cpan-upload` uploads it.
- **The manuals are made from `docs/`.** `scripts/manuals` makes
  `lib/Ekorn/Pipeline/Manual/Reference.pod` and `HowTo.pod` from
  `docs/REFERENCE.md` and `docs/HOWTO.md`, so MetaCPAN lists the
  reference and the how-to, as DBIx-Squirrel does (change record
  2026-0005). Edit the Markdown and run the script, as with the README,
  never the POD; `xt/manuals.t` fails if they differ. A change to the
  script that would suit DBIx-Squirrel's copy goes to it as a message,
  so the two stay alike.
## Checking the docs' examples

- **The how-to's examples are checked by `xt/howto.t`,** as Iain
  decided on 2026-11-13: it runs them as one program, the first setting
  up their data and each after it in a block of its own, and checks
  each prints what its comments say, a comment at the end of a line
  that prints, or comment lines straight after it, or after the end of
  a block that prints, with `...` for any text. So write a how-to
  example's comments as exactly what it prints. One that can't be run
  so, such as one printing a test's output, is marked
  `<!-- not run -->` on the line before it, and checked by hand. The
  test is DBIx-Squirrel's, as it is but for its notes, so a change to
  it that would suit DBIx-Squirrel's goes to it as a message.
- **The reference's and the README's examples are checked by
  `xt/examples.t`,** from 2026-11-25 (roadmap 2026-0053's F15). Each
  of the reference's, before its index, runs on its own after the
  reference's catalogue of tracks, in a folder with the files its
  examples read, and must print what its comments say, as the how-to's
  do; so write its comments the same way. One that can't run so, such
  as one that croaks on purpose or uses a stand-in, is marked
  `<!-- not run -->`, and checked by hand. The README's use stand-ins,
  such as `users()`, so each is only compiled; a block that isn't Perl
  is marked `=for not-run`. The helpers both tests use, and
  `xt/howto.t`, are in `xt/lib/Examples.pm`.
- **`xt/agreement.t` runs random pipelines** pushed, pulled, read with
  `all` and fed, from a fixed seed, and fails if any way gives other
  values. `EKORN_AGREEMENT_SEED` and `EKORN_AGREEMENT_CASES` run it
  with another seed, or more cases.
- Users installing from CPAN run the tests with whatever harness their
  installer uses, so they must pass under `prove` too. yath is the
  maintainers' choice, not a requirement.
