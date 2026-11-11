# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0021.

Items come in four groups:

- **Now:** being worked on, each with a paragraph and a link to its
  [change record](docs/changes/README.md); never more than three, so
  that it stays a queue;
- **Next:** decided, but not started: what, why, and when it's done;
- **Later:** meant to be done, but not yet planned, in a line or two;
- **Ideas:** might be done, or never; kept so they aren't lost, in a
  line or two, newest last.

Now, Next and Later put the most useful first.

Each item has an id, its year and a serial, such as 2026-0001. The year
is when the item was added, and the serial counts from 0001, starting
again each year. An id is given when the item is added, whichever group
it goes in, and is kept as the item moves, so that 2026-0001 means the
same item in a commit message years later. It names the item's change
record, its line in Changes ("(roadmap 2026-0001)") and any branch for
it. The line above gives the last id allocated.

Each item has a size too, a guess at how much work it is, as a T-shirt
size and its story points: XS 1, S 2, M 3 and L 5. Sizes compare items
with each other; they aren't a measure of time. An item bigger than L
is split into items that aren't, each saying what it was split from.
An item that can't be done before another says so ("Depends on:"), and
is never in a group ahead of it.

An item whose questions aren't all settled says so, and its record
lists them. Work on it starts only once each is settled, or moved to
another item or task.

When an item ships, it leaves here for Changes. An item that's
dropped is deleted, and the commit that drops it names its id.

## Now

Nothing yet.

## Next

### 2026-0021. Ekorn::Pipeline::Factories

**Size:** M (3)

A module of words, Ekorn::Pipeline::Factories, holding the short,
keyword-like functions that make Ekorn's types, starting with
`pipeline`, moved there from Ekorn::Pipeline, and `gather`; each one
line over a class method, so the class keeps no `import` of its own.
Why: `pipeline` is syntax, not behaviour, the first of a family
2026-0015 adds to, and in the class it needed `import` tricks to make
a subclass. DBIx::Squirrel's words go in DBIx::Squirrel::Factories.
Done when the module, the class method, their tests and docs are in,
with coverage above the floors, and DBIx-Squirrel has a message saying
how to write its own. Two questions are open: see its
[record](docs/changes/2026-0021-factories.md).

### 2026-0010. Named pipelines at compile time

**Size:** S (2)

**Depends on:** 2026-0011

A module like DBIx::Squirrel::Sugar for pipelines:
`use Ekorn::Pipeline::Sugar pipeline => {name => [@stages]}` names
pipelines as the program compiles, with 2026-0011's names, and gives
the package a function of each name, which runs values through it,
taking more stages as a pipeline after them. Why: a pipeline used in
several places needn't be kept in a variable or wrapped in a sub.
Done when the module, its tests and its docs are in, with coverage
above the floors. Its questions are settled: see its
[record](docs/changes/2026-0010-named-pipelines.md).

## Later

Nothing yet.

## Ideas

An idea is a numbered heading, the date it was added, its size, and a
line or two on what and why. Each is kept, promoted to Later or Next
with its id, or dropped, as Iain decides.

### 2026-0012. A named pipeline with a source of its own

**Added:** 2026-11-10. **Size:** S (2). **Depends on:** 2026-0010

A definition that starts with a source, a function making the values,
as a statement makes its rows, so its function, called with no values,
still has something to give, and takes stages as a pipeline given
last: `recent(pipeline(take(5)))`. Moved from 2026-0010's D2, where a
function and `pipeline(@stages)` were found to cover it for now, and
how a source is told from a first stage, such as by a key,
`recent => [source => sub {...}, @stages]`, is still to settle.

### 2026-0013. A named pipeline named in a stage's error

**Added:** 2026-11-10. **Size:** S (2). **Depends on:** 2026-0011

When a stage in a named pipeline dies, the message gives its place,
such as `#2.3`, but not the pipeline's name, which would make it
easier to find. A `name` getter, left free by 2026-0011's D3, would
give it. It changes a message, so it's a v0.3.0, with a task for
DBIx-Squirrel to change its tests and its copies of the message.
Suggested in a message from DBIx-Squirrel, 2026-11-10 (DBIx-Squirrel
60dd1af8f11b7661b4e47decadf9885d3e22a2d3).

### 2026-0014. An end that always runs, told how the run ended

**Added:** 2026-11-10. **Size:** M (3)

A lifecycle hook in the core: an object given as a stage or a source
can have two methods, called at the start of each run and at its end,
the end told whether the run was `done`, `stopped` or `died`. So a
source can close its file however a run ends, `file_lines($path) |
take(5)` included, which no caller can do today; and a sink can commit
or roll back. An object without them behaves as now, so it only adds.
With it, `is_source`, for `iterator` to take a source with a set-up
and an end. From DBIx-Squirrel's message of 2026-11-10, layer 0 of
four, each opt-in, for a grammar of sources, stages, gathers and
sinks; built, as it suggests, on an experimental branch shared with
DBIx-Squirrel, `pipeline-experimental` in both, with a line in both
CLAUDE.md files saying how.
The message, whole:
`git show 7cf473408d73add0eda3eae5ca3e0be6afaaf122:TODO.md`.

