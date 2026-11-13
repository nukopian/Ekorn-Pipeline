# 2026-0014. The lifecycle: sources, stages, sinks and their ends

**Status:** in progress

**Decisions:** the design's (2026-0022, D1 to D70) settle it; D1, a
gather's message reworded for the flush and the end.

**Origin:** roadmap, added 2026-11-10, from DBIx-Squirrel's message
(DBIx-Squirrel 7cf473408d73add0eda3eae5ca3e0be6afaaf122), rewritten
from the design approved on 2026-11-13 (2026-0022)

**Started:** 2026-11-13

## Background

The design (`docs/design/`, 2026-0022) settles the lifecycle, and its
prototype, on `pipeline-experimental`, builds it, with the proofs of
its section 19 in `t/15-proofs.t`. What's left is to finish it: the
new modules' POD is a placeholder, coverage is below the floors, and
the published reference and how-to don't yet describe it.

## Decisions

The design's settle the item. Questions found in the work:

- [x] **D1. The gather message's "end function".** The message
  "Expected stage #%s, made with gather, to return a code reference or
  a pipeline, and optionally an end function" names the second thing a
  gather returns by v0.2.0's name; it's now the flush, and a third, the
  end, may follow. Reword it as "..., and optionally a flush and an
  end", as the stage's message has it, in v0.3.0 (DBIx-Squirrel's tests
  and copies of the message told), or keep it. **Reworded,** as Iain
  decided on 2026-11-13: the message should name what a gather may
  return now. DBIx-Squirrel is handed a task, as it copies the message.

## The plan

As the roadmap gave it on 2026-11-13:

> The core of the design approved on 2026-11-13 (2026-0022), finished
> from its prototype on `pipeline-experimental`: a run made of a
> source, stages and sinks, each made for the run by its role method
> (`ekorn_source`, `ekorn_stage`, `ekorn_sink_one`, `ekorn_sink_many`),
> with a flush and an end told how the run ended, `done`, `stopped` or
> `died`; Ekorn's types as Elements; and the Iterator, with `ended`,
> `finish`, `all`, `first` and `single`. Done when its code has its
> POD, its tests hold the design's proofs (section 19) and keep
> coverage above the floors, and the reference and how-to take in its
> share of the drafts, with `Changes`.

Steps: the POD of Ekorn::Pipeline's run, Element, Source, Stage,
Sink and Iterator, from the draft reference; tests for what coverage
shows missed; the reference's and how-to's sections on runs, ends and
iterators, from the drafts; `Changes`, its line ending "(roadmap
2026-0014)".

## What happened

**The POD, 2026-11-13.** Ekorn::Pipeline, Element, Source, Stage, Sink,
Iterator and Gather are documented from the draft reference, each
method with POD, so Pod::Coverage finds none missing in them. Pipeline
gains a section, Runs and how they end, with `is_sink`, `run_context`,
and the new messages in DIAGNOSTICS; Gather's "end function" is its
flush, with a section on ends. Each example was run. Two links point
ahead, to the reference's Delivering parts for Ekorn, which this item's
reference step adds. Pipeline's sections on named pipelines through a
subclass are left for 2026-0021, which removes them.

Coverage after it is still below the floors, as Factories, Sources,
Sinks and Operators, which are other items', have placeholder POD, and
the branches and conditions untested in the core are the next step.

**The core's tests, 2026-11-13.** `t/16-run.t` tests the run's edges
the POD describes: what each set-up may return, a set-up, a source and
an end that die, with an error object or a message, a source that
stops, a stop in a flushed value, a sink whose flush stops, a part of
a package's own, Sink's subclasses, and the Iterator made with `new`.
Ekorn::Pipeline, Element, Source, Stage, Sink, Iterator and Gather now
have every statement, branch, condition, subroutine and POD covered.

What the tests found:

- **Stage took an object called as a code reference, but a run of it
  croaked,** as `ekorn_stage` gave the object, not code. Its code is
  now found once, as the stage is made, and `code` still gives the
  object.
- **Three conditions could never be false:** the run's check that its
  source was done before ending, as every caller checks first; that a
  run ended from outside hadn't died, before saying values were
  dropped, as a run that dies drops them itself; and an iterator's
  check that it had a way to end its run, which `new` always gives.
  They're gone, the run's two with a comment where they were.
- **A stage of a stop in a flushed value is told `stopped`** if a value
  from an earlier flush was still waiting for it, as its input was cut
  short: the design's rule, which a first guess in the test had wrong.

Coverage of `lib/` as a whole is still below the floors for branches
and POD, all in Factories, Sources, Sinks and Operators, which are
2026-0021's, 2026-0016's, 2026-0017's and 2026-0018's.

**The reference and the how-to, 2026-11-13.** The reference gains
Runs and how they end (made for a run, how a run ends, flushes and
ends, and sections for Source, Sink, the Iterator, and Stage and
Element), `is_sink` and `run_context`, and Delivering parts for Ekorn,
less its `|` for your sources, which is 2026-0018's. Terms, `new`,
calling a pipeline, `iterator`, `is_stage`, `ending`, what a stop does,
Gather, errors, writing stages, the diagnostics, the exports and the
modules follow: a gather's *end function* is its flush, and it has an
end. The how-to gains, under Pulling values one at a time, "Close a
file however the run ends", "Don't leave a file open when you stop
reading early" and "Read every value, or only the first", with `ended`
in "Know when an iterator is done"; under Gathering values, "Clean up
however the run ends" and "Write a sink of your own, and act on how
the run ended"; and, for stage authors, "Deliver sources, sinks and
stages for Ekorn". Each example was run.

Their examples make sources and sinks with the classes,
`Ekorn::Pipeline::Source->new` and `Ekorn::Pipeline::Sink->new_sink_one`,
not Factories' words, which are 2026-0021's; it can change them to the
words. The README is left for 2026-0025, which rewrites it.

Found on the way: `stages` returns Elements, as the design settles
(DESIGN.md's table of changes), but the reference and the POD still
said its list could go to a function taking only code references.
Both now say a code reference comes back as a Stage, and that v0.2.0
gave the code references themselves.
