# Planned work

## 1. Make pipeline() build the subclass it's called through

**From:** DBIx-Squirrel's session, 2026-11-11 (DBIx-Squirrel
b42762959e467286e7406c2f86c4b944a9b101a6)
**Waiting on:** nothing

**What:** `pipeline` always makes an `Ekorn::Pipeline`, as it calls
`__PACKAGE__->new` (`lib/Ekorn/Pipeline.pm`, at 4eb7fa3). So
DBIx::Squirrel can't give its users a `pipeline` that makes
`DBIx::Squirrel::Pipeline`, its subclass, where it changes how its
pipelines behave. It can't wrap it either: `pipeline` looks names up
in the package that called it, so a wrapper's own package would be
searched, and the lookup, `_resolved`, is private. `named` already
gets this right, calling `new` on its invocant.

Iain decided on 2026-11-11 that Ekorn should make the subclass
(DBIx-Squirrel 2026-0009 D1). How is Ekorn's to design: for instance,
`pipeline` callable as a class method, `Subclass->pipeline(...)`, or
a way for a subclass to export a `pipeline` of its own that still
resolves names in its user's package.

Otherwise it works with DBIx::Squirrel. Against 4eb7fa3, all its tests
pass (26 files, 1,585 assertions), and a script found that
`pipeline('names', take(2))` works as a stage of `iterate` and `pipe`,
that a bind value `'names'` stays a bind value, that
`DBIx::Squirrel::Pipeline->named(...)` makes the subclass, and that an
unqualified name dies in another package, as D5 has it.

**Done when:** a subclass can offer its users a `pipeline` that makes
the subclass and resolves names in the user's package, with a test of
that, on `pipeline-experimental`; and a message here says how, so
DBIx-Squirrel's 2026-0009 can use it.
