# Working on Ekorn-Pipeline

These are the working rules for this repository. Ekorn-Pipeline is Iain
Campbell's: it starts from the pipeline in DBIx-Squirrel 2, his code,
which he and Claude bring over and grow together, and Claude reviews
what he writes by hand. The rules below say who does what. Each rule
comes with the reason for it.

This project is standalone, as DBIx-Squirrel is, by Iain's choice on
2026-11-07: this file is the whole of its rules, and it imports no
shared practice. How the repository is kept, from every commit to a
release on CPAN, is in [docs/MAINTAINING.md](docs/MAINTAINING.md), with
commands to paste.

## What Ekorn-Pipeline is for

Stages for any function: let the caller finish the job. A function that
hands out values takes a list of stages from its caller, as its last
arguments, and runs each value through them. A stage can change a value
(map), drop it by returning nothing (filter), or return several values
(flatMap), and can stop the pipeline early, so that the function makes
no more values than its caller wants.

The point is that a function's author needn't cater for every use case
with an option, and its caller needn't litter the calling code with
loops, temporaries and flags: the caller extends what's done with the
results, beside the call. The README makes that case, and it's the
test of any new feature: does it let callers do more without the author
writing more?

It isn't tied to the DBI, or to any source of values.

## Ekorn-Pipeline and DBIx-Squirrel

The code came from DBIx-Squirrel-2 at
`5e30135672d8002b0bb67ba68278e5b1c262df8b` on its `develop` branch,
its version v2.0.2:
Pipeline, Stop, Gather, Pipes and the canned stages in Stages::Flow,
Stages::Batch and Stages::Taps, with their tests, renamed from
`DBIx::Squirrel::*` to `Ekorn::Pipeline::*`. What stayed there needs
the DBI or DBIx::Squirrel's iterators: Context, Stages::Rows (pluck and
as_hash, which need a statement's column names), and the iterators
themselves. Of DBIx::Squirrel::Errors, only `croakf` came.

The plan is for DBIx-Squirrel to depend on Ekorn-Pipeline once both are
stable, in place of its own copy. Until then the pipeline lives in
both:

- **A fix to code both have,** or anything else DBIx-Squirrel needs to
  do, is handed to it as a task in its `TODO.md`, as Planned work says.
- **What's new grows here,** not in DBIx-Squirrel.
- **Stages go where what they need to know is,** as Iain decided on
  2026-11-07. Stages for any values, whatever they are and wherever
  they come from, go under `Ekorn::Pipeline::Stages::*`. Stages for one
  kind of value or one source go under that module's own namespace:
  DBIx::Squirrel's, such as `pluck` and `as_hash`, which need a
  statement's column names, stay `DBIx::Squirrel::Stages::*`, and
  DBIx::Squirrel can keep making new ones there. Both kinds are built
  from Gather, Stop and `croakf`, and `t/09-stage-modules.t` checks
  that a module of stages outside Ekorn's namespace works with no more
  set up. A stage that turns out to need nothing of DBIx::Squirrel's
  belongs here.
- **Keep the switch in view.** The messages, the order stages run in,
  and what Stop and Gather do are DBIx-Squirrel's behaviour too. A
  change to them is a change DBIx-Squirrel will take on when it
  switches, so say so in the commit message and in `Changes`.
- **The version says what DBIx-Squirrel can take.** DBIx::Squirrel
  requires `>= v0.2.0, < v0.3.0`, as it moved the range on 2026-11-10,
  once v0.2.0 was on CPAN; the range began at `>= v0.1.1, < v0.2.0`,
  as Iain decided on 2026-11-07 and DBIx-Squirrel raised it on
  2026-11-08. So a v0.2.x reaches its users with no release of
  DBIx::Squirrel's. A v0.2.x only fixes or adds. A release that changes
  behaviour users' stages depend on (when a `gather` stage is made,
  what a stop does, the order end functions run in, where errors are
  reported, the messages), or drops or renames a public name, is
  v0.3.0, and comes with a task handed to DBIx-Squirrel, which tests it
  and moves the range. DBIx::Squirrel imports the names it documents
  by name: `Stop`, `gather`, `take`, `drop`, `take_while`,
  `drop_while`, `batch`, `collect`, `peek`, `count_into` and
  `dump_to`. A stage added here doesn't appear there until it's added
  to its list.

