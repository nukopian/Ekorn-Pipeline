# TODO

## Pick up roadmap 2026-0058: a check on the sections DBIx-Squirrel links to

**What:** settle the item's two open decisions with Iain, then move it
to Now and do it: an author test in `xt/` that fails if a heading of
`docs/REFERENCE.md` or `docs/HOWTO.md` that DBIx-Squirrel's documents
link to goes, or if our reference's index stops linking one of the
thirteen names DBIx-Squirrel's index uses to the section it expects.

**Why:** Iain wants Ekorn's ties to DBIx-Squirrel kept in view. This
one shows up only after a release today: DBIx-Squirrel's CI checks
seven of its sixteen links, reading our installed manual, and nothing
checks the rest.

**Files:** [the change record](docs/changes/2026-0058-sections-dbix-squirrel-links-to.md),
which lists the sixteen anchors and the decisions; `ROADMAP.md`;
`xt/reference-index.t`, whose `anchor` and `index_entries` subs show
how our headings and index links are read; a new test in `xt/`, or a
subtest added to that one; and `docs/claude/neighbours.md`, whose
bullet on DBIx-Squirrel's reference links should name the test.
DBIx-Squirrel's links can be listed afresh from its `origin/main`,
reading only, with `git show origin/main:docs/REFERENCE.md` and
grepping for `Ekorn-Pipeline/blob/main/`; its `xt/reference-index.t`
says which thirteen names its index links.

**Done when:** the test passes, and fails when one of the headings is
renamed in a scratch copy; `yath test -L` and `scripts/coverage` pass;
the item ships, leaving `ROADMAP.md`, with a line in `Changes` only if
Iain wants one, as the test isn't in the distribution; and this task
is removed in that commit, with the file.
