# 2026-0038. Secrets redacted by dump_to

**Status:** open

**Decisions:** D1 settled: redacts by itself when Text::Redact::Secrets
is installed and passes a self-test, and croaks if it doesn't. D2
settled: a package global, `local`ised, stops it when true. D3
settled: `$DumpSecrets`. D4 settled: looked for once, at the first
dump. D5 settled: the text redacted, not the value. D6 settled: a
v0.3.x, and a message to DBIx-Squirrel. None open.

**Origin:** roadmap, added 2026-11-15, split from 2026-0036

**Depends on:** Text-Redact-Secrets 2026-0001, its first release;
2026-0037 until 2026-11-15, when it moved there

## Background

A dump is often written to a log, and a value holding a password, a
token or a DSN leaks it there. Text-Redact-Secrets 2026-0001, at first
this repository's 2026-0037, makes Text::Redact::Secrets, a module of
gitleaks' rules with a function that puts `*REDACTED*` in place of each
secret in a string. `dump_to`, in Ekorn::Pipeline::Stages::Taps, writes
each value with Data::Dumper, `local`ising `$Data::Dumper::Indent`,
`Sortkeys` and `Terse` as it does. DBIx::Squirrel imports `dump_to` by
name.

## Decisions

- [x] **D1.** Opt in or out? **Redaction is on by itself whenever
  Text::Redact::Secrets is installed, with nothing to ask for it,**
  Iain decided on 2026-11-15: the right thing with the least friction.
  Without the module, `dump_to` is as it was, so it adds no
  dependency.

  **Refined the same day: installed isn't enough; it must work.** The
  first time a dump is written, once Text::Redact::Secrets has loaded
  (D4), `dump_to` runs a self-test: it redacts a few known secrets and
  checks each is gone. The result is kept for the rest of the process,
  as D4's answer is, so the test costs one dump's worth, once. If the
  module fails to load, or fails the test, `dump_to` croaks, saying so,
  and that a `local $Ekorn::Pipeline::Stages::Taps::DumpSecrets = 1`
  dumps without redacting. A redactor that's there but doesn't work
  would otherwise let secrets through as if they were safe, and a dump
  that's meant to be redacted is better not written than written in
  full; turning redaction off is then asked for, as D2 has it, not
  fallen into. With `$DumpSecrets` true, neither the load nor the test
  is tried. This settles D4's "reported": it croaks. The message is one
  of Ekorn's, raised with `croakf`, and goes in Taps' DIAGNOSTICS.
- [x] **D2.** How is it turned off? **By a package global, true to stop
  redacting, `local`ised as Data::Dumper's are,** Iain decided on
  2026-11-15: what's unsafe is what's asked for, and only for as long
  as it's needed, `local` putting it back after. It's read as each
  value is dumped, not when the stage is made, so a `local` around a
  run, or inside a stage before it, takes effect.
- [x] **D3.** The global's name?
  **`$Ekorn::Pipeline::Stages::Taps::DumpSecrets`,** Iain decided on
  2026-11-15, as he proposed, over the `ShowSecrets` first recommended:
  it's bound to the tap it governs, read as "`dump_to`: dump secrets",
  where `ShowSecrets` could be taken for all of Taps, or the pipeline.
  It still names, as Data::Dumper's globals do, what setting it does,
  so code that sets it says plainly that it writes secrets out. It's
  `dump_to`'s alone: a tap that redacts later takes a switch of its
  own, so turning off one doesn't turn off the other.
- [x] **D4.** How `dump_to` looks for the module, and when? **By
  `require` in an `eval`, once, the first time a dump is written, the
  answer kept for the rest of the process; a module found but failing
  to load is reported, by a croak (D1), not taken as absent,** Iain
  decided on 2026-11-15, as recommended. Each time would cost every
  dump; at load, it would load the module for code that never dumps.
  A module that's there but broken, taken as absent, would let secrets
  through without a word, the failure D1 is there to prevent.
- [x] **D5.** The dumped text redacted, or the value? **The text,**
  Iain decided on 2026-11-15, as recommended. Text::Redact::Secrets
  works on strings; Data::Dumper's text keeps each key beside its
  value, which gitleaks' rules look for; and the value isn't copied or
  touched, so what goes on down the pipeline is what came in.
- [x] **D6.** Which version, and what DBIx-Squirrel is told? **A
  v0.3.x, with a message to DBIx-Squirrel,** Iain decided on
  2026-11-15, as recommended. It adds: nothing changes unless a new
  module is installed, and what changes then is only what's written to
  a dump, not what a stage sees, nor any message there was before. The
  croak D1 adds is a new message, not a change to one. DBIx-Squirrel
  imports `dump_to`, so it's sent a message saying what its users'
  dumps will do once Text::Redact::Secrets is installed, the croak if
  it's broken, and `$DumpSecrets`.
