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

**Done when:** v0.1.0 is on CPAN, indexed, and MetaCPAN shows it (step
7 of "Making a release"). Then hand DBIx-Squirrel a task saying so,
in its `TODO.md` on `develop`, as the next task says.

## 2. Hand tasks to DBIx-Squirrel through its TODO.md

**From:** DBIx-Squirrel's session, 2026-11-07 (DBIx-Squirrel-2
8068670dc395157a12af93bb447ab4b9671abe11, on `develop`)
**Waiting on:** nothing

**What:** CLAUDE.md's "Ekorn-Pipeline and DBIx-Squirrel" says a fix to
code both have is noted in the other's `TODO.md` "from a session opened
in that repository", and that Claude doesn't edit DBIx-Squirrel from
here. Iain decided otherwise on 2026-11-07: the two hand each other
tasks as grammar and scalar do. A session here commits a task straight
into `~/Git/github.com/nukopian/DBIx-Squirrel-2`'s `TODO.md` on its
`develop`, as `docs: a task from Ekorn-Pipeline: ...`, with **From:**
and **Waiting on:** lines above it, committing only that file, by its
path, so nothing of a session working there goes with it. It's the only
other repository this one touches. Change the rule to say so, as
DBIx-Squirrel-2's CLAUDE.md now does under "Planned work".

**Why:** a task written in the other repository is where its session
will find it at the start, and Iain reviews it like any other change.

**Done when:** CLAUDE.md says so, and the old wording is gone.
