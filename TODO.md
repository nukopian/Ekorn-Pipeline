# Messages

## From DBIx-Squirrel, 2026-11-07: it runs on Ekorn::Pipeline, behind a facade

**From:** DBIx-Squirrel's session (DBIx-Squirrel-2
82f7695f3d20cd0467a5524d52924195c6d3c5b0, on its branch `ekorn-pipeline`)

DBIx::Squirrel now runs on Ekorn::Pipeline, installed from this
repository's `develop` on GitHub, and every test and CI job of its
passes on it. Its Pipeline, Stop, Gather, Pipes and Stages::Flow, Batch
and Taps stay, as Iain decided, as a permanent facade: subclasses of
Ekorn's modules, or exporting what they export, copied from their
`@EXPORT`, `@EXPORT_OK` and `%EXPORT_TAGS` when loaded, so a stage added
here appears there too. Its tests still test the pipeline through
DBIx::Squirrel's names, so a change here that its users would notice
fails there.

What it depends on, so worth keeping as they are, or changing only with
a task handed to DBIx-Squirrel:

- `Ekorn::Pipeline::ending()`, called by DBIx::Squirrel::Context;
- `@Ekorn::Pipeline::Errors::INTERNAL`, which its own `@INTERNAL`
  includes, so errors raised here are reported at its user's line;
- the class names `Ekorn::Pipeline::Stop` and `Ekorn::Pipeline::Gather`:
  its docs now tell a stage that catches errors to throw a stop on with
  `die $e if $e isa 'Ekorn::Pipeline::Stop';`;
- the export lists of Stop, Gather and the three stage modules, and the
  messages of the errors its tests check, such as
  `Expected stage #%d to be a code reference` and
  `Pipeline stage #%d failed at ...`.

Also: `TODO.md` now has this `# Messages` section, above
`# Planned work`, for news between the two sessions that needs no work
of its own. The task below records that here.

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
     in `die $e if $e isa 'Ekorn::Pipeline::Stop';`.
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

## 2. Record the Messages section in CLAUDE.md

**From:** DBIx-Squirrel's session, 2026-11-07 (DBIx-Squirrel-2
c9db87bbc20f794e775ad1779110d1c349145ef0, on `develop`)
**Waiting on:** nothing

**What:** Iain decided on 2026-11-07 that `TODO.md` has a `# Messages`
section, above `# Planned work`, for news between the two sessions. A
message is what one side has decided or done, or a change in plan, and
needs no work of its own; one that asks for work is a task instead.
Each is a `##` heading saying who it's from, the date and what it's
about, with a **From:** line, sent as `docs: a message from
Ekorn-Pipeline: ...`, committing only that file. Messages are read at
the start of a session, with the tasks, and the session they're for
removes each once read, in a commit saying what came of it, and the
heading with the last one. Add this to CLAUDE.md's rules for handing
tasks to DBIx-Squirrel, as DBIx-Squirrel-2's CLAUDE.md has it under
"Planned work".

**Why:** news and tasks look alike in one list; apart, a session can
tell what it must do from what it should know.

**Done when:** CLAUDE.md has the rule.
