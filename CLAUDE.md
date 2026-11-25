# Working on Ekorn-Pipeline

These are the working rules for this repository. Ekorn-Pipeline is Iain
Campbell's: it starts from the pipeline in DBIx-Squirrel 2, his code,
which he and Claude bring over and grow together, and Claude reviews
what he writes by hand. The rules below say who does what. Each rule
comes with the reason for it.

This project is standalone, as DBIx-Squirrel is, by Iain's choice on
2026-11-07: this file, and the files in `docs/claude/` it points to,
are the whole of its rules, and it imports no shared practice. How the
repository is kept, from every commit to a release on CPAN, is in
[docs/MAINTAINING.md](docs/MAINTAINING.md), with commands to paste.

This file holds the rules most tasks need. Read the others when a task
needs them:

- [docs/claude/neighbours.md](docs/claude/neighbours.md): Ekorn's
  contract with DBIx-Squirrel and Text-Redact-Secrets, the version
  range DBIx::Squirrel requires, and the names it imports. Read it
  before changing a public name, a message, a protocol or the order
  things run in, and before choosing a release's version.
- [docs/claude/sessions.md](docs/claude/sessions.md): how tasks and
  messages pass between this repository and DBIx-Squirrel's and
  Text-Redact-Secrets', with the worktree commands. Read it before
  writing a task or a message, and at a release.
- [docs/claude/roadmap.md](docs/claude/roadmap.md): how `ROADMAP.md`
  and the change records in `docs/changes/` are kept. Read it before
  adding, moving, starting, shipping or dropping an item, or writing a
  record.
- [docs/claude/docs-and-builds.md](docs/claude/docs-and-builds.md):
  Minilla, the manuals made from `docs/`, and how the examples in the
  how-to, the README and the reference are checked. Read it before a
  change to the docs, or a release.

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

DBIx-Squirrel will depend on Ekorn-Pipeline, and already uses it as any
package would, so Ekorn's protocols, messages, the order stages run in,
and what Stop and Gather do are its behaviour too. What's new grows
here; a fix to code both have goes to DBIx-Squirrel as a task. A v0.4.x
only fixes or adds; a change to behaviour users' stages depend on, or a
public name dropped or renamed, is a v0.5.0, with a task for
DBIx-Squirrel. The rules, and why, are in
[docs/claude/neighbours.md](docs/claude/neighbours.md).

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
- **The PDFs are made when Iain asks, not after every docs change,**
  as he decided on 2026-11-13, in place of his usual rule of
  rebuilding them and reading the changed pages each time. Check a
  docs change as text: run its examples, read the diff, and run
  `xt/manuals.t`. When he asks, build them with
  `scripts/readme-pdf.sh`, as MAINTAINING.md says, and read the pages
  he names, as text with `pdftotext` unless layout matters.
- **Commit messages:** Claude drafts them when asked, for Iain's commits
  as well as its own.

Why: Ekorn-Pipeline is a tool Iain uses, and DBIx-Squirrel will stand
on it, so it matters most that it's right.

## Credit

