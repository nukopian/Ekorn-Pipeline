# 2026-0047. CI installs only what each job needs, and caches it

**Status:** in progress

**Decisions:** None.

**Origin:** roadmap, added 2026-11-16, after v0.3.5's release waited
on the macOS job

**Started:** 2026-11-16, on `develop` at
40e02b783bd3531981620369686f177ab85c425a

## Background

Every job but `secrets` ran `cpanm --notest --installdeps
--with-develop --with-recommends .`, or, on Windows, without
`--with-develop`, from scratch, with nothing cached. `--with-develop`
brings every maintainer's tool in the `cpanfile`: Minilla, with Moo
among its dependencies, Perl::Critic, Devel::Cover, Devel::NYTProf,
CPAN::Uploader and the rest. Of those, the test jobs use only yath.

The five runs on `develop` before the change, 2026-11-16, from
417b4a8 to dca3d1d, as GitHub timed each job and its dependencies
step, not counting the time a job waited for a runner:

| Job | Whole job | Dependencies |
|---|---|---|
| perl 5.36 to 5.44 (ubuntu-24.04) | 2m 30s to 4m 6s | 139 to 232 s |
| perl 5.44 (macos-26) | 6m 23s to 7m 52s | 357 to 449 s |
| perl 5.36 (windows-2025) | 1m 24s to 2m 6s | 64 to 100 s |
| perl 5.44 (windows-2025) | 1m 3s to 1m 16s | 39 to 49 s |
| style | 2m 43s to 3m 49s | 140 to 202 s |
| coverage | 3m 21s to 4m 12s | 164 to 205 s |

So installing is most of every job, and on macOS about 90% of it.

## Decisions

None: the item's What settled the approach when Iain put it in Next,
and the choices below are how it's done.

## The plan

**What:** each job's modules are installed by actions-setup-perl,
already pinned in the workflow, with its `install-modules-with: cpanm`,
into `local/`, which it caches itself. Its cache key is the Perl's
`perl -V` digest, the installer, the `cpanfile`'s hash and the modules
named in `install-modules`, but not `install-modules-args`; it restores
an older cache for the same Perl if there's no exact match, and
`cpanm --installdeps` then installs only what's missing.

- The test jobs on Linux and macOS install the runtime, test and
  recommended modules, and name `Test2::Harness` and `UUID`, the
  develop modules they use; naming them also keeps their cache apart
  from those of `style` and `coverage`, on the same Perls.
- The Windows jobs install the runtime, test and recommended modules,
  as before.
- `style` and `coverage` keep `--with-develop`.
- `docs/MAINTAINING.md` says how to delete the caches, to test against
  the newest modules, as a cache keeps the versions it was made with
  until the `cpanfile` changes.

**Why:** to cut each job's time, and above all the macOS job's, which
holds up every release.

**Done when:** CI runs the same jobs, with the same names, so `main`'s
required checks are unchanged, and they pass; a run with an unchanged
`cpanfile`, after the caches are made, is measurably faster, the macOS
job most of all; the timings of a first run, making the caches, and a
second, using them, are here. If it works better, the same change goes
to Text-Redact-Secrets and DBIx-Squirrel as a task in each one's
`TODO.md`, with what was measured.

## What happened
