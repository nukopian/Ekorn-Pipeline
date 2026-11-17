# Ekorn-Pipeline's neighbours

Part of the working rules in [CLAUDE.md](../../CLAUDE.md), kept here
as only some tasks need them: Ekorn's contract with DBIx-Squirrel and Text-Redact-Secrets, and what a change or a release must keep for them.

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
- **DBIx::Squirrel uses Ekorn as it is,** as Iain decided on
  2026-11-12, as any other package would: it delivers sources, sinks
  and stages that keep Ekorn's protocols, and runs them in Ekorn's own
  pipelines. It subclasses, wraps and remakes nothing of Ekorn's, and
  Ekorn changes nothing for it, adding only what any package could
  use. Ekorn's contract with other packages is its protocols, not its
  classes, so a change to a protocol is a v0.4.0. This replaces the
  rule of 2026-11-11 that DBIx::Squirrel's modules were subclasses of
  Ekorn's, which tied the two designs together; the design (roadmap
  2026-0022), principle 2 and its 17.3, has why. It's in
  `docs/design/` on the tag `archive/pipeline-experimental`, not on
  `develop`.
- **Factories are words, and live in a module of words,** as Iain
  decided on 2026-11-11: a short, keyword-like function that makes one
  of Ekorn's types, such as `pipeline`, `source {...}` or `gather`, is
  syntax, not behaviour, so it goes in
  Ekorn::Pipeline::Factories, not in the class it makes. Each is one
  line over a class method, and lives there only: Ekorn::Pipeline
  doesn't export `pipeline` too (2026-0022's D30). Record 2026-0021.
- **Keep the switch in view.** The messages, the order stages run in,
  and what Stop and Gather do are DBIx-Squirrel's behaviour too. A
  change to them is a change DBIx-Squirrel will take on when it
  switches, so say so in the commit message and in `Changes`.
- **The version says what DBIx-Squirrel can take.** DBIx::Squirrel
  requires `>= v0.3.0, < v0.4.0`, as it moved the range on 2026-11-14,
  for its v3.0.0, the first built on Ekorn as it is. The range began at
  `>= v0.1.1, < v0.2.0`, as Iain decided on 2026-11-07, and
  DBIx-Squirrel raised it on 2026-11-08, and to `>= v0.2.0, < v0.3.0`
  on 2026-11-10. So a v0.3.x reaches its users with no release of
  DBIx::Squirrel's. A v0.3.x only fixes or adds. A release that changes
  behaviour users' stages depend on (when a `gather` stage is made,
  what a stop does, the order end functions run in, where errors are
  reported, the messages), or drops or renames a public name, is
  v0.4.0, and comes with a task handed to DBIx-Squirrel, which tests it
  and moves the range. DBIx::Squirrel imports some of Ekorn's modules
  by name and some whole. By name: `Stop` and `gather`; Flow's `take`,
  `drop`, `take_first`, `take_last`, `take_single`, `take_while`,
  `drop_while`, `take_if` and `drop_if`; Batch's `batch` and
  `collect`; Taps' `peek`, `count_into` and `dump_to`; and Factories'
  `pipeline`, `stage`, `source`, `generator`, `yield`, `sink_one` and
  `sink_many`. Whole, by `:all`, in its Tooling: Sources, Sinks and
  JSON, so a name added to one of those three reaches its users at
  once, and must suit them. A name added anywhere else doesn't appear
  there until it's added to its list.
- **A name added to Ekorn's Tooling costs DBIx-Squirrel's CI, not its
  users,** as it settled on 2026-11-17, from v3.1.1 (Ekorn 2026-0048's
  wash-up). Its `xt/ekorn-tooling.t` checks, tag by tag, that its
  Tooling holds every name Ekorn's does, so a new one turns its CI red
  until it lists the name, which it means to: send it a message with
  each name added. Its `t/`, which installs run, checks only that each
  name both export is one sub, and that importing both `:all`s into
  one package warns of nothing. So a name both export must stay the
  same sub, and a name Ekorn's Tooling adds mustn't clash with one of
  DBIx::Squirrel's; either would fail its installed releases, so
  either goes to Iain before it's made. Its v3.1.0, on CPAN, still
  checks every name in `t/`, and fails with any name added to Ekorn's
  Tooling: so a release that adds one waits until v3.1.1 is on CPAN.

## Ekorn-Pipeline and Text-Redact-Secrets

Text::Redact::Secrets finds secrets in text by gitleaks' rules, and
redacts them. It was designed here, as roadmap 2026-0037, and moved on
2026-11-15 to a repository of its own,
`~/Git/github.com/nukopian/Text-Redact-Secrets`, as its 2026-0001, as
Iain decided (2026-0037's D1): new rules reach users with no release of
Ekorn's. Its work, and its design from now on, are its session's.

- **Ekorn uses it as any package would,** and doesn't require it:
  `dump_to` redacts with it whenever it's installed and passes a
  self-test (roadmap 2026-0038), calling its `redact`. That's its
  contract with Ekorn; a change to it comes here as a message first.
- **2026-0038 waits on its first release,** which its session tells
  this one with a task in `TODO.md`. A later release that only brings
  new rules from gitleaks needs nothing here.