- **Every commit Claude makes carries a `Co-Authored-By` trailer** for
  the Claude model that made it, currently
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`: code, CI,
  setup files, tests or docs written at Iain's request, and a commit
  holding Iain's own change with Claude's work to finish it, as Iain
  decided on 2026-11-13. It's left off only when Iain says so before
  the commit. Commits Iain makes himself are his to sign off.
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
  allows `finally`, but only after a `catch`: `try {...} finally {...}`
  is a syntax error on every Perl from 5.36 to 5.44, so code that only
  cleans up catches and throws again, then cleans up after. Once the
  floor reaches 5.40, `use v5.40` turns on `try`/`catch` by itself,
  and the line is needed only for `finally`, still experimental.
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
  the last section of DBIx-Squirrel's `docs/MAINTAINING.md`, "Iain's
  Mac", has what worked.

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
- **`xt/`, when there is one, holds the maintainers' tests,** which
  yath runs with those in `t/`, as `.yath.rc` says, and `prove` doesn't.

## Style and tools

- **Perl::Tidy** formats the code, with `.perltidyrc` (Iain's, the same
  as DBIx-Squirrel's). It sets `--standard-output`, for editors, so
  `perltidy` prints the result instead of writing a `.tdy` file. To see
  what it would change, on the newest Perl, as CI's style check runs:

  ```
  perlbrew exec --quiet --with perl-5.44.0@ekorn-pipeline perltidy lib/Ekorn/Pipeline.pm | diff lib/Ekorn/Pipeline.pm -
  ```

- **Perl::Critic** reviews it, with `.perlcriticrc`: severity 3 and up,
  core policies. Its comments say why each excluded policy is excluded;
  `ProhibitVersionStrings` among them, since modules start `use v5.36`.
  Run it on the newest Perl, as CI's style check does: it knows a
  Perl's builtins from that Perl, so a sub named for a keyword added
  since the floor, such as `all`, from 5.42, passes on 5.36.

  ```
  perlbrew exec --with perl-5.44.0@ekorn-pipeline perlcritic lib
  ```

- **Data::Dump**'s `pp` is for looking at data while debugging, not for
  the shipped modules or for test expectations (see Tests).
- **`croakf` raises our own errors.** A message Ekorn::Pipeline writes
  is raised with `croakf` from Ekorn::Pipeline::Errors, a `sprintf`
  format and its arguments, as in
  `croakf 'Expected stage #%d to be a stage, not a source', $n`, so each
  message is one plain string, matching its DIAGNOSTICS entry. `croak`
  is for what we pass on, such as an exception object or a stop. A new
  stop is thrown with `die`, as Iain decided on 2026-11-14: given an
  object, `croak` adds nothing, and tripled a stop's cost
  (`Stop->throw`'s comment has the measurement). A `%`
  in a message of our own is written `%%`. A new module that croaks
  goes in `@Ekorn::Pipeline::Errors::INTERNAL`, and takes that list as
  its `@CARP_NOT`, so errors are reported at the caller's line.
- **Every module declares `our $VERSION`,** the distribution's, once,
  for its own package, as Iain decided on 2026-11-25 (2026-0053's
  D5): `minil prepare` sets each, and `t/34-versions.t` fails if one
  is missing, differs, or strays into a package inside a module. A new
  module copies the line from any other.
- **Exports:** `@EXPORT_OK` as a rule. A module whose whole purpose is
  its functions, such as Stop, Gather and the canned stages, exports
  them by default, marked `## no critic
  (Modules::ProhibitAutomaticExportation)` as a deliberate exception.
- **Two blank lines between subs, or one above a sub's comment.** A sub
  without a comment above it has two blank lines before it, to make the
  gap between subs plain; one with a comment has one, above the
  comment, which marks the gap itself, as Iain confirmed on 2026-11-25
  (2026-0053's D4), in tests and scripts too. Perl::Tidy keeps one
  above a comment, but makes two above a sub without one, even at the
  start of a block, and above `sub {` starting a line in a list: name
  such a closure in a variable first.
- **A closure run for each value reads `$_[0]`, without a signature,**
  as Iain decided on 2026-11-16, as DBIx-Squirrel did the same day:
  the steps that our stages, sources and sinks return, which the
  pipeline calls once for each value. A comment says why, so no one
  puts the signature back. A one-argument signature costs about 19 ns
  a call, and copying `$_[0]` into a `my` variable as much, so it's
  read where it's used; an empty `sub ()` costs about 6 ns more than
  `sub`. Measured that day, the canned stages and sinks cost 15 to 30
  ns a value less, 2 to 4%. Nothing is lost: only the pipeline calls
  a step, so the signature's count of arguments guarded nothing, and
  `$_[0]` aliases a value the step loop holds itself, which the
  step's result replaces. A closure that hands the value to its
  caller's code, such as `take_if`'s test or `peek`'s block, keeps
  its signature, so a block that changes its argument can't change
  what's passed on. Flushes, ends and other subs keep their
  signatures, and so do the docs' examples, as users copy them.
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
- **Tasks and messages for the other repositories,** and the rules for
  writing them, are in [docs/claude/sessions.md](docs/claude/sessions.md).

Why: planned work survives between sessions in the open, where Iain
reviews it like any other change, and a release never carries an
unfinished list.

## The roadmap and change records

`ROADMAP.md` holds what Ekorn-Pipeline means to do, each item named by
an id such as `2026-0001`, and `docs/changes/` a record of each planned
change, its decisions and what happened. An item's questions are
settled before work on it starts, and an item leaves the roadmap in the
commit that ships it. The rules are in
[docs/claude/roadmap.md](docs/claude/roadmap.md).

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
  history is published, it can't be taken back. So a commit of docs,
  tests or a message, here or in another repository's `TODO.md`, is
  scanned before it's pushed, with `gitleaks dir --redact --exit-code 1`
  on what it changed, judged by its exit status; a git-ignored
  `cover_db/` can show a finding that isn't in history. A full commit
  hash beside one of gitleaks' rule names can look like a secret too.
  If one reaches published history anyway, it's listed by its
  fingerprint in a `.gitleaksignore`, with a comment saying why, as
  Text-Redact-Secrets does (its 2026-0001's D14), rather than history
  rewritten; Iain decides each.
