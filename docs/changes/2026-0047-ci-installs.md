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

- **First run, making the caches,** on
  b44a1183ab8de8f30b15f063b682b64eb4d32e1b, 2026-11-16, run
  43907401403. The test jobs on Linux and macOS, installing far less,
  were already fast: 48 s to 1m 2s on Ubuntu, with 29 to 52 s in
  setup-perl's step, and 1m 1s on macOS, with 48 s. `style` (2m 55s)
  and `coverage` (4m 24s), installing the develop modules into empty
  caches, took as long as before.
- **Windows 5.44 failed,** and is back as it was. `t/23-tooling.t` and
  `t/24-json.t` died before any output, with exit status 5. Before, the
  job took JSON::MaybeXS and Cpanel::JSON::XS from those the runner's
  Perl came with; setup-perl's cpanm uses `--local-lib-contained`,
  which ignores them, so it built Cpanel::JSON::XS 4.82 into `local/`,
  and loading it, by JSON::MaybeXS, seems to be what killed the tests,
  as only those two load it. Windows 5.36 passed the same way. So the
  Windows jobs install with cpanm onto the runner's Perl, uncached, as
  before; they took a minute or two anyway. What it suggests for users
  who install Cpanel::JSON::XS afresh on Windows and Perl 5.44 isn't
  settled here: it's for Iain to decide whether it's looked into.