## Who does what

- **The code is a two-way process.** Iain writes some by hand, and
  Claude reviews it, suggests, and explains. Where Iain asks, Claude
  writes code too, often bringing his DBIx-Squirrel code over and
  improving it, and Iain reviews that. Claude doesn't change code it
  wasn't asked to.
- **Claude helps with the Git Ops and the repository's setup:**
  branches, CI, releases, and the files around the code. Ask before
  changing anything on GitHub.
- **Tests and documentation,** where Iain asks: the pipeline's spec as
  tests, and keeping the POD, README, `docs/HOWTO.md`,
  `docs/REFERENCE.md` and `Changes` up to date with the code. The
  how-to and the reference say the same as the POD, at more length; the
  POD is the authority where they differ.
- **Commit messages:** Claude drafts them when asked, for Iain's commits
  as well as its own.

Why: Ekorn-Pipeline is a tool Iain uses, and DBIx-Squirrel will stand
on it, so it matters most that it's right.

## Credit

- Iain's commits carry no `Co-Authored-By` trailer, even when Claude
  drafted the message.
- Commits Claude wrote, such as code, CI, setup files, tests or docs
  written at Iain's request, end with a trailer for the Claude model
  that wrote them, currently
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- The README's Acknowledgements say what Claude did. Keep them accurate.
- **On CPAN, Iain is `Iain Campbell <cpanic@cpan.org>`,** and no other
  address goes in the distribution: the main module's AUTHOR and so
  `META.json`. Commits use his GitHub noreply address, which GitHub
  needs to verify their signatures, so `.mailmap` maps it to the CPAN
  one. Minilla reads authors through it, and would otherwise list Iain
  as a contributor to his own distribution.

Why: credit goes where the work was done, so a reader can see exactly
what was Iain's.

## Perl

- **Perl 5.36 or later.** Modules start `use v5.36`, which gives strict,
  warnings, `say` and signatures. `try`/`catch` is still experimental
  in 5.36, and is used anyway, as DBIx-Squirrel decided on 2026-10-28:
  a module that needs it adds `use experimental qw(try);`, which also
  allows `finally`. Once the floor reaches 5.40, `use v5.40` turns on
  `try`/`catch` by itself, and the line is needed only for `finally`.
  `builtin::` functions are used the same way, in place of
  Scalar::Util: a module adds `use experimental qw(builtin);` and
  imports what it needs, such as `use builtin qw(weaken);`. Only
  functions stable in 5.40 are used, so that once the floor reaches
  5.40, `use v5.40` imports them, and both lines go. CI tests from the
  floor to the newest Perl.
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
- **No dependency on the DBI,** or on anything that isn't needed to run
  values through stages. The runtime dependencies are in `cpanfile`;
  adding one is a decision for Iain.
