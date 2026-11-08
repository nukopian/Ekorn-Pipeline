# Planned work

## 1. Release v0.1 by 2026-11-09, with the names DBIx::Squirrel needs

**From:** DBIx-Squirrel's session, 2026-11-07 (DBIx-Squirrel-2
8447689997ae6b1ec5f3a5c45a4fac0224391ce4, on its branch
`ekorn-pipeline`)
**Waiting on:** nothing

**What:** DBIx::Squirrel is now developed against Ekorn::Pipeline, on
DBIx-Squirrel-2's branch `ekorn-pipeline`, which installs it from this
repository's `develop` on GitHub. From 2026-11-09, DBIx::Squirrel's
next trial, v2.0.3, will require Ekorn::Pipeline from CPAN. So:

1. Before release, settle which names are public, and keep them, as
   DBIx::Squirrel will depend on them:
   - `Ekorn::Pipeline::ending()`, which DBIx::Squirrel::Context calls;
   - `croakf` and `@Ekorn::Pipeline::Errors::INTERNAL`, which
     DBIx::Squirrel::Errors and Stages::Rows will use;
   - `Ekorn::Pipeline::Pipes`, which DBIx::Squirrel's handles inherit
     from;
   - `Ekorn::Pipeline::Stop` and `Ekorn::Pipeline::Gather`, whose class
     names DBIx::Squirrel's documentation will tell users to check, as
     in `die $e if $e isa 'Ekorn::Pipeline::Stop';`;
   - the names DBIx::Squirrel's facade imports by name, as its message
     of 2026-11-07 (DBIx-Squirrel-2
     69a69be7bdea0ef0c42f963b91ca6aeaab827746) said: `Stop`, `gather`,
     `take`, `drop`, `take_while`, `drop_while`, `batch`, `collect`,
     `peek`, `count_into` and `dump_to`. A stage added here doesn't
     appear there by itself;
   - the messages of the errors DBIx::Squirrel's tests check, such as
     `Expected stage #%d to be a code reference` and
     `Pipeline stage #%d failed at ...`.

   DBIx::Squirrel runs on all of these as they are, with every test and
   CI job passing (its message of 2026-11-07, from DBIx-Squirrel-2
   82f7695f3d20cd0467a5524d52924195c6d3c5b0). Since
   0b45ac977eac8dba7d59562267e04d4895f1037d no name or message has
   changed, but two behaviours have: counts and sizes take the digits
   0-9 only (3323a7f4e4500894e846984b403126d2ad936b58), and a stop that
   isn't an array carries nothing
   (f6827617d2c2cc820e56bea07cf6534f9b728a3a). DBIx-Squirrel was told
   of both, in its tasks 3 and 5. Changing a name, a message or a
   behaviour means handing DBIx-Squirrel a task.

   What v0.1 promises waits on three roadmap items, whose open
   decisions are in their records in `docs/changes/`. Settle them with
   Iain, and do what they need before the release:
   - 2026-0002, an iterator after a stage dies: done, so the release
     is v0.1.1, after a second trial;
   - 2026-0003, a pipeline in scalar context: done;
   - 2026-0001, a `stages()` method: D1 and D2 are
     settled: it goes in v0.1.1.

   `ending()` stays public, under that name, as Iain decided on
   2026-11-07 (2260edfb803b18695d7ce470b66abc1b5876d3c0).
2. Upload a trial, as "A trial release" in docs/MAINTAINING.md says,
   and read its reports. Done on 2026-11-07:
   `Ekorn-Pipeline-v0.1.0-TRIAL.tar.gz`, built from
   b5e28c4e48c9615366e9b34191c8c4d86ace0865 after CI passed on it,
   SHA-256
   2a67c85f1067fcfaa32693f09427ac4755dab530a9f28586fb02d2636966fdee.
   DBIx-Squirrel was told (DBIx-Squirrel-2
   dad0b1d46557620129e7b1e0e33b13e676d7b4e3). Its reports are still to
   read; a failure is fixed and goes out as a trial of v0.1.1.
3. Release the version of the last trial, v0.1.0 or the v0.1.1 a
   failure or a decision makes, properly, not as a trial, as "Making a
   release" says.

If 2026-11-09 can't be met, because reports are slow, one fails, or a
decision needs a new trial, tell DBIx-Squirrel at once with a message
in its `TODO.md`, as its task 2 waits on this release.

**Why:** CPAN Testers install a distribution's dependencies from the
CPAN index, which doesn't hold trials, so a DBIx::Squirrel trial that
needed an Ekorn::Pipeline trial would mostly report a missing
prerequisite, not test anything. A 0.x version already says the
interface may still change.

**Done when:** the decisions above are settled, and what they need for
v0.1 is done, the last trial's
reports are read, and Iain decides it's ready. The commit that removes this task, and so this file, starts
release day, as `main` can't take `TODO.md`. "Making a release" then
ends, at its step 8, by handing DBIx-Squirrel a task saying which
version is on CPAN.

## 2. Find out why a push starts no CI run

**From:** Ekorn-Pipeline's session, 2026-11-07 (Ekorn-Pipeline
a36da79f6ca387514092bf7d1f0a82a6ab4bcc91)
**Waiting on:** nothing

**What:** no push to `develop` has started a run of `test.yml`, though
it has `on: push: branches: [main, develop]`, and Actions is enabled
for the repository with every action allowed. GitHub has the commits,
but makes no check suite for them: `gh api
repos/nukopian/Ekorn-Pipeline/commits/b5e28c4e48c9615366e9b34191c8c4d86ace0865/check-suites`
lists none from a push. Every run so far was started by hand, with
`gh workflow run test.yml --ref develop`. Things to look at, reading
only, as changing a GitHub setting needs Iain's go-ahead:

- the repository's Actions settings and any organisation policy over
  them (`gh api repos/nukopian/Ekorn-Pipeline/actions/permissions`);
- whether webhooks for pushes reach GitHub Actions at all, as in the
  repository's events (`gh api repos/nukopian/Ekorn-Pipeline/events`);
- what differs from DBIx-Squirrel-2, whose pushes to `develop` and
  `ekorn-pipeline` do start runs (`gh run list -R
  nukopian/DBIx-Squirrel-2`): its workflow's `on:`, its Actions
  settings, and how the repository was created and first pushed;
- GitHub's status page for Actions incidents on 2026-11-07.

**Why:** "Making a release" step 1 needs CI to have passed on the last
commit of `develop`, and a push that tests nothing lets a broken
commit look fine until someone starts a run.

**Done when:** a push to `develop` starts a run by itself, or the cause
is found and Iain has decided what to do. If it can't be solved before
the release, start a run by hand on the commit to be released, as so
far.
