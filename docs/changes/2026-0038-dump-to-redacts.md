# 2026-0038. Secrets redacted by dump_to

**Status:** open

**Decisions:** D1 settled: redacts by itself when Text::Redact::Secrets
is installed. D2 settled: a package global, `local`ised, stops it when
true. D3 open: the global's name. D4 open: when the module is looked
for. D5 open: the text redacted, not the value. D6 open: a v0.3.x, and
the message to DBIx-Squirrel.

**Origin:** roadmap, added 2026-11-15, split from 2026-0036

**Depends on:** 2026-0037

## Background

A dump is often written to a log, and a value holding a password, a
token or a DSN leaks it there. 2026-0037 makes Text::Redact::Secrets,
a module of gitleaks' rules with a function that puts `*REDACTED*` in
place of each secret in a string. `dump_to`, in
Ekorn::Pipeline::Stages::Taps, writes each value with Data::Dumper,
`local`ising `$Data::Dumper::Indent`, `Sortkeys` and `Terse` as it
does. DBIx::Squirrel imports `dump_to` by name.

## Decisions

- [x] **D1.** Opt in or out? **Redaction is on by itself whenever
  Text::Redact::Secrets is installed, with nothing to ask for it,**
  Iain decided on 2026-11-15: the right thing with the least friction.
  Without the module, `dump_to` is as it was, so it adds no
  dependency.
- [x] **D2.** How is it turned off? **By a package global, true to stop
  redacting, `local`ised as Data::Dumper's are,** Iain decided on
  2026-11-15: what's unsafe is what's asked for, and only for as long
  as it's needed, `local` putting it back after. It's read as each
  value is dumped, not when the stage is made, so a `local` around a
  run, or inside a stage before it, takes effect.
- [ ] **D3.** The global's name? Recommended:
  `$Ekorn::Pipeline::Stages::Taps::ShowSecrets`, named, as Data::Dumper
  names its globals, for what setting it does, so code that sets it
  says plainly that it shows secrets.
- [ ] **D4.** How `dump_to` looks for the module, and when?
  Recommended: `require` in an `eval`, once, the first time a dump is
  written, its answer kept for the rest of the process; not each time,
  which costs, nor at load, which would load the module for code that
  never dumps. A module found but failing to load is reported, not
  quietly taken as absent.
- [ ] **D5.** The dumped text redacted, or the value? Recommended: the
  text. Text::Redact::Secrets works on strings, Data::Dumper's text
  keeps each key beside its value, which gitleaks' rules look for, and
  the value isn't copied or touched, so what goes on down the pipeline
  is what came in.
- [ ] **D6.** Which version, and what DBIx-Squirrel is told?
  Recommended: a v0.3.x, as it adds: nothing changes unless a new
  module is installed, and what changes is only what's written to a
  dump, not what a stage sees or the messages. DBIx-Squirrel is sent a
  message, as it imports `dump_to`, saying what its users' dumps will
  do, and the global's name.