- Locally, Iain uses perlbrew with a library of the project's own,
  `perl-5.36.3@ekorn-pipeline`, so its modules don't mix with other
  projects'. Whatever his default Perl is at the time, run commands with
  the library named, so they don't depend on it, and never `perlbrew
  switch` or `use`, which would change his shell:

  ```
  perlbrew exec --with perl-5.36.3@ekorn-pipeline yath test
  ```

  Each Perl CI covers has a library of the same name, made on
  2026-11-07 with the cpanfile's runtime, test and develop modules, so
  the tests run across the whole range: `perl-5.38.5@ekorn-pipeline`,
  `perl-5.40.5@ekorn-pipeline`, `perl-5.42.3@ekorn-pipeline` and
  `perl-5.44.0@ekorn-pipeline`. Minilla, and yath's helpers for its
  logs, are in the 5.36 library.

  Building a Perl, or Net::SSLeay against OpenSSL 4, on Iain's Mac:
  DBIx-Squirrel's CLAUDE.md has what worked.

## Tests

- **Test2::V0, not Test::More,** in every test: `use Test2::V0;`, with
  `is`, `like` and Test2's checks (`T()`, `F()`, `hash`, `array`) for
  structures. Compare values, never Data::Dumper output: a boolean
  dumps as `1` on Perl 5.36 and as `!!1` from 5.38.
- **Test2::Plugin::NoWarnings** in each test file, so a warning fails
  the test that caused it.
- **yath, not prove,** runs them. It adds `lib`, `blib/lib` and
  `blib/arch` itself, and runs files in parallel. With `-L`, it keeps a
  log of the run, in the system's temporary directory, linked from
  `./lastlog.jsonl` (git-ignored), so a failure can be read after it,
  even one that doesn't happen again:

  ```
  perlbrew exec --with perl-5.36.3@ekorn-pipeline yath test -L
  perlbrew exec --with perl-5.36.3@ekorn-pipeline yath failed lastlog.jsonl
  ```

  The second shows the tests that failed in the last run;
  `yath replay lastlog.jsonl` shows all of it.

- **Coverage has floors, which it mustn't fall below.**
  `scripts/coverage` runs the tests under Devel::Cover, from an empty
  `cover_db`, and fails if the coverage of `lib/` falls below the floors
  at its top; CI runs it on every push. New code comes with the tests
  that keep coverage above them. Raise a floor when coverage rises, and
  lower one only with the reason in the commit message.

  ```
  perlbrew exec --with perl-5.36.3@ekorn-pipeline scripts/coverage
  perlbrew exec --with perl-5.36.3@ekorn-pipeline cover -report text -select_re '^lib/'
  ```

  The second, after the first, shows the lines and branches the tests
  miss.
- **The examples in the README, the how-to and the reference are
  checked by hand** for now: run each one, and see that it prints what
  its comments say, before committing a change to them. The how-to's
  examples follow on from its first, which sets up their data.
- Users installing from CPAN run the tests with whatever harness their
  installer uses, so they must pass under `prove` too. yath is the
  maintainers' choice, not a requirement.
- **`xt/`, when there is one, holds the maintainers' tests,** which
  yath runs with those in `t/`, as `.yath.rc` says, and `prove` doesn't.

## Style and tools

- **Perl::Tidy** formats the code, with `.perltidyrc` (Iain's, the same
  as DBIx-Squirrel's). It sets `--standard-output`, for editors, so
  `perltidy` prints the result instead of writing a `.tdy` file. To see
  what it would change:

  ```
  perlbrew exec --quiet --with perl-5.36.3@ekorn-pipeline perltidy lib/Ekorn/Pipeline.pm | diff lib/Ekorn/Pipeline.pm -
  ```

- **Perl::Critic** reviews it, with `.perlcriticrc`: severity 3 and up,
  core policies. Its comments say why each excluded policy is excluded;
  `ProhibitVersionStrings` among them, since modules start `use v5.36`.

  ```
  perlbrew exec --with perl-5.36.3@ekorn-pipeline perlcritic lib
  ```

- **Data::Dump**'s `pp` is for looking at data while debugging, not for
  the shipped modules or for test expectations (see Tests).
- **`croakf` raises our own errors.** A message Ekorn::Pipeline writes
  is raised with `croakf` from Ekorn::Pipeline::Errors, a `sprintf`
  format and its arguments, as in
  `croakf 'Expected stage #%d to be a code reference', $n`, so each
  message is one plain string, matching its DIAGNOSTICS entry. `croak`
  is for what we pass on, such as an exception object or a stop. A `%`
  in a message of our own is written `%%`. A new module that croaks
  goes in `@Ekorn::Pipeline::Errors::INTERNAL`, and takes that list as
  its `@CARP_NOT`, so errors are reported at the caller's line.
- **Exports:** `@EXPORT_OK` as a rule. A module whose whole purpose is
  its functions, such as Stop, Gather and the canned stages, exports
  them by default, marked `## no critic
  (Modules::ProhibitAutomaticExportation)` as a deliberate exception.
- **Two blank lines between subs, or one above a sub's comment.** A sub
  without a comment above it has two blank lines before it, to make the
  gap between subs plain; one with a comment has one, above the
  comment, which marks the gap itself. Perl::Tidy keeps either.
- **Every regex takes the `x` flag** and is written with its operator
  and parentheses: `m( \A \d+ \z )x`, `s( \s+ \z )()xr`, `qr( ... )x`;
  never `/.../`. The whitespace makes a regex easier to read, and the
  operator and parentheses make it read like a function. Under `x`, a
  literal space is `\ ` and a literal `#` is `\#`.

