# Working on Ekorn-Pipeline

The working rules for this repository, which is standalone: it imports
no shared practice. What it means to do is in [ROADMAP.md](ROADMAP.md),
with each item's decisions in its record in
[docs/changes/](docs/changes/README.md). How it's kept, from a commit
to a CPAN release, with commands to paste, is in
[docs/MAINTAINING.md](docs/MAINTAINING.md): read the section for the
job before doing it. Building Perl on Iain's Mac is in Iain's Mac,
the last section of DBIx-Squirrel's `docs/MAINTAINING.md`.

## What it is

Stages for any function: let the caller finish the job. A function
takes a list of stages from its caller, as its last arguments, and runs
each value it hands out through them. A stage can change a value
(map), drop it (filter), return several (flatMap), or stop the
pipeline early. It's tied to no source of values. The test of a new
feature: does it let callers do more without the author writing more?

## Who does what

- **Code goes both ways.** Iain writes some by hand, and Claude reviews
  it. Where Iain asks, Claude writes code, often bringing his
  DBIx-Squirrel code over and improving it, and Iain reviews that.
  Claude doesn't change code it wasn't asked to.
- **Claude helps with Git ops and setup:** branches, CI, releases, the
  files around the code. Ask before changing anything on GitHub.
- **Tests and docs where Iain asks,** keeping the POD, `README.pod`,
  `docs/HOWTO.md`, `docs/REFERENCE.md`, `Changes` and the README's
  Acknowledgements (what Claude did) accurate. The how-to and the
  reference say what the POD says, at more length; the POD wins where
  they differ.
- **PDFs only when Iain asks** (`scripts/readme-pdf.sh`). Check a docs
  change as text: run its examples, read the diff, run `xt/`.
- **Commit messages:** Claude drafts them when asked. Every commit
  ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`,
  Iain's own included: we share the credit and the blame.
- **On CPAN, Iain is `Iain Campbell <cpanic@cpan.org>`,** the only
  address in the distribution. `.mailmap` maps his GitHub noreply
  address to it, so Minilla doesn't list him as his own contributor.

## Perl

- **Perl 5.36 or later;** modules start `use v5.36`. A module using
  `try`/`catch` adds `use experimental qw(try);`. `finally` works only
  after a `catch`: `try {...} finally {...}` is a syntax error on every
  Perl up to 5.44, so cleanup-only code catches, cleans up and throws
  again. `builtin::` functions replace Scalar::Util, with
  `use experimental qw(builtin);` and `use builtin qw(weaken);`; only
  those stable in 5.40.
- **No dependency on the DBI,** or on anything not needed to run values
  through stages. Adding a runtime dependency to `cpanfile` is Iain's
  decision.
- **Minilla builds the distribution;** follow its conventions. Our
  three departures: the README is `README.pod` (never edit
  `README.md`); `Changes` keeps an "Unreleased" heading; and releases
  do their own git steps rather than `minil release`, as
  MAINTAINING.md says.
- **The manuals are generated:** edit `docs/REFERENCE.md` and
  `docs/HOWTO.md`, run `scripts/manuals`, never edit the POD. A change
  to the script that suits DBIx-Squirrel's copy goes to it.
- **Run everything with the library named,** never `perlbrew switch`
  or `use`, which would change Iain's shell:
  `perlbrew exec --with perl-5.36.3@ekorn-pipeline ...`. Libraries of
  the same name exist for 5.38.5, 5.40.5, 5.42.3 and 5.44.0; Minilla
  and yath's log helpers are in 5.36's.

## Tests

- **Test2::V0, never Test::More,** with Test2::Plugin::NoWarnings in
  every file. Compare values, never Data::Dumper output (booleans dump
  differently from 5.38).
- **yath, not prove,** with `-L`; `yath failed lastlog.jsonl` shows the
  failures. It runs `xt/` with `t/` (`.yath.rc`). Tests must pass
  under `prove` too, which users have.
- **Coverage has floors** in `scripts/coverage`. New code comes with
  tests that keep above them; raise a floor when coverage rises, lower
  one only with the reason in the commit message.
- **The docs' examples are tested** by `xt/howto.t` and
  `xt/examples.t`, against their comments: write a comment as exactly
  what the example prints, and mark one that can't run
  `<!-- not run -->`. `xt/agreement.t` runs random pipelines every way.
  MAINTAINING.md's Every commit has the detail.

## Style

- **Perl::Tidy and Perl::Critic** (`.perltidyrc`, `.perlcriticrc`) run
  on Perl 5.44, as CI's style job does, since Perl::Critic takes
  keywords from the Perl it runs on.
- **`croakf` raises our own errors,** from Ekorn::Pipeline::Errors, as
  a `sprintf` format and arguments matching its DIAGNOSTICS entry; a
  literal `%` is `%%`. `croak` passes on what isn't ours. A new module
  that croaks goes in `@Ekorn::Pipeline::Errors::INTERNAL` and takes it
  as its `@CARP_NOT`, so errors are reported at the caller's line.
- **An object, such as a stop, is thrown with `die`:** `croak` adds
  nothing for it, at three times the cost.
- **Every module declares `our $VERSION`,** once, for its own package;
  `t/34-versions.t` checks.
- **`@EXPORT_OK` as a rule.** A module whose whole purpose is its
  functions, such as Stop, Gather and the canned stages, exports by
  default, marked `## no critic (Modules::ProhibitAutomaticExportation)`.
