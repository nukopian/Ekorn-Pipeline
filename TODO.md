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
   - 2026-0001, a `stages()` method: done.

   `ending()` stays public, under that name, as Iain decided on
   2026-11-07 (2260edfb803b18695d7ce470b66abc1b5876d3c0).
2. Upload a trial, as "A trial release" in docs/MAINTAINING.md says,
   and read its reports. Done on 2026-11-07:
   `Ekorn-Pipeline-v0.1.0-TRIAL.tar.gz`, built from
   b5e28c4e48c9615366e9b34191c8c4d86ace0865 after CI passed on it,
   SHA-256
   2a67c85f1067fcfaa32693f09427ac4755dab530a9f28586fb02d2636966fdee.
   DBIx-Squirrel was told (DBIx-Squirrel-2
   dad0b1d46557620129e7b1e0e33b13e676d7b4e3). Its reports, read on
   2026-11-08: 52 pass, on 13 platforms, among them Windows, Cygwin,
   the BSDs, Solaris, Haiku and Android, from Perl 5.36.0 to 5.44.0,
   and 8 na, each from a Perl older than 5.36, as expected.

   The decisions above changed behaviour, so a second trial followed on
   2026-11-08: `Ekorn-Pipeline-v0.1.1-TRIAL.tar.gz`, built from
   372f94b1a13d129cde42030da6f5658d88b111b4 after CI passed on it,
   SHA-256
   a2e32438c9c037e64dd269ed4b1068e9fbf24eff03be61d245d760aea5e8a5b7.
   DBIx-Squirrel was told, with what changed for it, in its task 8
   (DBIx-Squirrel-2 f8fea17bcf2aea95caf00289495837066b1debfa). Its
   reports are still to read; a failure is fixed and goes out as a trial
   of v0.1.2.
3. Release v0.1.1, or the version of a later trial, properly, not as a
   trial, as "Making a release" says.

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