## Planned work

- **At the start of a session, check for `TODO.md`** at the top of the
  repository, on `develop`. If it's there, read it, ask Iain whether each
  task should still be done, and do the ones he confirms. Remove each
  task in the commit that completes it, so the history shows which
  commit did which, and delete the file with the last one. A task he
  drops is removed too, saying why in the commit message.
- **Work planned for a later session goes into `TODO.md`,** committed on
  `develop`, with enough to do it cold: what, why, the files involved,
  and how to check it's done. Not only in Claude's memory or the chat,
  which Iain can't review and a fresh session may not have.
- **Before each commit, `git pull --ff-only` and re-read `TODO.md`.**
  DBIx-Squirrel's session adds tasks here, mid-session too, and a
  commit that completes a task must remove it.
- **Each task opens with where it came from and what it waits on,** so
  a session can see at a glance which tasks it can do now, and whom to
  tell when one is done:

  ```markdown
  ## Release v0.1.0

  **From:** DBIx-Squirrel's session, 2026-11-07 (DBIx-Squirrel
  8447689997ae6b1ec5f3a5c45a4fac0224391ce4, on its branch `ekorn-pipeline`)
  **Waiting on:** nothing
  ```

  `From` names the repository whose session added it, the date, and the
  commit it came from: the full hash, and the branch if it isn't
  `develop`. `Waiting on` is "nothing" when the task can be done now.
- **Tasks for DBIx-Squirrel go in its `TODO.md`,** as grammar and scalar
  hand tasks to each other, as Iain decided on 2026-11-07. A session
  here commits the task straight into
  `~/Git/github.com/nukopian/DBIx-Squirrel`'s `TODO.md`, as `docs: a
  task from Ekorn-Pipeline: ...`, and pushes it at once: left
  uncommitted, it blocks that repository's next pull and never reaches
  the session that would do it. Commit only that file, by its path, so
  nothing of a session working there goes with it.
- **While an experimental branch carries a repository's work, its
  `TODO.md` is kept on that branch,** as Iain decided on 2026-11-08, so
  tasks and messages for it go there, not to `develop`. DBIx-Squirrel's
  `ekorn-pipeline` did, until it merged on 2026-11-08. Now both
  repositories' work on roadmap 2026-0014 and the items after it is
  carried by a branch of the same name in each, `pipeline-experimental`,
  as Iain decided on 2026-11-10: shorter than a name made from the id,
  and one name for the two sessions. So tasks and messages for
  DBIx-Squirrel go to its `pipeline-experimental`, and its own come to
  ours, until the branches merge. Never switch DBIx-Squirrel's
  working copy, or commit in it, as a session may be working there:
  use a worktree of the branch as GitHub has it, edit
  `/tmp/dbix-squirrel-todo/TODO.md`, commit only it, and push from
  there:

  ```
  git -C ~/Git/github.com/nukopian/DBIx-Squirrel fetch -q origin
  git -C ~/Git/github.com/nukopian/DBIx-Squirrel worktree add --detach /tmp/dbix-squirrel-todo origin/develop
  git -C /tmp/dbix-squirrel-todo push origin HEAD:develop
  git -C ~/Git/github.com/nukopian/DBIx-Squirrel worktree remove /tmp/dbix-squirrel-todo
  ```

  While an experimental branch of DBIx-Squirrel's carries its work, use
  that branch's name in place of `develop` in the second and third
  commands. A push refused as not a fast-forward means the branch
  moved: remove the worktree and start again from the fetch. The
  same holds here: while an experimental branch of Ekorn-Pipeline's,
  such as `pipeline-experimental`, carries its work, `TODO.md` is kept
  on it, and DBIx-Squirrel's session hands tasks and messages to that
  branch. DBIx-Squirrel's tasks for Ekorn-Pipeline come here the same
  way. It's the only other repository this one touches.
- **A release ends by telling DBIx-Squirrel,** with a task in its
  `TODO.md`, and by looking there for tasks waiting on the release, so
  Iain knows which can now be done. Nothing else tells its session
  that a release has landed.
- **Messages go in a `# Messages` section, above `# Planned work`,** in
  the same `TODO.md`, as Iain decided on 2026-11-07. A message is news
  the other session should know, but needs no work of its own: what one
  side has decided or done, or a change in plan. A message that asks
  for work is a task instead. Each is a `##` heading saying who it's
  from, the date and what it's about, with a **From:** line, sent as
  `docs: a message from Ekorn-Pipeline: ...`, committing only that
  file. Read messages at the start of a session, with the tasks; the
  session they're for removes each once read, in a commit saying what
  came of it, and the heading with the last one.