- **Factories,** such as `pipeline` and `gather`, are one line over a
  class method, only in Ekorn::Pipeline::Factories. Stages for any
  values go under `Ekorn::Pipeline::Stages::*`; one needing a source's
  knowledge goes in that source's namespace.
- **A closure run for each value reads `$_[0]`, without a signature**
  (our stages, sources and sinks), with a comment saying why: a
  signature, or copying to a `my`, costs about 19 ns a call. A step
  that hands the value to the caller's code, such as `peek`'s block,
  keeps its signature, so the block can't change what's passed on.
  Other subs, and the docs' examples, keep theirs.
- **Two blank lines between subs,** or one above a sub's comment, in
  tests and scripts too. Perl::Tidy keeps one above a comment, but
  makes two above a sub without one, even at the start of a block, and
  above `sub {` starting a line in a list: name such a closure in a
  variable first.
- **Every regex takes `x`, and its operator with parentheses:**
  `m( \A \d+ \z )x`, `s( \s+ \z )()xr`, `qr( ... )x`; never `/.../`.
  A literal space is `\ `, a literal `#` is `\#`.
- **Data::Dump's `pp`** is for debugging only.

## DBIx-Squirrel and Text-Redact-Secrets

DBIx::Squirrel uses Ekorn as any package would, so Ekorn's protocols,
messages, the order stages run in, and what Stop and Gather do are its
behaviour too. What's new grows here; a fix to code both have goes to
DBIx-Squirrel as a task.

- **Its `cpanfile` has the range it requires,** now `>= v0.4.3,
  < v0.5.0`. A v0.4.x only fixes or adds. A change to behaviour users'
  stages depend on, a public name dropped or renamed (`DumpSecrets`
  included, which it ties to), or a protocol changed, is v0.5.0, with a
  task for DBIx-Squirrel. Say so in the commit message and `Changes`.
- **It imports Ekorn's names one by one;** its
  `lib/DBIx/Squirrel/Tooling.pm` and modules are the list. A name added
  to Ekorn's Tooling goes to it as a message, and mustn't clash with
  one of its own: that goes to Iain first. A name both Toolings export
  must stay one sub, which its installed tests check.
- **Its docs link to our sections.** `xt/dbix-squirrel-links.t` must
  pass before a release; a heading it checks changes only after a
  message to DBIx-Squirrel.
- **Text::Redact::Secrets is recommended:** `dump_to` calls its
  `redact` when it's installed and passes a self-test; a change to that
  comes here as a message first.

## Planned work

- **At a session's start, read `TODO.md`** on `develop`, or on an
  experimental branch while one carries the work. Ask Iain
  whether each still stands. Remove each in the commit that completes
  or drops it (saying why), and the file with the last one.
- **Before each commit, `git pull --ff-only` and re-read `TODO.md`:**
  the other sessions add to it mid-session.
