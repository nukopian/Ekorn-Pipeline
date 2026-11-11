# Ekorn::Pipeline and DBIx::Squirrel: one design

**Status:** a draft for review, roadmap 2026-0022. Nothing here is
decided until Iain approves it. Where it says "settled", it means
decided earlier and carried in; where it says "proposed", it's this
design's suggestion; open questions are numbered **Q1** and on, and
listed together in section 16. Section 17 gives the reasons for each
settled decision, and what was weighed against it.

**Read with:** [REFERENCE.md](REFERENCE.md) and [HOWTO.md](HOWTO.md)
in this folder, drafts of the sections the reference and the how-to
would gain, written as they'd read.

**For:** Iain, and DBIx-Squirrel's session, which reviews it as
Ekorn's first user and sends its view as messages.

## Contents

1. [Why this document](#1-why-this-document)
2. [What it's for](#2-what-its-for)
3. [Principles](#3-principles)
4. [The concepts](#4-the-concepts)
5. [Runs, and how they end](#5-runs-and-how-they-end)
6. [Making things: classes and words](#6-making-things-classes-and-words)
7. [Names](#7-names)
8. [Ready-made parts](#8-ready-made-parts)
9. [Operators](#9-operators)
10. [Sugar: names at compile time](#10-sugar-names-at-compile-time)
11. [The modules](#11-the-modules)
12. [DBIx::Squirrel on top](#12-dbixsquirrel-on-top)
13. [Compatibility and versions](#13-compatibility-and-versions)
14. [What's built already](#14-whats-built-already)
15. [The order things depend on](#15-the-order-things-depend-on)
16. [Open questions](#16-open-questions)
17. [Decisions, and what was weighed](#17-decisions-and-what-was-weighed)
18. [Where each roadmap item lands](#18-where-each-roadmap-item-lands)

## 1. Why this document

Until now, the work was split into roadmap items, here and in
DBIx-Squirrel, each designed on its own. The decisions were sound one
at a time, but they kept turning out to bite later: one name registry
for every class, Ekorn's Sugar making DBIx::Squirrel's pipelines, a
facade's `import` losing `pipeline`, and `pipeline` itself living in
the class. Each was found after it was built.

This document describes everything planned in both repositories as one
design, so that its parts can be checked against each other before
anything more is built. Only once it's approved is it split into
items again.

## 2. What it's for

Ekorn::Pipeline's purpose, from its README: **stages for any function;
let the caller finish the job.** A function that hands out values
takes stages from its caller and runs each value through them, so its
author needn't write an option for every use, and its caller needn't
write loops and flags around the call. The test of any feature: does
it let callers do more without authors writing more?

The plans below go further, toward a small library of streams:
sources that make values, sinks that consume them, and an operator to
join them. That's a change of scope, and the first question for Iain
is whether it's wanted (**Q1**). The design keeps it opt-in, so that
someone using only stages sees no change.

DBIx::Squirrel is Ekorn's first user: a wrapper of the DBI whose
statements hand out rows through stages. It's where most of these
ideas came from, and where they'll be tried first.

## 3. Principles

These were settled before this document, except where it says
"proposed". Every part of the design below follows from them, and
section 17 gives the reasons for each.

1. **Opt-in, in layers.** The core is extended only as far as the
   layers above need. Each layer comes in a module of its own, so
   someone who never `use`s it sees no change.
2. **Ekorn::X is the ancestor of DBIx::Squirrel::X.** Ekorn::Pipeline
   is the pipeline without a database; DBIx::Squirrel::Pipeline is its
   descendant, a subclass, and the same holds for every DBIx::Squirrel
   module with an Ekorn analogue. So Ekorn never names its own class
   where it makes something, but the class it was reached through.
3. **The streams don't cross.** What's made or named in
   DBIx::Squirrel's namespace stays there. DBIx::Squirrel inherits from
   Ekorn, one way; Ekorn never holds, finds or makes DBIx::Squirrel's
   things for it.
4. **Factories are words, in a module of words.** A short,
   keyword-like function that makes one of the types, such as
   `pipeline` or `source {...}`, is syntax, not behaviour. It lives in
   Ekorn::Pipeline::Factories, as one line over a class method, not in
   the class it makes. DBIx::Squirrel's own words, making its classes,
   live in DBIx::Squirrel::Factories.
5. **Names are resolved where the user writes them.** Only a word the
   user calls reads names, in the user's own package. `new` reads
   none, as it's called by code in between: Pipes, DBIx::Squirrel's
   `iterate`, any function taking stages from its caller.
6. **Every type is a code reference.** Each is a blessed code
   reference, so it works wherever a code reference does, and every
   function taking stages today takes the new types unchanged.
7. **State made for a run lives in lexicals.** Whatever needs fresh
   state for each run is written as `gather` is today: its block runs
   at the start of the run, declares the state with `my`, and returns
   closures that share it. One shape for every type that needs it.
8. **Nothing that works today changes,** unless a release says so and
   moves the middle number, as v0.3.0; and DBIx::Squirrel, whose range
   is `>= v0.2.0, < v0.3.0`, signs off first.

## 4. The concepts

### 4.1 Values

Anything a stage is given or returns. `undef`, 0 and the empty string
are values. A value never means "the end"; an empty list does.

### 4.2 The six types

| Type | What it does | Called with | Returns | Today |
|---|---|---|---|---|
| **Stage** | turns one value into none, one or several | one value | a list | any code reference; `take(5)` |
| **Gather** | a stage with state for the run, and an end that lets out what it held | one value | a list | `gather {...}`, `batch`, `collect` |
| **Pipeline** | a list of stages, run in order | values (push), or a source (pull) | a list, or an iterator | `Ekorn::Pipeline->new` |
| **Source** | gives values when pulled, until it gives none | nothing | the next value or values, or an empty list | a code reference given to `iterator` |
| **Sink** | consumes every value, and gives one result | (as the last stage) each value | nothing, until its end gives the result | nothing yet: a call in list context, `all`, `count` |
| **Stop** | ends a run early, from inside a stage | values to carry on | (thrown) | `Stop(...)` |

How they relate:

- **A pipeline stands for its stages.** Given where a stage goes, its
  stages are spliced in (settled, 2026-0004).
- **Neither a stage nor a source is a kind of the other.** A source is
  called with nothing, until it gives an empty list. A stage is called
  with a value, and an empty list means "drop this value". Each would
  misread the other's empty list, so they're two classes with no
  inheritance between them.
- **A pipeline with a source in front is a source.**
  `$pipeline->iterator($source)` already makes one: pulled, it gives
  the values that come out of the stages.
- **A gather is a stage** whose state lasts a run, with an end that can
  let out what it held.
- **A sink is the last stage of a pipeline,** whose end gives the
  run's one result (proposed, **Q8**). Pushed values in, one result
  out; or, pulled from a source, an iterator that hands out one value,
  the result.
- **A stop** ends the run from inside a stage; the values it carries
  go on through the stages after it.

### 4.3 Push and pull

A pipeline runs two ways (settled):

- **Push:** called with values, `$p->(@values)`, it runs each through
  and returns what comes out. The values are the source.
- **Pull:** given a source, `$p->iterator($source)`, it returns an
  iterator that hands out one result per call, pulling from the source
  only as it needs. Once a stage stops, the source isn't called again.

The pull is what makes a function that reads a file or a database read
no more than its caller wants. Sources, sinks and their ends exist to
make the pull safe as well as lazy: a file opened by a source is
closed however the pull ends.

## 5. Runs, and how they end

This is the one change only the core can make (2026-0014), and
everything that opens something rests on it.

### 5.1 A run

A run is one call of a pipeline with values, or one iterator made
from it (settled). Each run has its own state: two iterators of one
pipeline don't share a gather's batch, or a source's filehandle.

### 5.2 Made for a run

`gather` already makes a stage afresh for each run. Its block is the
set-up: it runs at the start of the run, declares the run's state as
lexicals, and returns the step, and optionally an end, as closures
sharing that state:

```perl
sub batches_of ($size) {
    return gather {
        my @batch;    # this run's
        return (
            sub ($x) { push @batch, $x; @batch == $size ? [splice @batch] : () },
            sub ()   { @batch ? [@batch] : () },
        );
    };
}
```

**Proposed:** sources and sinks are made for a run the same way, with
the words `source` and `sink` (section 6). Each block is a set-up,
returning a step and an end:

```perl
sub file_lines ($path) {
    return source {
        open my $fh, '<', $path or die "Can't read $path: $!\n";
        return (
            sub ()     { my $line = readline $fh; defined $line ? $line =~ s( \n \z )()xr : () },
            sub ($how) { close $fh },
        );
    };
}
```

So there's one shape to learn, state lives in plain lexicals, and the
core needs one protocol: an object it's given as a stage or a source
can be **made for a run**, by a method the core calls at the start of
each run, which returns the step and the end (the method's name is
**Q2**; here, `for_run`). An object without the method is used as it
is, as every code reference is today.

### 5.3 How a run ends

A run ends in one of three ways, and each part of it is told which,
**from where it stands** (proposed, **Q3**):

| The run | The source, and stages up to and including the one that stopped | Stages after the one that stopped |
|---|---|---|
| ran out of values | `done` | `done` |
| was stopped by a stage | `stopped` | `done` |
| had a stage or an end die | `died` | `died` |

That's how a stop works already. After a stop, the stages after the
one that stopped go on, and their ends are called with the values from
before the stop and the ones it carries: for them, the stream ended
normally. The stage that stopped, and those before it, are cut off:
their ends aren't called.

So `file_lines($path) | take(5) | count` means: the source,
`file_lines`, is told `stopped`, and closes its file; `count`, after
`take(5)`, is told `done`, and gives 5, the result.

### 5.4 What an end does

**A source's and a sink's end** (proposed, **Q4**):

- **always runs, once,** however the run ended, and is given how it
  ended, `done`, `stopped` or `died`, as its argument;
- **counts only when it's `done`:** a sink's end gives the result
  then. Told `stopped` or `died`, what it returns is dropped; it runs
  only to clean up, such as closing a file or rolling back. What a
  source's end returns is always dropped.
- **runs in order:** the stages' ends first, first stage first, as
  now, and **the source's end last**, after every stage has finished
  with what it gave (**Q5**);
- **after a die,** still runs, told `died`, and then the error is
  thrown again. An end that dies while the run is already dying
  doesn't hide the first error (**Q6**).

**A gather's end is unchanged.** It's called only when its stage's
stream ended normally: when the values ran out, or after a stop in a
stage before it. It's given no arguments, and what it returns goes on
through the stages after it.

### 5.5 A run that's abandoned

An iterator nobody finishes, such as `my($first) = $next->()` and
then nothing more, never runs out and is never stopped. Its source's
file would stay open until the program ends.

**Proposed (Q7):** `iterator` returns a blessed code reference (still
callable as `$next->()`, so nothing changes for its callers), whose
`DESTROY` ends the run, telling its source and sink `stopped`, if it
hasn't ended already. Perl calls `DESTROY` when the last reference
goes, which is prompt for a lexical iterator. During global
destruction its order isn't guaranteed, so an end mustn't rely on
other objects then.

### 5.6 What `ending` means

`Ekorn::Pipeline::ending()` is true while the values going through
the stages come from an end (settled, 2.0). It keeps that meaning.
DBIx::Squirrel's Context relies on it: a value from an end has no row
it came from.

## 6. Making things: classes and words

### 6.1 Classes and their constructors

Each type is a class, made by its constructor, a class method that
takes only real things (code references, pipelines), never names:

| Class | Constructor | Notes |
|---|---|---|
| `Ekorn::Pipeline` | `new(@stages)` | settled; strict: no names |
| `Ekorn::Pipeline::Stage` | `new($code)` | proposed; wraps the code given, never blesses it (**Q9**) |
| `Ekorn::Pipeline::Gather` | `new($setup)` | as `gather` makes today |
| `Ekorn::Pipeline::Source` | `new($setup)` | proposed; `$setup` returns the step and the end |
| `Ekorn::Pipeline::Sink` | `new($setup)` | proposed; `$setup` returns the step and the end |

And one more class method, the only one that reads names (settled in
2026-0021 as a class method taking the package; its name is **Q10**,
here `pipeline_in`):

```perl
Ekorn::Pipeline->pipeline_in($package, @stages)
```

It makes a pipeline of its invocant's class, with each name among the
stages looked up in `$package`, for its invocant's class (section 7).

### 6.2 The words: Ekorn::Pipeline::Factories

The words are the short forms users write, each one line over a
constructor (settled, 2026-0021):

| Word | Makes | Its block |
|---|---|---|
| `pipeline(@stages)` | a pipeline, its stages possibly names | (takes a list) |
| `stage {...}` | a Stage | the stage itself, called with each value |
| `gather {...}` | a Gather | a set-up, returning the step and, optionally, the end |
| `source {...}` | a Source | a set-up, returning the step and, optionally, the end |
| `sink {...}` | a Sink | a set-up, returning the step and the end |

The rule for the blocks: **a word for something made afresh for each
run takes a set-up; `stage` takes the stage itself.** A source with
nothing to open or close needs no word: any code reference is a
source, as today.

```perl
my $upper = stage { uc };

my $count = sink {
    my $n = 0;
    return (sub ($value) { $n++; return }, sub ($how) { $n });
};
```

Exports (settled, 2026-0021): nothing by default; each on request.
`gather` is exported here too, and stays in Ekorn::Pipeline::Gather as
well. `Stop` isn't a factory, and stays only in Ekorn::Pipeline::Stop.

### 6.3 Words versus ready-made parts

Two kinds of function make things, and they live apart:

- **Words** make one of the types from what the user writes:
  `pipeline`, `stage`, `gather`, `source`, `sink`. One word per type,
  in Ekorn::Pipeline::Factories.
- **Ready-made parts** are particular stages, sources and sinks, with
  a job of their own: `take(5)`, `file_lines($path)`, `count`. They
  live by topic, as the canned stages do now: Ekorn::Pipeline::Stages::*,
  ::Sources, ::Sinks. Each is built with a word or a constructor.

So a user asks "which word makes a source?" in one place, and "is
there a source for a file's lines?" in another.

## 7. Names

Settled in 2026-0011 and 2026-0020; carried in whole.

- **A name** is identifiers, as Perl's, joined by `::`: `clean`,
  `My::Module::clean`.
- **Two things decide which pipeline a name means.** The package it's
  in says whose it is: the package that called `named`, unless it's
  qualified. The class it was defined through says who can find it.
- **`named` defines one:** `Ekorn::Pipeline->named(clean => @stages)`
  makes a pipeline of its invocant's class; `$p->named('clean')` names
  one you have. A class can't define a name twice; naming the same
  pipeline again is no mistake. A name can't be removed.
- **A class sees its own names and its ancestors',** nearest first,
  never a subclass's. A subclass can override an ancestor's name for
  itself and its subclasses; the ancestor keeps its own.
- **A name is resolved when the pipeline is made,** and the pipeline
  it names is spliced in. A pipeline once made keeps what it found.
- **Only `pipeline` (through `pipeline_in`) and `named` read names.**
  `new` doesn't, and `is_stage` is false for a string, so a function
  that finds its stages with `is_stage` never takes a value such as
  `'clean'` for one.

Proposed: **names are for pipelines only, for now.** A pipeline may end
in a sink, and so can be named. Naming a source, a pipeline with a
source in front, is roadmap idea 2026-0012, left for later (**Q11**).

## 8. Ready-made parts

### 8.1 Stages (settled; one change proposed)

`take`, `drop`, `take_while`, `drop_while`, `batch`, `collect`,
`peek`, `count_into`, `dump_to`, in Ekorn::Pipeline::Stages::*.

Proposed: each returns an `Ekorn::Pipeline::Stage` (or Gather) object
rather than a plain code reference, so they work with the operators of
section 9. They stay code references, so everything taking them works
as now; only `ref` of one changes, from `CODE` to the class
(**Q12**).

### 8.2 Sources: Ekorn::Pipeline::Sources (2026-0016)

Using only what comes with Perl. Nothing exported by default.

| Source | Gives | Its end |
|---|---|---|
| `from_array(@values)` | the values given | none |
| `from_arrayref(\@array)` | an array's values, read as asked for | none |
| `from_fh($fh)` | a filehandle's lines, chomped | none: you opened it |
| `file_lines($path)` | a file's lines | closes the file, however the run ends |
| `counter($start, $step)` | 1, 2, 3 and on, without end | none |
| `unfold($seed, sub {...})` | a sub applied again and again, until it gives nothing | none |
| `cycle(@values)` | the values, round and round | none |
| `concat(@sources)` | each source in turn | ends each source it read |
| `interleave(@sources)` | one value from each source in turn | ends each source it read |
| `hash_pairs(\%hash)` | a hash's keys and values, as pairs | none |

`hash_pairs`, not `pairs`, which List::Util has (**Q13**).

### 8.3 Sinks: Ekorn::Pipeline::Sinks (2026-0017)

Names that can't clash with Perl's built-ins or List::Util's. Nothing
exported by default.

| Sink | Gives | Stops the pull early? |
|---|---|---|
| `to_array` | an array reference of every value | no |
| `into(\@array)` | pushes each value onto your array; gives how many | no |
| `to_hash(sub {...})` | a hash reference, keyed by what the sub gives | no |
| `group_by(sub {...})` | a hash of arrays | no |
| `count` | how many values there were | no |
| `first_value` | the first value | yes |
| `last_value` | the last value | no |
| `any_value(sub {...})` | true at the first value the sub is true of | yes |
| `every_value(sub {...})` | false at the first value the sub is false of | yes |
| `fold($init, sub {...})` | a running total, of any kind | no |
| `joined($separator)` | the values joined into one string | no |
| `to_file($path)` | writes each value as a line; gives how many | no; its end closes the file |
| `for_each(sub {...})` | calls the sub with each value; gives how many | no |

A sink that stops early is told `done`, as the stage that decided the
run had enough; the source and stages before it are told `stopped`.

## 9. Operators (2026-0018)

An opt-in layer, Ekorn::Pipeline::Operators, on the typed objects of
section 6 only:

```perl
my $clean = $trim | $lowercase | $dedupe;               # Stage | Stage: a pipeline
my $names = $src | take(10) | stage { $_->{name} };    # Source | Stage: a source
my $n     = $src | stage { $_->{name} } | count;       # Source | ... | Sink: the result
my @names = @{ $src | take(10) };                       # @{} drains a source
```

- **An operator makes the class of its operand,** never a class it
  names (settled with 2026-0020's rule), so DBIx::Squirrel's chain as
  its own.
- **Perl calls an overload only if one side is an object.** Between two
  plain code references, `|` silently ORs their addresses. The docs
  must say loudly: in a chain, every stage is a `stage {...}`, or a
  ready-made part, which section 8.1 makes objects.
- **An operator returns one scalar,** so a sink gives an array
  reference, or `@{}` drains a source.
- A pipeline made with `new` gets no operators: only the chains `|`
  makes, and the typed objects, do.

## 10. Sugar: names at compile time (2026-0010)

`Ekorn::Pipeline::Sugar` names pipelines as a program compiles, and
gives the package a function of each name, which runs values through
it:

```perl
use Ekorn::Pipeline::Sugar
    pipeline => {
        trimmed => [sub { s( \A \s+ | \s+ \z )()xgr }],
        clean   => ['trimmed', sub { length ? $_ : () }],
    };

my @out = clean(@raw);                        # values through clean
my @top = clean(@raw, pipeline(take(5)));     # and more stages, given last
```

Settled in 2026-0010's record:

- **A definition can name any other in the same `use`,** in a hash or
  an array of pairs; each is defined once the names it uses are, and a
  cycle croaks.
- **Names and clashes are checked exactly as DBIx::Squirrel::Sugar
  does,** so one program using both reads alike.
- **It makes only Ekorn::Pipelines.** DBIx::Squirrel's Sugar defines
  its own pipelines, with `DBIx::Squirrel::Pipeline->named`, rather
  than handing them to Ekorn's.
- `import_into($package, ...)` lets a module add to it for its caller.

Proposed: the helpers both Sugars need, which make nothing, such as
checking a name, installing a function, and ordering definitions with
a cycle check, are functions DBIx::Squirrel can call, in a module of
their own (**Q14**). That's DBIx-Squirrel's 2026-0011.

## 11. The modules

### 11.1 Ekorn

| Module | Layer | Gives | Exports |
|---|---|---|---|
| `Ekorn::Pipeline` | core | the class; `new`, `pipeline_in`, `named`, `iterator`, `stages`; the lifecycle (section 5) | `is_stage` (and `is_source`, **Q15**) on request |
| `Ekorn::Pipeline::Stop` | core | `Stop`, `throw` | `Stop` by default |
| `Ekorn::Pipeline::Gather` | core | the Gather class; `gather` | `gather` by default |
| `Ekorn::Pipeline::Errors` | core | `croakf`, `@INTERNAL` | `croakf` on request |
| `Ekorn::Pipeline::Pipes` | core | `pipe`, `tap`, `pipeline_class` for a class of your own | none: a parent class |
| `Ekorn::Pipeline::Stage`, `::Source`, `::Sink` | 1 | the classes | none |
| `Ekorn::Pipeline::Factories` | 1 | the words | on request |
| `Ekorn::Pipeline::Stages::Flow`, `::Batch`, `::Taps` | parts | canned stages | as now |
| `Ekorn::Pipeline::Sources`, `::Sinks` | 2 | ready-made sources and sinks | on request |
| `Ekorn::Pipeline::Sugar` | names | compile-time naming | its import list |
| `Ekorn::Pipeline::Operators` | 3 | `\|`, `\|=`, `@{}` on the types | none: loading it switches them on for the typed objects |

Each new module that croaks joins `@Ekorn::Pipeline::Errors::INTERNAL`,
so errors are reported at the caller's line.

### 11.2 DBIx::Squirrel

Its rule: `Ekorn::Pipeline::X` maps to `DBIx::Squirrel::X`. A facade
subclasses where DBIx::Squirrel changes behaviour, and only re-exports
where it doesn't.

| Module | Is | Today | Proposed |
|---|---|---|---|
| `DBIx::Squirrel::Pipeline` | subclass of Ekorn::Pipeline | facade, no code | unchanged: inherits `pipeline_in` and `named` |
| `DBIx::Squirrel::Factories` | its words | (new) | `pipeline` making its class; the other words re-exported from Ekorn's, unless it subclasses their types |
| `DBIx::Squirrel::Pipes` | subclass of Ekorn's Pipes | facade | overrides `pipeline_class`, so `$sth->pipe` makes its pipelines |
| `DBIx::Squirrel::Stop` | subclass of Ekorn's Stop | exports Ekorn's `Stop`, which throws Ekorn's class | its own one-line `Stop`, if its subclass should be thrown |
| `DBIx::Squirrel::Gather`, `::Stages::*` | re-exports | as now | as now, adding names it chooses |
| `DBIx::Squirrel::Stages::Rows` | its own | `pluck`, `as_hash` | unchanged |
| `DBIx::Squirrel::Iterator` | its own | statements' rows | a Source (section 12.3) |
| `DBIx::Squirrel::Sinks` | its own | (new) | `insert_into` (its 2026-0012) |
| `DBIx::Squirrel::Sugar` | its own | databases, statements | a `pipeline` key, defining its own (its 2026-0010) |

## 12. DBIx::Squirrel on top

From DBIx::Squirrel's code on its `pipeline-experimental`, as read on
2026-11-11.

### 12.1 How it uses Ekorn today

- **One place builds a pipeline:** `DBIx::Squirrel::Iterator`, as
  `DBIx::Squirrel::Pipeline->new(@stages)->iterator($source)`, its
  source a closure fetching rows in batches of 100. Nothing else calls
  `new`, `throw`, or catches a stop.
- **Stages are found with `is_stage`,** in `split_stages`
  (DBIx::Squirrel::Util), which takes trailing stages off a statement's
  arguments, leaving bind values. `is_stage` is false for strings, so a
  bind value never becomes a stage, names included.
- **`pipe` and `tap`** on database and statement handles come from
  Ekorn's Pipes, through its facade.
- **Context** tells stages which row a value came from, and uses
  `Ekorn::Pipeline::ending()` to give none for values from an end.
- **Its Sugar** defines databases and statements at compile time, with
  its own `install_sub` and `is_name`, and stores a statement's stages.
- **Its errors** add Ekorn's `@INTERNAL` to its own `@CARP_NOT` list.

### 12.2 Its words

`DBIx::Squirrel::Factories` gives its users `pipeline`, one line over
the class method it inherits:

```perl
sub pipeline (@stages) { DBIx::Squirrel::Pipeline->pipeline_in(scalar caller, @stages) }
```

So `$sth->iterate(pipeline('clean', take(5)))` makes a
DBIx::Squirrel::Pipeline, finding `clean` among DBIx::Squirrel's names
and Ekorn's, in the user's package. Words whose types it doesn't
subclass, such as `stage` or `sink`, it re-exports from Ekorn's
Factories (which words it offers is its choice, **Q16**).

### 12.3 Its iterator as a source

A statement is a natural source, made for a run like any other: its
set-up executes the statement, its step fetches, its end finishes the
statement handle. With section 5, a statement's rows read through
`take(5)` finish the handle when the stop comes, and an iterator
dropped half-read finishes it too.

How DBIx::Squirrel::Iterator becomes one is DBIx-Squirrel's to design
(**Q17**). It's a hash-based object today, with `next`, `all`,
`reset`, `single`, `count`, not a code reference, so it would either
offer a Source (say `$it->source`) or become callable. Its `reset` is
the set-up; its `_finish` the end.

### 12.4 A database as a sink

`insert_into($dbh, $table)`, in DBIx::Squirrel::Sinks (its 2026-0012):
its set-up prepares the INSERT and begins a transaction; its step
executes it for each value; its end commits if the run is `done`, and
rolls back if not, giving how many rows went in:

```perl
sub insert_into ($dbh, $table) {
    return sink {
        my $sth = $dbh->prepare(...);
        my $n   = 0;
        $dbh->begin_work;
        return (
            sub ($row) { $sth->execute(@$row); $n++; return },
            sub ($how) { $how eq 'done' ? $dbh->commit : $dbh->rollback; $n },
        );
    };
}
```

It needs Ekorn's Sink and section 5's ends. Which columns, how often to
commit, and what it gives back are DBIx-Squirrel's questions.

### 12.5 Its Sugar

A `pipeline` key in DBIx::Squirrel::Sugar (its 2026-0010) defines its
own pipelines, qualifying names with its caller's package, with
`DBIx::Squirrel::Pipeline->named`. Whether a statement's definition
can name a pipeline by a string, and how that's told from anything
else in a definition, is its question (**Q18**).

### 12.6 What could bite

Found by reading both sides together; each has an answer above or a
question below.

- `$sth->pipe(...)` makes an Ekorn::Pipeline unless DBIx::Squirrel's
  Pipes overrides `pipeline_class`.
- `Stop` from DBIx::Squirrel::Stop throws Ekorn's class.
- If `iterator` returns an object (section 5.5), DBIx::Squirrel's
  `$self->{next}->()` keeps working, as it's still a code reference.
- If the canned stages become objects (**Q12**), any test in
  DBIx::Squirrel comparing `ref` to `CODE` would fail.
- Its CI installs Ekorn from CPAN, and runs only on `main` and
  `develop`, so it can't test against Ekorn's `pipeline-experimental`
  yet (**Q19**).

## 13. Compatibility and versions

| Change | Breaks anything? | Version |
|---|---|---|
| The lifecycle protocol; sources' and sinks' ends | no: only the new types use them | v0.2.x |
| `gather` | unchanged | |
| `iterator` returning a blessed code reference | no, unless code checks `ref` is `CODE` | v0.2.x (**Q7**) |
| Stage, Source, Sink, Factories, Sources, Sinks, Sugar, Operators | no: new modules | v0.2.x |
| `pipeline` and `named` | no: new, unreleased | v0.2.x |
| Canned stages returning objects | `ref` changes from `CODE` | v0.2.x if accepted (**Q12**) |
| A pipeline's name in its stages' errors (2026-0013) | messages change | v0.3.0 |
| A strict `is_stage` by default (2026-0019) | behaviour changes | v0.3.0, not proposed |

Proposed: everything here ships as v0.2.x, in one or more releases,
and 2026-0013 waits for a v0.3.0 with whatever else needs one.

## 14. What's built already

On Ekorn's `pipeline-experimental`, unreleased, and provisional until
this design is approved:

| Built | In this design |
|---|---|
| `pipeline(...)`, exported by Ekorn::Pipeline, with an `import` of its own that makes it for a subclass (2026-0011, 2026-0020) | moves to Factories, over `pipeline_in`; Ekorn::Pipeline's own `import` goes (2026-0021) |
| `named`, names per package and per class, inherited one way, overridable | kept as it is |
| Pipes' `pipeline_class` | kept |
| The docs for all of it, and `Changes` | rewritten with the move |

## 15. The order things depend on

Not yet a plan of items; just what must come before what.

```
core lifecycle (5)
  -> Stage, Source and Sink classes (6.1)
       -> Factories' stage, source and sink (6.2)
            -> Sources (8.2) -> Operators (9)
            -> Sinks (8.3)   -> Operators (9)
            -> canned stages as objects (8.1) -> Operators (9)

pipeline_in (6.1)
  -> Factories' pipeline (6.2)
       -> Sugar (10)

DBIx-Squirrel:
  Factories' pipeline        -> its Factories (12.2), its Sugar key (12.5)
  core lifecycle + Source    -> its iterator as a source (12.3)
  core lifecycle + Sink      -> insert_into (12.4)
```

`pipeline` moving to Factories needs only `pipeline_in`, so it can come
first, before any of the lifecycle work.

## 16. Open questions

Each says whose it is, and recommends an answer where there's one.

| | Question | Whose | Recommended |
|---|---|---|---|
| **Q1** | Do sources, sinks and operators belong in Ekorn, a step toward a stream library beyond the README's pitch? | Iain | Yes, opt-in, as the pull is what makes stages safe for files and databases; the README says so in a section of its own |
| **Q2** | The lifecycle method's name (`for_run` here)? | Ekorn | `for_run` |
| **Q3** | Each part told how the run ended from where it stands (5.3)? | Ekorn | Yes: it's how a stop works today |
| **Q4** | A source's and a sink's end always runs, and a sink's result counts only when `done`? | Ekorn | Yes |
| **Q5** | The source's end runs last, after every stage's? | Ekorn | Yes |
| **Q6** | An end that dies during a die: warn, keeping the first error? | Ekorn | Yes, with a message saying which end |
| **Q7** | `iterator` returns a blessed code reference whose `DESTROY` ends an abandoned run? | Ekorn, DBIx-Squirrel to confirm | Yes |
| **Q8** | A sink is the last stage of a pipeline, made for a run, its end giving the result? | Ekorn | Yes |
| **Q9** | `stage(\&trim)`: wrap, never bless the sub given? | Ekorn | Always wrap |
| **Q10** | The name-reading class method: `pipeline_in` or `new_in`? | Ekorn (2026-0021 D6) | `pipeline_in` |
| **Q11** | Named sources (2026-0012) now, or later? | Iain | Later |
| **Q12** | Canned stages return objects, changing their `ref`? | Iain, DBIx-Squirrel to check its tests | Yes, in a v0.2.x, said plainly in `Changes` |
| **Q13** | `hash_pairs` for a hash's pairs? | Ekorn | Yes |
| **Q14** | Shared helpers for both Sugars: where, and named what? | Ekorn and DBIx-Squirrel | A module of functions in Ekorn, such as `Ekorn::Pipeline::Util` |
| **Q15** | `is_source`, exported like `is_stage`? | Ekorn | Yes, if `iterator` must tell a Source from a code reference |
| **Q16** | Which words DBIx::Squirrel::Factories offers? | DBIx-Squirrel | |
| **Q17** | How DBIx::Squirrel::Iterator becomes a source? | DBIx-Squirrel | |
| **Q18** | Can a statement's definition in its Sugar name a pipeline by a string? | DBIx-Squirrel | |
| **Q19** | Its CI testing against Ekorn's `pipeline-experimental`? | DBIx-Squirrel | Yes, as on its `ekorn-pipeline` branch in November |
| **Q20** | Ekorn::Pipeline still re-exporting `pipeline` (2026-0021 D7)? | Iain | No |
| **Q21** | A strict `is_stage` (2026-0019) at all, given pipeline-last? | Iain | Not now: pipeline-last answers the need |

## 17. Decisions, and what was weighed

The reasons for each settled decision this design rests on, and what
was considered and set aside, so a reader can see why, and needn't
weigh the same options again. The records named hold the full
discussion.

### 17.1 Words live in Ekorn::Pipeline::Factories

`pipeline` behaves as a factory, but its short, keyword-like name is
the only reason it exists: `new` already makes pipelines. That makes
it syntax, and syntax belongs in a module the user chooses to import,
beside the other words that make types. (2026-0021, D1 and D2.)

Weighed and set aside:

- **`pipeline` exported by Ekorn::Pipeline itself.** In the class, it
  had to work out which class to make. That took an `import` of the
  class's own, building a function for each subclass it was imported
  through. A subclass with an `import` of its own, such as Exporter's,
  lost it, and needed `__PACKAGE__->SUPER::import('pipeline')` in a
  `BEGIN` block to get it back. A package could hold only one
  `pipeline`. And `DBIx::Squirrel::Pipeline->pipeline(...)`, the call a
  factory looks like, read the class's name as a pipeline's.
- **Ekorn::Pipeline::Sugar.** Its import list takes definitions,
  `use Ekorn::Pipeline::Sugar pipeline => {...}`, so `pipeline` would
  mean two things on one line. And sugar in Perl usually means
  definitions made as the program compiles, where the words are used in
  expressions as it runs.
- **Ekorn::Pipeline::Blocks.** It names what some of the words take,
  not what they do, and `pipeline` takes no block.
- **DBIx::Squirrel::Pipeline::Factories,** for DBIx::Squirrel's words.
  Its modules map `Ekorn::Pipeline::X` to `DBIx::Squirrel::X`, so
  DBIx::Squirrel::Factories keeps the pattern, where the longer name
  would sit a level deeper than everything else.
- **`Stop` among the words.** It throws a stop rather than making
  something to keep, so it stays in Ekorn::Pipeline::Stop.

### 17.2 Names are read only where the user writes them

`new` stays strict, and the only method that reads names takes the
package to look them up in, `pipeline_in($package, @stages)`, which the
words call with `scalar caller`. (2026-0011 D4; 2026-0021 D3.)

`new` is the constructor every layer passes stages through: Pipes'
`pipe`, DBIx::Squirrel's `iterate`, and any function taking stages
from its caller, which is the pattern the library exists for. Its
caller is that code, not the user. If `new` read names in its caller's
package, a user's `'clean'` given to `$sth->iterate` would be looked up
in DBIx::Squirrel's package, and fail, or worse, find something else.
A word is called by the user, in their own code, so it looks in the
right place, and hands `new` real pipelines.

Weighed and set aside:

- **`new` reading names.** For the reason above; and its message,
  "Expected stage #%d to be a code reference or a pipeline", would have
  to change, which is a v0.3.0.
- **A second constructor reading names in its caller's package,** such
  as `Class->of(...)`. It has `new`'s problem whenever code passes
  stages through it.
- **`Class->pipeline(...)` as a class method.** It can't be told from
  `pipeline('My::Pipeline', ...)`, where `My::Pipeline` is a valid
  qualified name.

### 17.3 Names belong to a class, inherited one way

A name is kept under the class it was defined through. A class sees
its own and its ancestors', nearest first, never a subclass's; a
subclass can override an ancestor's name; a class can't define a name
twice. (2026-0020, D4 and D5.)

Weighed and set aside:

- **One registry for every class.** A pipeline named through
  DBIx::Squirrel::Pipeline could be found by Ekorn's own `pipeline`,
  and spliced into an Ekorn::Pipeline: the streams crossed.
- **A registry for each class, strictly separate.** Simpler to explain,
  but a subclass would lose the pipelines its ancestor names, which a
  subclass should inherit, as it inherits methods.
- **A subclass unable to define a name its ancestor has.** That was
  lopsided, as an ancestor could define a name its subclass had, and
  unlike methods, which a subclass overrides as a matter of course. It
  meant to keep a pipeline from finding that a name it used had changed
  meaning; but a name is resolved when a pipeline is made, so a
  pipeline made before an override keeps what it found anyway.

### 17.4 Each Sugar makes only its own

Ekorn's Sugar makes Ekorn::Pipelines, and DBIx::Squirrel's Sugar
defines its own pipelines, with its own class's `named`. (2026-0010,
D10.)

Weighed and set aside:

- **Ekorn's Sugar handing definitions back as DBIx::Squirrel's,** either
  by a `pipeline_class` method a subclass of Ekorn's Sugar overrides,
  or by a class passed to `import_into`. Either way Ekorn's code would
  make and hold DBIx::Squirrel's pipelines, crossing the streams; and
  the two Sugars aren't class and subclass, just modules in different
  namespaces making syntax for their own users.

### 17.5 Stages after values that may be code references

A function whose values can be code references takes a pipeline given
last as its stages, and its caller makes one with `pipeline`.
(2026-0011, D2.)

Weighed and set aside:

- **`is_stage` on the arguments' tail,** which is how a function whose
  values aren't code references finds its stages. With callbacks as
  values, the last callbacks would be taken for stages.
- **A strict `is_stage`, accepting only Stage objects and pipelines**
  (2026-0019). It would work only if callers wrote every stage as
  `stage {...}`, and as a default it would change behaviour, a v0.3.0.
  Pipeline-last works with the plain `sub {...}` stages callers already
  write (**Q21**).

### 17.6 One shape for things made for a run

`gather`, `source` and `sink` each take a block that's the set-up: it
runs at the start of each run, declares the run's state with `my`, and
returns the step and the end as closures sharing it. (Principle 7.)

Weighed and set aside:

- **Three blocks, `source {...} step {...} end {...}`,** as Try::Tiny's
  `try` and `catch` read. The blocks are separate subs, so they can't
  share lexicals: the set-up would return the state as a reference, and
  every use would dereference it, `@{ $_[0] }` where today it's
  `@batch`, with a hash reference once there are two things to keep. It
  would add two words, `step` and `end`, so short that they'd need
  exporting only together, and leave `$_` meaning the value in one kind
  of block and the state in another. The closure shape is what `gather`
  already uses, so there's nothing new to learn.

### 17.7 Only sources and sinks get the new ends

A source's and a sink's end always runs, and is told how the run
ended; a gather's end is unchanged. (Section 5.4.)

Weighed and set aside:

- **The same rules for `gather`.** After a stop, a gather's end isn't
  called today if the gather was before the stopping stage; calling it
  would change behaviour code relies on, a v0.3.0. And a gather holds
  values, not files or transactions, so it has nothing to clean up
  after a stop or a die. Sources and sinks are what open things.

### 17.8 Each part is told how the run ended from where it stands

(Section 5.3, **Q3**.)

Weighed and set aside:

- **Every part told the same,** with an end's return dropped after any
  stop. `count` after `take(5)` would then lose its result, though for
  `count` the stream ended normally. A stop already divides a run this
  way: the stages after it finish normally, and those up to it are cut
  off.

### 17.9 A sink is the last stage of a pipeline

(Section 4.2, **Q8**.)

Weighed and set aside:

- **A sink as a gather that lets nothing through.** Close, but a
  sink's end must always run, to roll back or close a file after a
  die, which a gather's end doesn't (17.7).
- **A sink as something outside the pipeline,** taking a source and
  returning a result. It would need a second way of running a
  pipeline, where the last stage of one already gives push and pull
  for free: pushed values in, one result out; pulled, an iterator of
  one value.

### 17.10 An abandoned iterator ends its run

(Section 5.5, **Q7**.)

Weighed and set aside:

- **A method the caller must call to finish,** such as `$next->finish`.
  Callers forget, and the commonest pull, reading the first few values
  and stopping, is exactly the one where they would.

### 17.11 Operators only on the typed objects

(Section 9.)

Weighed and set aside:

- **Operators on every pipeline.** Overloading belongs to a class, not
  a scope, so it would change Ekorn::Pipeline for everyone, whether or
  not they loaded the operators.
- **`+`, `.` or `>>`.** Each already means too much to a Perl reader.

### 17.12 Ready-made parts are named not to clash

`first_value`, `any_value`, `joined`, `hash_pairs`: each avoids a
built-in (`join`, `each`, `keys`) or a List::Util function many import
(`first`, `any`, `all`, `pairs`, `sum`, `reduce`). And nothing is
exported by default, so a ready-made part never replaces a function
already in the user's package. (2026-0016, 2026-0017.)

## 18. Where each roadmap item lands

| Item | Section | In this design |
|---|---|---|
| Ekorn 2026-0010, Sugar | 10 | as its record, makes only Ekorn's |
| Ekorn 2026-0011, `pipeline` and names | 6.2, 7 | names kept; `pipeline` moves |
| Ekorn 2026-0012, a named source | 7 | later (**Q11**) |
| Ekorn 2026-0013, names in errors | 13 | v0.3.0, later |
| Ekorn 2026-0014, the lifecycle | 5 | the core change everything that opens something rests on |
| Ekorn 2026-0015, words for sources, stages and sinks | 6 | in Factories |
| Ekorn 2026-0016, sources | 8.2 | as listed |
| Ekorn 2026-0017, sinks | 8.3 | as listed (**Q8**) |
| Ekorn 2026-0018, operators | 9 | as listed |
| Ekorn 2026-0019, strict `is_stage` | 13 | not now (**Q21**) |
| Ekorn 2026-0020, `pipeline` through a subclass | 14 | replaced by Factories; names per class kept |
| Ekorn 2026-0021, Factories | 6.2 | as its record |
| DBIx-Squirrel 2026-0003, add-on distributions | 8 | those needing no database may move here |
| DBIx-Squirrel 2026-0009, export `pipeline` | 12.2 | through its Factories |
| DBIx-Squirrel 2026-0010, Sugar's `pipeline` key | 12.5 | defines its own |
| DBIx-Squirrel 2026-0011, Ekorn's helpers | 10 | **Q14** |
| DBIx-Squirrel 2026-0012, `insert_into` | 12.4 | needs Sink and ends |