- **`TODO.md`'s tasks and messages are the only way the two sessions
  talk.** Now that DBIx-Squirrel and Ekorn-Pipeline are separate,
  DBIx-Squirrel dogfoods Ekorn-Pipeline, as its first user, and what it
  finds matters most: friction, a gap, a clumsy name, or a stage it had
  to write that others would want. Either session that finds such a
  thing in the other's product while working sends it as a message:
  what was found, where (the file and commit), and what might be done.
  Nothing enters the other's `ROADMAP.md` or records directly; the
  session it's for takes the message to Iain, who decides whether it
  becomes an idea, an item or a task there, and the commit that
  removes the message says so. An item that comes of one gives the
  message in its record's Origin, with the repository, date and commit.
- **A feature is designed in the session of the repository it belongs
  to,** as Iain decided on 2026-11-10, after the design of Ekorn's
  grammar of sources, stages, gathers and sinks was split across the
  two sessions. Its discussion, and its ideas, items and records, are
  that repository's. The other session sends what it thinks of, or
  finds, as messages, and designs nothing of it in its own chat:
  Ekorn::Pipeline's features are designed in Ekorn-Pipeline's session,
  and DBIx::Squirrel's, such as a stage or sink that needs the DBI, in
  DBIx-Squirrel's.
- **`TODO.md` never reaches `main`.** `main` moves only by a
  fast-forward to `develop`, so a release waits until the file is gone:
  each task done, or, to outlast the release, moved to `ROADMAP.md`, a
  decision awaiting Iain with it, in its record. No GitHub issues or
  Claude Docs for planned work or decisions, as Iain decided on
  2026-11-07: they sit outside the repository, apart from the history
  and the chat.

Why: planned work survives between sessions in the open, where Iain
reviews it like any other change, and a release never carries an
unfinished list.

## The roadmap

These rules, and those for change records, are Ekorn-Pipeline's and
DBIx-Squirrel's, as Iain decided on 2026-11-07. They follow the shared
practice grammar and scalar use, but name items by an id rather than
a number.

- **`ROADMAP.md` holds what Ekorn-Pipeline means to do:** features and
  outcomes, not session tasks. Its opening says how it's kept. **Now**
  is what's being worked on, at most three items, so it stays a queue:
  each a paragraph and a link to its record. Another starts only when
  one ships or goes back to Next. **Next** is decided but not started
  (what, why, done when). **Later** is meant to be done but not yet
  planned, in a line or two. **Ideas** might be done, or never: the
  date added, a line or two, newest last. The others put the most
  useful first.
- **Every item has an id, its year and a serial: `2026-0001`.** The
  year is the year it was added, and the serial is four digits, from
  0001, starting again each year. It's given when the item is added,
  never changed, and never used again. The roadmap's opening gives the
  last id allocated, as "Last id: 2026-0004": to allocate one, take
  this year, and add one to the last serial if its year is this year,
  or start at 0001 if not, and change that line in the commit that adds
  the item.