### 2026-0015. Block factories: source, stage, sink, and gather's new form

**Added:** 2026-11-10. **Size:** M (3). **Depends on:** 2026-0014,
2026-0021

Factories in Ekorn::Pipeline::Factories (2026-0021), not a module of
their own, as Iain decided on 2026-11-11: once planned as
`Ekorn::Pipeline::Blocks`, but `pipeline`, in the same family, takes no
block. Factories taking a block, optionally
followed by `step {...}` and `end {...}`, as Try::Tiny's `try` is
by `catch`: the block alone is the step, and with a `step` after it,
the set-up, whose result `step` and `end` are given. `end` always
runs, and what it returns counts only when the run was `done`. Each
makes a blessed code reference, so it works wherever a code reference
does. `gather`'s list form stays as it is; the factory can tell the
new form by a `step` or `end` after its block, rather than by what the
block returns. Layer 1 of DBIx-Squirrel's message.
Each factory makes its type with a class method, so a subclass, such
as DBIx::Squirrel's, can wrap its own (2026-0020). `step` and `end` are
exported only under a tag, with the block factories, so a short name
like `end` is never imported alone (2026-0021).
The message, whole:
`git show 7cf473408d73add0eda3eae5ca3e0be6afaaf122:TODO.md`.

### 2026-0016. Sources that come with Perl

**Added:** 2026-11-10. **Size:** M (3). **Depends on:** 2026-0015

`Ekorn::Pipeline::Sources`, needing nothing from CPAN: `from`,
`from_array`, `lines`, `file_lines`, `counter`, `unfold`, `cycle`,
`concat`, `interleave`, and a hash's pairs, under a name that doesn't
clash with List::Util's `pairs`. Nothing exported by default. Those
needing CPAN, such as JSON or CSV, go in add-on distributions of
Ekorn's, as they need no database. Layer 2 of DBIx-Squirrel's message.
A change of scope, toward a stream library, to weigh against the
README's pitch.
The message, whole:
`git show 7cf473408d73add0eda3eae5ca3e0be6afaaf122:TODO.md`.

### 2026-0017. Sinks that come with Perl

**Added:** 2026-11-10. **Size:** M (3). **Depends on:** 2026-0015

`Ekorn::Pipeline::Sinks`, with names that can't clash with Perl's or
List::Util's: `to_array`, `into`, `to_hash`, `group_by`, `count`,
`first_value`, `last_value`, `any_value`, `every_value`, `fold`,
`joined`, `to_file` and `for_each`; those that can, stop the pull
early. Nothing exported by default. Layer 2 of DBIx-Squirrel's
message, and the type DBIx-Squirrel 2026-0012, a database as a sink,
`insert_into`, depends on. A change of scope, as 2026-0016 is.
The message, whole:
`git show 7cf473408d73add0eda3eae5ca3e0be6afaaf122:TODO.md`.

### 2026-0018. Operators: `|`, `|=` and `@{}`

**Added:** 2026-11-10. **Size:** S (2).
**Depends on:** 2026-0016, 2026-0017

`Ekorn::Pipeline::Operators`: `$src | take(10) | count`, on the typed
objects of 2026-0015 and the chains `|` makes, never on a pipeline
made with `new`. An operator returns one scalar, so a sink gives an
array reference, or `@{}` drains a source. Between two plain code
references, `|` silently ORs their addresses, so the docs must say
loudly that every stage in a chain is a `stage {...}`. Layer 3 of
DBIx-Squirrel's message.
An operator makes the class of its operand, never a class it names,
so DBIx::Squirrel's pipelines chain as its own (2026-0020).
The message, whole:
`git show 7cf473408d73add0eda3eae5ca3e0be6afaaf122:TODO.md`.

### 2026-0019. A strict is_stage

**Added:** 2026-11-10. **Size:** S (2). **Depends on:** 2026-0015

An `is_stage` that accepts only Stage objects and pipelines, as a
function or an argument, so a function whose values can be code
references can take stages without 2026-0011's pipeline-last
convention, provided its callers write `stage {...}`. Made the
default, it would change behaviour: a v0.3.0, with a task for
DBIx-Squirrel. Weigh against 2026-0011's D2, which answers the same
need with plain subs. From DBIx-Squirrel's message, part 4.
The message, whole:
`git show 7cf473408d73add0eda3eae5ca3e0be6afaaf122:TODO.md`.
