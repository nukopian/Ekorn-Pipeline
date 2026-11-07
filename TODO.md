# Messages

## From DBIx-Squirrel, 2026-11-07: its own export lists, and a version range

**From:** DBIx-Squirrel-2 69a69be7bdea0ef0c42f963b91ca6aeaab827746, on its
branch `ekorn-pipeline`

Two changes to how DBIx::Squirrel depends on Ekorn::Pipeline, both
Iain's decisions of 2026-11-07:

- **The facade no longer copies the export lists.** DBIx::Squirrel's
  Stop, Gather and Stages::Flow, Batch and Taps each list the names
  their POD documents, the same as today's, and import them from here
  by name (DBIx-Squirrel-2 0c2d4fef002232f194093821c6979b8adf6b3250).
  A stage added here no longer appears there by itself; it's added to
  DBIx::Squirrel's list when wanted. A name DBIx::Squirrel lists that
  stops being exported here makes its module fail to load. Task 1's
  bullet on the export lists, which says the facade copies them, is
  out of date in that respect: what DBIx::Squirrel needs kept is
  `Stop`, `gather`, `take`, `drop`, `take_while`, `drop_while`,
  `batch`, `collect`, `peek`, `count_into` and `dump_to`.
- **DBIx::Squirrel requires `>= v0.1.0, < v0.2.0`.** The facade keeps
  names, not behaviour, and users' own stages depend on behaviour:
  when a `gather` stage is made, what a stop does, the order end
  functions run in, where errors are reported. So a release that
  changes any of those, or drops or renames a public name, is v0.2.0,
  not v0.1.x, and comes with a task handed to DBIx-Squirrel, which
  tests it and moves the range. A v0.1.x reaches DBIx::Squirrel's
  users with no release of DBIx::Squirrel's, so it should only fix,
  or add.

# Planned work

## 1. Release v0.1.0 by 2026-11-09, with the names DBIx::Squirrel needs

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
   - the export lists of Stop, Gather and Stages::Flow, Batch and
     Taps, which DBIx::Squirrel's facade copies when it's loaded, so a
     stage added here appears there too;
   - the messages of the errors DBIx::Squirrel's tests check, such as
     `Expected stage #%d to be a code reference` and
     `Pipeline stage #%d failed at ...`.

   DBIx::Squirrel runs on all of these as they are, unchanged since
   0b45ac977eac8dba7d59562267e04d4895f1037d, with every test and CI job
   passing (its message of 2026-11-07, from DBIx-Squirrel-2
   82f7695f3d20cd0467a5524d52924195c6d3c5b0). Changing one means
   handing DBIx-Squirrel a task.
2. Upload a trial, as "A trial release" in docs/MAINTAINING.md says,
   and read its reports.
3. Release v0.1.0 properly, not as a trial, as "Making a release"
   says.

**Why:** CPAN Testers install a distribution's dependencies from the
CPAN index, which doesn't hold trials, so a DBIx::Squirrel trial that
needed an Ekorn::Pipeline trial would mostly report a missing
prerequisite, not test anything. A 0.x version already says the
interface may still change.

**Done when:** the trial's reports are read and Iain decides v0.1.0 is
ready. The commit that removes this task, and so this file, starts
release day, as `main` can't take `TODO.md`. "Making a release" then
ends, at its step 8, by handing DBIx-Squirrel a task saying v0.1.0 is
on CPAN.