- **The id names the item everywhere:** its heading, `### 2026-0001. A
  stages() method`; its record, `docs/changes/2026-0001-stages-method.md`;
  its line in `Changes`, which ends "(roadmap 2026-0001)"; commit
  messages; and a branch for it, such as
  `experiment/2026-0001-stages-method`. Another repository's id goes
  with that repository's name, as "DBIx-Squirrel 2026-0001".
- **Every item has a size,** a guess at how much work it is, as a
  T-shirt size and its story points, XS 1, S 2, M 3 and L 5, in a
  **Size:** line, such as `**Size:** S (2)`. An item bigger than L is
  split into items that aren't, each with an id of its own and a
  **Split from:** line; the item split is retired, its id named in the
  commit.
- **An item that can't be done before another says so,** in a
  **Depends on:** line naming each id. It's never in a group ahead of
  an item it depends on: moving it forward moves those too, so a chain
  of them moves together, and they ship first or with it.
- **An item's questions are settled before work on it starts.** They're
  discussed in the chat, and kept in its record's Decisions, numbered,
  D1, D2 and on: unchecked while open, and checked once settled, with
  the answer, the date and why. A **Decisions:** line under the
  record's status sums them up, each settled or open in a few words,
  so its state shows at a glance. An item moves to Now only once every
  decision is checked, or Iain agrees to move one still open to another
  item or task, which the record says. A decision that needs no work
  of its own is kept in the commit message that records it.
- **When Iain mentions an idea in passing,** offer in one line to add
  it ("add as 2026-0005?"), and add it in a `docs:` commit.
- **It's kept current:** an item leaves when it ships, in the commit
  that adds it to `Changes`, and a change that ships, starts or drops
  an item updates it in the same commit. A dropped item is deleted, the
  commit naming its id, and its record, if it has one, says why.
- **It's public, on GitHub and `main`,** but not in the CPAN tarball,
  as `minil.toml` says, so nothing personal goes in it. There's no PDF
  of it.

Why: `Changes` is the past, the README the present, and the roadmap
the future, so anyone following the project can see what's coming; and
an id that sorts and never changes can be searched for years later.

## Change records

- **A planned change keeps a record** in `docs/changes/`, named for its
  id and the change: `2026-0001-stages-method.md`. A roadmap item's
  record is opened when it first has a question to settle, or when
  work on it starts. A task in `TODO.md` with steps gets a record too,
  taking the next id from the roadmap's opening, in the same sequence,
  though the task never appears there.
- **The plan is written in it when work starts, and isn't edited
  after.** What happened is added as the work goes: the outcome against
  Done when, changes from the plan and why, measurements, what was
  tried and reverted, and what's left. Experiments go in it too, with
  what they showed, as they won't survive anywhere else.
- **It's finished in the commit that ships or drops the change.** Its
  status is open, in progress, shipped, unreleased, shipped in vX.Y.Z,
  or dropped; a dropped change keeps its record, saying why.
- `docs/changes/README.md` has the template, and lists the records.
  Small fixes need none. There's no PDF of a record.

Why: the plan and its outcome sit side by side, with the decisions
that shaped it, so a reader can see what was predicted and what was
found.

## Commits

- Conventional commits, such as `feat: ...`, `fix: ...`, `docs: ...`,
  `test: ...` or `ci: ...`. Say why as well as what.
- Commits are signed. Work is committed and pushed to `develop`. `main`
  is the latest release, and moves only at a release, by a fast-forward
  to `develop`, with a signed tag on it. The first was
  v0.1.1, on 2026-11-08.
- Add what changed for users to `Changes`, under Unreleased, in the same
  commit. Each entry opens with a precis, a short paragraph saying what
  the release brings, naming by id the roadmap items it ships, kept
  current as Unreleased grows: CPAN's users don't get the roadmap, and
  the precis is their account of it.
- gitleaks scans the whole history for secrets in CI on every push, and
  by hand before a tag. A leak stops the work like a failing test: once
  history is published, it can't be taken back.