- **Work for a later session goes in `TODO.md`** on `develop`, with
  enough to do it cold: what, why, the files, and how to check it's
  done. Never only in memory or the chat.
- **`TODO.md` never reaches `main`:** before a release each task is
  done or moved to `ROADMAP.md`. No GitHub issues or Claude Docs for
  plans or decisions.
- **DBIx-Squirrel and Text-Redact-Secrets are the only other
  repositories this one touches,** and only their `TODO.md`. A
  **task** asks for work, under `# Planned work`, committed as
  `docs: a task from Ekorn-Pipeline: ...`, with **From:** (repository,
  date, our full commit hash) and **Waiting on:** lines. A **message**
  is news needing no work, in a `# Messages` section above it, a `##`
  heading with sender, date and subject, a **From:** line, committed as
  `docs: a message from Ekorn-Pipeline: ...`. A release ends with a
  task to DBIx-Squirrel. Commit only that file, by path, on its
  `develop`, and push at once, from a worktree, never its working copy
  (for Text-Redact-Secrets, change the name):

  ```
  git -C ~/Git/github.com/nukopian/DBIx-Squirrel fetch -q origin
  git -C ~/Git/github.com/nukopian/DBIx-Squirrel worktree add --detach /tmp/dbix-squirrel-todo origin/develop
  git -C /tmp/dbix-squirrel-todo push origin HEAD:develop
  git -C ~/Git/github.com/nukopian/DBIx-Squirrel worktree remove /tmp/dbix-squirrel-todo
  ```

  If the push isn't a fast-forward, remove the worktree and start from
  the fetch. Nothing goes in the other's roadmap or records directly:
  Iain decides what a message becomes, and an item from one names it
  in its record's Origin.
- **A feature is designed in its own repository's session:**
  Ekorn::Pipeline's here, anything needing the DBI in DBIx-Squirrel's.
  The other session only sends messages.
- **No secret whole in a message or task,** made-up or not: build it
  from pieces (`join '', 'AKIA', 'MADEUP', ...`) or leave it out.

## The roadmap and change records

ROADMAP.md's opening and docs/changes/README.md say how they're kept;
follow them. In short:

- Ids are year and serial, `2026-0001`, taken from "Last id:" in the
  roadmap's opening, which the adding commit updates. The id names the
  heading, the record, the `Changes` line ("(roadmap 2026-0001)"),
  commits and any branch. Another repository's id carries its name.
- Every item has a **Size:** (XS 1, S 2, M 3, L 5; bigger is split),
  and a **Depends on:** line where needed. Now holds at most three.
- An item's questions are numbered decisions (D1, D2...) in its record,
  checked with answer, date and why, and summed up in a
  **Decisions:** line. It moves to Now only once all are settled.
- **When Iain mentions an idea in passing,** offer in one line to add
  it ("add as 2026-0059?").
- The plan in a record isn't edited once work starts; what happened is
  added as it goes, and finished in the commit that ships or drops it.
  A shipped item leaves the roadmap in the commit adding it to
  `Changes`.
- Both are public, so nothing personal.

## Commits

- Conventional, signed, saying why as well as what; pushed to
  `develop`. `main` moves only at a release, by fast-forward, with a
  signed tag.
- User-visible changes go in `Changes` under Unreleased in the same
  commit, and the entry's precis, naming the roadmap ids it ships, is
  kept current.
- **Secrets:** betterleaks scans history in CI. A commit of docs, tests
  or a message, here or in another's `TODO.md`, is scanned before it's
  pushed, with `betterleaks dir --config .betterleaks.toml --redact
  --exit-code 1` on what it changed. Every scan names
  `.betterleaks.toml`, which allows `dump_to`'s placeholders; a new one
  goes in only as Iain decides. A finding stops the work. Published history is
  never rewritten: list that one finding by fingerprint in
  `.gitleaksignore`, which betterleaks reads, with Iain's reason above
  it, and revoke a real secret first. Claude changes
  `.betterleaks.toml` and `.gitleaksignore` only with its Edit tool,
  never from the shell: a rule in Iain's settings makes each such edit
  ask him.
