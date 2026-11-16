# The roadmap and change records

Part of the working rules in [CLAUDE.md](../../CLAUDE.md), kept here
as only some tasks need them: adding, moving, starting, shipping or dropping a roadmap item, and keeping its record.

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

