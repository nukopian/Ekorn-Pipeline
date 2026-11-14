# Maintaining

How Ekorn-Pipeline is kept: its branches, its releases to CPAN, and the
git and GitHub work done by hand. It's for whoever maintains it, which
is now Iain and Claude. Every command can be pasted as it stands. The
few that need a value say so on the line before, and set it in a
variable on their first line.

It's kept the same way as
[DBIx-Squirrel](https://github.com/nukopian/DBIx-Squirrel/blob/develop/docs/MAINTAINING.md),
where its code began. Minilla builds the distribution, and a release
goes to CPAN.

The working copy is `~/Git/github.com/nukopian/Ekorn-Pipeline`. Perl
commands run in the project's perlbrew library, named on each command
so they don't depend on the default Perl. [CLAUDE.md](../CLAUDE.md#perl)
lists the libraries.

## Branches

- `develop` is where work happens. Every commit goes there, and CI runs
  on every push to it.
- `main` is the latest release, and nothing else. It moves only at a
  release, by a fast-forward to `develop`, and carries the release's
  tag. The first was v0.1.1, on 2026-11-08. Visitors to GitHub see
  `main`, so its README describes what CPAN installs.
- There are no feature branches for now: changes are made one at a
  time. An experiment may have a branch, named for its roadmap item's
  id, as below.
- `TODO.md`, when there is one, lists work planned for a later session.
  It's committed on `develop` and gone before a release, so it never
  reaches `main` ([CLAUDE.md](../CLAUDE.md#planned-work) has the rules).
- [ROADMAP.md](../ROADMAP.md) lists what the project means to do, each
  item with an id such as 2026-0001. [docs/changes/](changes/README.md)
  keeps a record of each planned change. Both are public, on `main`,
  but not in the CPAN tarball
  ([CLAUDE.md](../CLAUDE.md#the-roadmap) has the rules).
- A branch for a roadmap item, when there is one, is named for its id,
  as `experiment/2026-0004-pipeline-as-a-stage`. The exception was
  `pipeline-experimental`, shared with DBIx-Squirrel, which has a
  branch of the same name: it carried roadmap 2026-0014 and the items
  after it, with `TODO.md`, until it merged into `develop` on
  2026-11-13 (roadmap 2026-0025). Its last commit with the design,
  `docs/design/`, is tagged `archive/pipeline-experimental`.

`main` is protected on GitHub. Pushes to it need signed commits, a
linear history (no merge commits) and CI passing on every job. It
can't be force-pushed or deleted, by admins either. To see the
settings:

```sh
gh api repos/nukopian/Ekorn-Pipeline/branches/main/protection --jq '{signatures: .required_signatures.enabled, linear: .required_linear_history.enabled, checks: .required_status_checks.contexts, force_push: .allow_force_pushes.enabled, admins: .enforce_admins.enabled}'
```

### A fresh clone

The settings that sign commits are in the working copy's own
`.git/config`, not the global one, so a fresh clone needs them before
its first commit. Then switch to `develop`, and install the
dependencies, including the maintainers' tools, and Minilla, which
builds the distribution. Minilla isn't in `cpanfile`, so installing
from `cpanfile` shows that the distribution needs nothing else:

```sh
cd ~/Git/github.com/nukopian/Ekorn-Pipeline
git config user.name nukopian
git config user.email nukopian@users.noreply.github.com
git config user.signingkey /Users/icampbell/.ssh/github_nukopian_noreply_rsa.pub
git config gpg.format ssh
git config gpg.ssh.allowedsignersfile '~/.config/git/allowed_signers'
git config commit.gpgsign true
git fetch origin
git switch develop
git pull --ff-only
perlbrew exec --with perl-5.36.3@ekorn-pipeline cpanm --installdeps --with-develop .
perlbrew exec --with perl-5.36.3@ekorn-pipeline cpanm Minilla
```

Last, set up direnv, so that a shell in the working copy uses the
project's library. Without it, a command run there that doesn't name
the library gets the default Perl and its modules. The `.envrc` is
git-ignored, so each clone writes its own. direnv loads it once it's
allowed:

```sh
cat > ~/Git/github.com/nukopian/Ekorn-Pipeline/.envrc <<'EOF'
unset PERL5LIB
source /Users/icampbell/perl5/perlbrew/etc/bashrc
perlbrew use perl-5.36.3@ekorn-pipeline
EOF
direnv allow ~/Git/github.com/nukopian/Ekorn-Pipeline
```

The commands in this guide still name the library, so they work
whether direnv has loaded it or not.

## Every commit

Run these first, and check that each one succeeds. Don't pipe them
through `tail` or `grep` to judge them: a pipe's exit status is the
last command's, which hides a failure. perlcritic and the perltidy
loop are CI's style check, and run on the newest Perl, as it does:
Perl::Critic knows a Perl's builtins from that Perl, so a sub named for
a newer keyword passes on 5.36. The loop prints a diff for each file
perltidy would change.

```sh
cd ~/Git/github.com/nukopian/Ekorn-Pipeline
perlbrew exec --with perl-5.36.3@ekorn-pipeline yath test -L
perlbrew exec --with perl-5.44.0@ekorn-pipeline perlcritic lib
for f in $(git ls-files 'lib/*.pm' 't/*.t' 'xt/*.t'); do perlbrew exec --quiet --with perl-5.44.0@ekorn-pipeline perltidy "$f" | diff -u "$f" -; done
```

To run the tests on every Perl CI covers, each in its own library:

```sh
cd ~/Git/github.com/nukopian/Ekorn-Pipeline
for p in perl-5.36.3 perl-5.38.5 perl-5.40.5 perl-5.42.3 perl-5.44.0; do perlbrew exec --quiet --with "${p}@ekorn-pipeline" yath test || echo "FAILED on ${p}"; done
```

After a change to the code, check its coverage too, as CI does.
`scripts/coverage` runs the tests under Devel::Cover, from an empty
`cover_db`. It prints each floor (set at the top of the script) beside
what the tests reached, and fails if the coverage of `lib/` falls
below any of them. New code comes with tests that keep coverage above
the floors. When coverage rises, raise the floors to just under it.
Lower one only with the reason in the commit message.

```sh
perlbrew exec --with perl-5.36.3@ekorn-pipeline ~/Git/github.com/nukopian/Ekorn-Pipeline/scripts/coverage
```

To see which lines and branches the tests miss, after it has run:

```sh
cd ~/Git/github.com/nukopian/Ekorn-Pipeline
perlbrew exec --with perl-5.36.3@ekorn-pipeline cover -report text -select_re '^lib/'
```

`Build.PL`, `META.json` and `README.md` are generated, and committed so
that `cpanm` can install from GitHub. After a change to `cpanfile`,
`minil.toml`, `README.pod` or the main module's POD, generate them
again. Commit what changes with the change that caused it:

```sh
cd ~/Git/github.com/nukopian/Ekorn-Pipeline
perlbrew exec --with perl-5.36.3@ekorn-pipeline minil build
git status --short
```

Minilla gets the branch for `README.md`'s CI badge from GitHub, with
`git remote show origin`. If GitHub can't be reached, it writes
`master` instead, and the badge breaks. Before committing, check that
this prints `branch=main`:

```sh
head -1 ~/Git/github.com/nukopian/Ekorn-Pipeline/README.md | grep -o 'branch=[a-z]*'
```

If it prints `branch=master`, put `main` back:

```sh
sed -i '' '1s/branch=master/branch=main/' ~/Git/github.com/nukopian/Ekorn-Pipeline/README.md
```

The manuals, `lib/Ekorn/Pipeline/Manual/Reference.pod` and
`HowTo.pod`, are generated too. `scripts/manuals` makes them from
`docs/REFERENCE.md` and `docs/HOWTO.md`, so that MetaCPAN lists the
reference and the how-to with the modules (change record 2026-0005).
After a change to either Markdown file, generate them again and commit
them with it. `xt/manuals.t`, which CI runs, fails if they don't match
the Markdown. The script converts only the Markdown the docs use, and
refuses anything else, naming it. If Minilla's spelling test flags a
word in a manual, add it to the Markdown as
`<!-- stopwords: word another -->`.

```sh
cd ~/Git/github.com/nukopian/Ekorn-Pipeline
perlbrew exec --with perl-5.36.3@ekorn-pipeline scripts/manuals
git status --short
```

Commits are signed, and use conventional prefixes (`feat:`, `fix:`,
`docs:`, `test:`, `ci:`, `refactor:`, `style:`, `chore:`). They say
why as well as what. To check the signatures of the last ten (`G` is
good, `N` is none):

```sh
git log --format='%h %G? %s' -10
```

Add what changed for users to `Changes` under Unreleased, in the same
commit. A change that ships a roadmap item ends its line with the
item's id, as "(roadmap 2026-0001)". It also names the item in the
entry's precis, and takes it off [ROADMAP.md](../ROADMAP.md).

## A trial release

A trial puts a version on CPAN for CPAN Testers to test, on platforms
CI doesn't cover, such as Windows and the BSDs. CPAN doesn't index it,
so `cpanm Ekorn::Pipeline` still installs the last release, and
DBIx::Squirrel's range doesn't take it. There's no tag and no GitHub
release, `main` doesn't move, and `Changes` keeps its Unreleased
heading.

What makes it a trial is the tarball's name: PAUSE treats one ending
`-TRIAL` as a trial. That's all `minil release --trial` does, and
`minil dist` has no `--trial`, so we rename the tarball by hand. The
`META.json` inside still says `"release_status" : "stable"`, as it
would from `minil release --trial`. PAUSE and MetaCPAN go by the name:
v0.1.0-TRIAL and v0.1.1-TRIAL went up this way, and MetaCPAN lists
both as developer releases.

The release uses the version of its last trial: v0.1.1 followed
v0.1.1-TRIAL, as PAUSE takes the two names as different files. It
never takes the same file name twice, though, so a second trial needs
a new version. A change to code or tests after a trial moves the
version on, as v0.1.0's trial was followed by v0.1.1's.

A change that touches only POD or documentation needs no new trial,
as Iain decided on 2026-11-08, since CPAN Testers test code, not
prose. Check the POD with `podchecker`, and say in the release's
commit that it differs from the trial in its documentation.

Don't use an underscore version, such as `v0.3.0_1`, for a trial of
v0.3.0. `version.pm` reads it as v0.3.1, so it would rank above the
release it was a trial of. DBIx-Squirrel decided this on 2026-11-06,
and the same holds here.

The commands below are for v0.3.0's trial. For another version, change
the first line of each.

1. **Check `develop`:** CI is green on its last commit, the working
   tree is clean, and the history has no secrets, since the tarball is
   published.

   ```sh
   cd ~/Git/github.com/nukopian/Ekorn-Pipeline
   git switch develop
   git pull --ff-only
   git status --short
   gh run list --branch develop --limit 1
   gitleaks git --redact --no-banner .
   ```

   Unlike a release, a trial doesn't wait for `TODO.md` to go:
   `minil.toml` leaves it out of the tarball, and `main` doesn't move.
   But a task that changes code is done first, or the trial tests
   something other than what's released.

2. **Set the version,** unless the main module has it already. For
   v0.3.0's first trial it says v0.2.0, so it's set. `minil prepare`
   writes it into the main module, and regenerates `META.json`,
   `Build.PL` and `README.md`:

   ```sh
   v=v0.3.0
   cd ~/Git/github.com/nukopian/Ekorn-Pipeline
   perlbrew exec --with perl-5.36.3@ekorn-pipeline minil prepare "$v" </dev/null
   git status --short
   ```

   Commit what changed as `chore: version v0.3.0, for a trial`, push,
   and wait for CI to pass on the commit before going on. `Changes`
   isn't touched: the trial has no entry of its own.

3. **Build the tarball, and check its tests passed.**
   `--skip-prepare` builds from the files as committed, as a release
   does from its tag:

   ```sh
   v=v0.3.0
   cd ~/Git/github.com/nukopian/Ekorn-Pipeline
   perlbrew exec --with perl-5.36.3@ekorn-pipeline minil dist --skip-prepare > "$TMPDIR/dist-$v.log" 2>&1
   grep '^Result:' "$TMPDIR/dist-$v.log"
   tar -xOzf "Ekorn-Pipeline-$v.tar.gz" "Ekorn-Pipeline-$v/META.json" | jq -r .version
   git status --short
   ```

   It must print `Result: PASS`, then the version: `minil dist` exits
   0, and writes the tarball, even when the tests fail. On a failure,
   remove the tarball, fix the problem on `develop`, and start again.
   `git status` should print nothing, as git ignores the tarball.

   The build also runs Minilla's own tests, which CI doesn't, among
   them a POD spelling test. A word it doesn't know, but that's right,
   goes in the POD's `=for stopwords` line, or, for the manuals, in the
   `<!-- stopwords: ... -->` comment at the top of the Markdown, which
   `scripts/manuals` copies.

4. **Rename it, and upload it.** `cpan-upload` reads the PAUSE account
   from `~/.pause`:

   ```sh
   v=v0.3.0
   cd ~/Git/github.com/nukopian/Ekorn-Pipeline
   mv "Ekorn-Pipeline-$v.tar.gz" "Ekorn-Pipeline-$v-TRIAL.tar.gz"
   perlbrew exec --with perl-5.36.3@ekorn-pipeline cpan-upload "Ekorn-Pipeline-$v-TRIAL.tar.gz"
   rm "Ekorn-Pipeline-$v-TRIAL.tar.gz"
   ```

5. **Check that CPAN has it, as a trial.** PAUSE emails when it has
   the upload, usually within the hour. Then MetaCPAN lists it, and
   `developer` says it's a trial:

   ```sh
   curl -sSf https://fastapi.metacpan.org/v1/release/versions/Ekorn-Pipeline | jq -r '.releases[] | "\(.name) \(.maturity) \(.status) \(.date)"'
   ```

   The first line should be `Ekorn-Pipeline-v0.3.0-TRIAL developer cpan`,
   and v0.2.0's should still say `latest`.

6. **Tell DBIx-Squirrel,** with a message in its `TODO.md`, as
   CLAUDE.md's Planned work says: which trial is on CPAN, and that
   `cpanm --dev Ekorn::Pipeline` installs it, if it wants to test
   against it. It needs no work of its own, so it's a message, not a
   task; the task to move its range comes with the release.

7. **Read the reports,** as they come in over the next few days. The
   first command counts each version's reports by grade; the second
   lists those that didn't pass, with a link to each:

   ```sh
   curl -sSf https://api.cpantesters.org/v3/summary/Ekorn-Pipeline | jq -r 'group_by(.version)[] | group_by(.grade)[] | "\(.[0].version) \(.[0].grade): \(length)"'
   curl -sSf https://api.cpantesters.org/v3/summary/Ekorn-Pipeline | jq -r '.[] | select(.grade != "pass") | "\(.version) \(.grade) \(.osname) perl \(.perl) https://www.cpantesters.org/cpan/report/\(.guid)"'
   ```

   A failure is fixed on `develop`, and a new trial uploaded, as
   v0.3.1, from step 2, before the release. An `na` from a Perl older
   than 5.36 is expected, and needs nothing.

8. **Release it,** once the reports are in and clean, as
   [Making a release](#making-a-release) says, with the trial's
   version. Its step 2's `minil prepare` then changes nothing, as the
   version is already set.

## Making a release

A release is a version on CPAN, plus a signed, annotated tag on `main`
with a GitHub release for it. Versions are dotted, as in `v0.1.0`, in
the main module's `$VERSION`, the tag and the tarball's name alike.
Claude asks before tagging.

DBIx::Squirrel requires `>= v0.2.0, < v0.3.0`, so choose the version
by what changed since the last release (CLAUDE.md has the rule). A fix
or an addition moves the last number, as in v0.2.1. A change of
behaviour, or a public name dropped or renamed, moves the middle
number, as in v0.3.0. That needs a task for DBIx-Squirrel, to test it
and move its range.

Releases don't use `minil release`, which makes its own commit and an
unsigned tag, and pushes both. `minil prepare` sets the version,
`minil dist` builds the tarball, and we do the git steps.

1. **Check `develop`:** CI is green on its last commit, there's no
   `TODO.md`, and the history has no secrets.

   ```sh
   cd ~/Git/github.com/nukopian/Ekorn-Pipeline
   git switch develop
   git pull --ff-only
   gh run list --branch develop --limit 1
   if [ -e TODO.md ]; then cat TODO.md; else echo "no TODO.md"; fi
   gitleaks git --redact --no-banner .
   ```

   If `TODO.md` is there, its tasks come first. Do them, or move them
   where CLAUDE.md says, and delete the file before going on.

2. **Set the version.** `minil prepare` writes it into the main module,
   and regenerates `META.json`, `Build.PL` and `README.md`. Set the
   version on the first line:

   ```sh
   v=v0.1.0
   cd ~/Git/github.com/nukopian/Ekorn-Pipeline
   perlbrew exec --with perl-5.36.3@ekorn-pipeline minil prepare "$v" </dev/null
   git status --short
   ```

3. **Turn Unreleased into the release** in [Changes](../Changes):

   - Rename the heading to the version and date, as `v0.1.0 2026-11-07`.
   - Start the entry with a sentence that sums it up; it becomes the
     tag's title. Then give the precis of the roadmap items it ships,
     by id.
   - Add an empty Unreleased above it.
   - Mark each shipped item's record "shipped in" the version.

   The entry's lines stay indented by four spaces:

   ```text
   Unreleased

   v0.1.0 2026-11-07

       The pipeline from DBIx-Squirrel v2.0.2, on its own, so that any
       function can take stages from its caller.

       - Requires Perl 5.36 or later.
   ```

   Commit it with the version (`chore: release v0.1.0`), push, and wait
   for CI.

4. **Write the tag message from the entry,** and read it. The entry,
   without its indent, is also the GitHub release's notes. The tag
   message is the same, with the version in front. An empty file means
   the heading doesn't match the version. Set the version on the first
   line:

   ```sh
   v=v0.1.0
   cd ~/Git/github.com/nukopian/Ekorn-Pipeline
   v=$v perl -0777 -ne 'print "$1\n" =~ s/^    //mgr if /^\Q$ENV{v}\E [^\n]*\n\n(.*?)\n*(?=^\S|\z)/ms' Changes > "$TMPDIR/notes-$v.txt"
   sed "1s/^/$v: /" "$TMPDIR/notes-$v.txt" > "$TMPDIR/tag-$v.txt"
   cat "$TMPDIR/tag-$v.txt"
   ```

5. **Move `main` and tag it.** First check that every check run on the
   commit has completed successfully. `gh run watch` can report a run
   as passed while one of its jobs is still marked in progress, and
   `main`'s protection refuses the push until it isn't. This lists each
   check once, from `develop`'s push:

   ```sh
   cd ~/Git/github.com/nukopian/Ekorn-Pipeline
   gh api "repos/nukopian/Ekorn-Pipeline/commits/$(git rev-parse develop)/check-runs" --jq '.check_runs[] | "\(.name) \(.status) \(.conclusion)"'
   ```

   Every line should end `completed success`. If one doesn't, see
   [When something goes wrong](#when-something-goes-wrong). Then merge.
   It's a fast-forward, so `main` gets exactly the commits CI tested on
   `develop`, with their signatures. Set the version on the first
   line:

   ```sh
   v=v0.1.0
   git switch main
   git pull --ff-only
   git merge --ff-only develop
   git tag -s "$v" -F "$TMPDIR/tag-$v.txt"
   git push origin main "$v"
   gh release create "$v" --verify-tag --title "$(git tag -l --format='%(contents:subject)' "$v")" --notes-file "$TMPDIR/notes-$v.txt"
   git switch develop
   ```

   `--verify-tag` stops `gh` making a tag of its own if the push didn't
   happen. If the merge says it can't fast-forward, `main` has a commit
   `develop` doesn't. Stop and find out why. Don't make a merge commit.

6. **Build the tarball and upload it to CPAN,** from the tag.
   `minil dist` runs the tests again on the built distribution first.
   `cpan-upload` reads the PAUSE account from `~/.pause`. Set the version
   on the first line:

   ```sh
   v=v0.1.0
   cd ~/Git/github.com/nukopian/Ekorn-Pipeline
   git switch --detach "$v"
   perlbrew exec --with perl-5.36.3@ekorn-pipeline minil dist --skip-prepare > "$TMPDIR/dist-$v.log" 2>&1
   grep '^Result:' "$TMPDIR/dist-$v.log"
   ```

   It must print `Result: PASS`. `minil dist` exits 0, and writes the
   tarball, even when the tests fail, so read this line, not its exit
   status. On a failure, the log says which test failed. Remove the
   tarball, fix the problem on `develop`, and start again. If it
   passed, upload:

   ```sh
   v=v0.1.0
   cd ~/Git/github.com/nukopian/Ekorn-Pipeline
   perlbrew exec --with perl-5.36.3@ekorn-pipeline cpan-upload "Ekorn-Pipeline-$v.tar.gz"
   git switch develop
   rm "Ekorn-Pipeline-$v.tar.gz"
   ```

7. **Check that CPAN has it.** PAUSE emails when it has indexed the
   upload, usually within the hour. The first upload also registers the
   `Ekorn::Pipeline` namespace to Iain's PAUSE account. Then MetaCPAN
   shows the new version, with the repository's URL:

   ```sh
   curl -sSf https://fastapi.metacpan.org/v1/release/Ekorn-Pipeline | jq -r '"\(.name) \(.date) \(.resources.repository.web)"'
   ```

8. **Tell DBIx-Squirrel.** Add a task to its `TODO.md` saying which
   version is on CPAN, as CLAUDE.md's Planned work says. The task goes
   on its `develop`, or on its experimental branch while one carries
   its work (as `ekorn-pipeline` did until 2026-11-08). Then read its
   other tasks for any waiting on this release, and tell Iain which can
   now be done. Nothing else tells its session.

## Changing the CI matrix

`main` requires each CI job by name, such as `perl 5.44 (macos-26)`.
A new Perl or a new runner means changing the required checks to
match. Otherwise `main` waits for a check that never reports, and
can't move. After the new jobs have passed once on `develop`, change
the list below to the jobs' names, and run it. It replaces the whole
list, so keep `secrets`, `style` and `coverage` in it. It's a GitHub
setting, so Iain runs it, or says Claude may:

```sh
gh api --method PATCH repos/nukopian/Ekorn-Pipeline/branches/main/protection/required_status_checks --silent --input - <<'EOF'
{
  "strict": false,
  "checks": [
    {"context": "secrets", "app_id": 15368},
    {"context": "perl 5.36 (ubuntu-24.04)", "app_id": 15368},
    {"context": "perl 5.38 (ubuntu-24.04)", "app_id": 15368},
    {"context": "perl 5.40 (ubuntu-24.04)", "app_id": 15368},
    {"context": "perl 5.42 (ubuntu-24.04)", "app_id": 15368},
    {"context": "perl 5.44 (ubuntu-24.04)", "app_id": 15368},
    {"context": "perl 5.44 (macos-26)", "app_id": 15368},
    {"context": "style", "app_id": 15368},
    {"context": "coverage", "app_id": 15368}
  ]
}
EOF
gh api repos/nukopian/Ekorn-Pipeline/branches/main/protection --jq .required_status_checks.contexts
```

`15368` is GitHub Actions, so only a job in this repository's
workflows can satisfy a check. When the floor moves up, from Perl 5.36
to 5.40 for `try`/`catch`, the oldest jobs go from both the matrix and
this list.

## When something goes wrong

- **A bad commit pushed to `develop`:** fix it in a new commit, or revert
  it with `git revert`, and push. Don't force-push: Iain reviews what's
  pushed, and a rewrite changes it under him.
- **A mistake in a pushed commit message:** leave it, and correct it in
  the next release's entry in `Changes`.
- **A bad release:** never move or delete a published tag, and never
  reuse a version. PAUSE refuses a file name it has had before, even
  one deleted since. Release a fixed version instead. To stop the bad
  one being installed meanwhile, delete it from CPAN on PAUSE
  (`https://pause.perl.org`, "Delete Files"). It goes after three days,
  and stays on BackPAN.
- **An upload refused or lost:** if PAUSE never had the file, run
  `cpan-upload` again with the same tarball. If it did, the version is
  spent: release the next one.
- **`cpan-upload --dry-run` prints the PAUSE password,** with or without
  `--verbose`. Don't run it where the output is shared or logged.
- **A commit made on `main` by mistake,** before it's pushed: move it to
  `develop`, and put `main` back. Do this only if `main` hasn't been pushed
  since:

  ```sh
  git switch develop
  git cherry-pick main
  git branch -f main origin/main
  ```

- **A push to `main` refused:** the protection did its job. Push to
  `develop` instead, or, at a release, wait for CI to pass on the commit.
- **No run for a push:** look at the repository's Actions tab. Until
  2026-11-08 no push started a run. The tab said Actions wasn't
  enabled, though `gh api repos/nukopian/Ekorn-Pipeline/actions/permissions`
  said it was, and enabling it in the tab fixed it. To test a commit
  meanwhile, start a run by hand, then watch it:

  ```sh
  cd ~/Git/github.com/nukopian/Ekorn-Pipeline
  gh workflow run test.yml --ref develop
  gh run list --branch develop --limit 1
  ```

- **A check stuck "in progress"** after all its steps passed: GitHub never
  marked it complete. Re-run that job alone. This finds every unfinished
  check on `develop`'s commit and re-runs it:

  ```sh
  cd ~/Git/github.com/nukopian/Ekorn-Pipeline
  gh api "repos/nukopian/Ekorn-Pipeline/commits/$(git rev-parse develop)/check-runs" --jq '.check_runs[] | select(.status != "completed") | .details_url' | sed -E 's|.*/runs/([0-9]+)/job/([0-9]+).*|\1 \2|' | while read run job; do gh run rerun "$run" --job "$job"; done
  ```

  Then check the check runs again, as in step 5.
- **`main` refused after the tag went up:** `git push origin main "$v"`
  sends both, so the tag can be published while `main` is refused.
  Leave the tag alone: it points at the right commit. Fix the check,
  then push `main` to the tagged commit, make the release, and go on
  with step 6. Set the version on the first line:

  ```sh
  v=v0.1.0
  cd ~/Git/github.com/nukopian/Ekorn-Pipeline
  git switch main
  git merge --ff-only "$v"
  git push origin main
  gh release create "$v" --verify-tag --title "$(git tag -l --format='%(contents:subject)' "$v")" --notes-file "$TMPDIR/notes-$v.txt"
  git switch develop
  ```

## Security checks

- **gitleaks** scans the whole history for secrets on every push, in
  `test.yml`'s `secrets` job, and by hand before a tag (step 1).
- **Secret scanning and push protection** are on: push protection
  refuses a push with a recognised secret in it, before gitleaks would
  see it.
- **Dependabot alerts** are on. **Dependabot security updates** are off
  on purpose: they open pull requests against `main`, which moves only
  at a release. Dependabot doesn't read a `cpanfile`, so its alerts
  cover the workflow's actions, not the Perl dependencies.
- **Private vulnerability reporting** is on, so a security problem can
  be reported without an open issue.

To see the settings, and any open alerts:

```sh
gh api repos/nukopian/Ekorn-Pipeline --jq '.security_and_analysis | to_entries[] | "\(.key) \(.value.status)"'
gh api repos/nukopian/Ekorn-Pipeline/vulnerability-alerts --silent && echo "Dependabot alerts on"
gh api repos/nukopian/Ekorn-Pipeline/dependabot/alerts --jq '.[] | select(.state == "open") | "\(.number) \(.security_advisory.summary)"'
gh api repos/nukopian/Ekorn-Pipeline/secret-scanning/alerts --jq '.[] | select(.state == "open") | "\(.number) \(.secret_type_display_name)"'
```

## Tools

- The project's perlbrew library, with Minilla and the dependencies in
  `cpanfile`, including yath, Perl::Critic, Perl::Tidy,
  CPAN::Uploader, and Pod::Markdown::Github, which `minil.toml` names
  to write `README.md`'s code in ```` ```perl ```` fences.
- `gh`, `gitleaks` and `jq`.
- For the PDFs, `pandoc` and Prince. `scripts/readme-pdf.sh` builds a
  PDF of the README, the how-to, the reference and this guide, for
  reading offline. The PDFs are git-ignored.
