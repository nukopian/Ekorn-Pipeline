# Tasks and messages between sessions

Part of the working rules in [CLAUDE.md](../../CLAUDE.md), kept here
as only some tasks need them: writing tasks and messages for DBIx-Squirrel's and Text-Redact-Secrets' sessions, and reading theirs.

## Planned work, continued

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
  and one name for the two sessions. Ekorn's merged into `develop` on
  2026-11-13 (roadmap 2026-0025, D4), so its work and `TODO.md` are on
  `develop` again, and DBIx-Squirrel's tasks and messages come there.
  DBIx-Squirrel's merged into its `develop` the same day, so tasks and
  messages for it go to its `develop` again. Never switch DBIx-Squirrel's
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
  way. Text-Redact-Secrets is the only other repository this one
  touches, in the same way: tasks and messages for it go in its
  `TODO.md`, on its `develop`, through a worktree at
  `/tmp/text-redact-secrets-todo`, with these commands with its name
  in place of DBIx-Squirrel's, and its tasks and messages come here.
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
- **A task or message never holds a secret whole, made-up or not,** as
  Iain decided on 2026-11-15: it's built from pieces, as a test's is,
  such as `join '', 'AKIA', 'MADEUP', ...`, or left out. One of
  Ekorn's messages quoted a test's made-up password whole, beside its
  key, and Text-Redact-Secrets' gitleaks scan then failed on every
  push, as history keeps it (Text-Redact-Secrets 2026-0001's D14).
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

