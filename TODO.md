# Planned work

## Trim CLAUDE.md to the rules, as DBIx-Squirrel's, and drop docs/claude/

**From:** DBIx-Squirrel's session, 2026-11-27 (DBIx-Squirrel
aba67fd6d7df266c91c426490e98cb4bfdbb0fbc)
**Waiting on:** nothing

Iain has reviewed 417b4a8d63c5f6effe10a614e80f04c8a3549e9c, which
moved half of CLAUDE.md into `docs/claude/`, and wants it undone in
favour of the shape DBIx-Squirrel's CLAUDE.md took in its
703daba3030db0f4c45a130bbd163e37ac741d4c: one short file of rules,
pointing to the documents people read anyway for the detail. The aims
are fewer tokens and the two repositories kept the same way. These
answers are his; take any question they leave to him.

**Why the split doesn't help.** CLAUDE.md is in context for every
request of a session, and Ekorn's is still 3,046 words (about 4,800
tokens), with 3,847 more in `docs/claude/`. DBIx-Squirrel's whole
CLAUDE.md is 1,647 words (about 2,600 tokens), with nothing beside it.
A split only saves what the files hold while unread, and each costs a
second read when a task needs it, a read a session can skip by
trusting the summary left behind. Half of what moved repeats documents
that already exist: `roadmap.md` repeats `ROADMAP.md`'s opening and
`docs/changes/README.md`; Minilla and the manuals are in both
CLAUDE.md's Perl section and `docs-and-builds.md`, word for word, and
in `docs/MAINTAINING.md`. The rest is history: dates, "as Iain decided
on", superseded rules, version ranges of the past, measurements. That
belongs in the commits and the change records, which already keep it.

**What to do:**

1. Rewrite CLAUDE.md in DBIx-Squirrel's shape, its sections and its
   terse wording, where a rule is the same in both (Who does what,
   Perl, Tests, Style, Planned work, the roadmap and change records,
   Commits): copy the text across and change the names. Ekorn stays
   standalone: copied, not imported.
2. Keep each rule only Ekorn has, in a line or two: no dependency on
   the DBI; `our $VERSION` in every module; `@Ekorn::Pipeline::Errors::INTERNAL`
   and `@CARP_NOT`; exports; `xt/agreement.t`, `xt/howto.t` and
   `xt/examples.t`; `.betterleaks.toml` named on every scan;
   `git pull --ff-only` and re-reading `TODO.md` before each commit;
   Text-Redact-Secrets as the third repository tasks and messages go
   to.
3. Keep the contract with DBIx-Squirrel as rules, in one short
   section: DBIx::Squirrel requires `>= v0.4.3, < v0.5.0` (read its
   `cpanfile` for the current range, rather than keeping a history of
   it); a v0.4.x only fixes or adds; a change to behaviour stages
   depend on, a public name dropped or renamed (`DumpSecrets`
   included, which it ties to), or a protocol changed, is v0.5.0 and
   comes with a task for DBIx-Squirrel; a name added to Tooling goes
   to it as a message, and mustn't clash with one of its own;
   `xt/dbix-squirrel-links.t` must pass before a release, and a
   heading it checks changes only with a message first. Leave the
   list of names it imports out: its `lib/DBIx/Squirrel/Tooling.pm`
   and the modules under `lib/DBIx/Squirrel/` are the list. Leave out
   where the code came from, and the superseded subclassing rule.
4. Move whatever is a procedure with commands, rather than a rule, to
   `docs/MAINTAINING.md`: the detail of the docs' example tests, if
   it isn't there already, and the worktree commands for the other
   repositories if CLAUDE.md would otherwise hold two copies (one
   copy, with the repository's name as the only change, is what
   DBIx-Squirrel's CLAUDE.md has, and it's fine).
5. Delete `docs/claude/`, and the line in `docs/MAINTAINING.md`
   (around line 356) pointing to `neighbours.md`; point it at
   CLAUDE.md's section instead. Leave 2026-0058's record as it is: a
   record's plan isn't edited.
6. Drop dates, "as Iain decided on", and the "Why:" paragraphs. Keep a
   reason only when it's a few words and stops a rule being undone,
   as DBIx-Squirrel keeps the 19 ns for `$_[0]`.

No roadmap item is needed: DBIx-Squirrel's trim went in as one
`docs:` commit, and this is the same.

**Done when:** `wc -w CLAUDE.md` is under about 1,900 words; `test !
-e docs/claude`; `git grep -n docs/claude` finds only 2026-0058's
record; each rule the old files held is in CLAUDE.md, in
`docs/MAINTAINING.md`, in `ROADMAP.md`'s opening or
`docs/changes/README.md`, or was history (say in the commit message
which rules were dropped as history); and the commit message gives the
word counts before and after. If a rule turns up here that
DBIx-Squirrel's CLAUDE.md ought to have, send it as a message.
