# Ekorn::Pipeline and DBIx::Squirrel: one design

**Status:** a draft for review, roadmap 2026-0022. Nothing here is
decided until Iain approves it. Where it says "settled", it means
decided earlier and carried in; where it says "proposed", it's this
design's suggestion; open questions are numbered **Q1** and on, and
listed together in section 16. Section 17 gives the reasons for each
settled decision, and what was weighed against it. Section 19 says how
the design is proved, by experimental code, before it's approved.

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
12. [DBIx::Squirrel: a user of Ekorn](#12-dbixsquirrel-a-user-of-ekorn)
13. [Compatibility and versions](#13-compatibility-and-versions)
14. [What's built already](#14-whats-built-already)
15. [The order things depend on](#15-the-order-things-depend-on)
16. [Open questions](#16-open-questions)
17. [Decisions, and what was weighed](#17-decisions-and-what-was-weighed)
18. [Where each roadmap item lands](#18-where-each-roadmap-item-lands)
19. [Proving the design](#19-proving-the-design)

## 1. Why this document

Until now, the work was split into roadmap items, here and in
DBIx-Squirrel, each designed on its own. The decisions were sound one
at a time, but they kept turning out to bite later: one name registry
for every class, Ekorn's Sugar making DBIx::Squirrel's pipelines, a
facade's `import` losing `pipeline`, and `pipeline` itself living in
the class. Each was found after it was built, and most came from tying
DBIx::Squirrel to Ekorn's classes, which this design undoes (principle
2).

This document describes everything planned in both repositories as one
design, so that its parts can be checked against each other before
anything more is built. It's then proved by experimental code, built
to show it holds together (section 19), and only once it's proved and
approved is it split into items again.

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
ideas came from, and where they'll be tried first. It uses Ekorn as
it is, as any other package would.

## 3. Principles

These were settled before this document, except where it says
"proposed". Every part of the design below follows from them, and
section 17 gives the reasons for each.

1. **Opt-in, in layers.** The core is extended only as far as the
   layers above need. Each layer comes in a module of its own, so
   someone who never `use`s it sees no change.
2. **Other packages use Ekorn as it is** (settled by Iain, 2026-11-12). DBIx::Squirrel,
   or any package that hands out values, is a user of Ekorn like any
   other. It delivers sources, sinks and stages that keep Ekorn's
   protocols, and runs them in Ekorn's own pipelines. It subclasses,
   wraps and remakes nothing of Ekorn's, and Ekorn changes nothing for
   it.
3. **Ekorn's contract is its protocols** (proposed). What other
   packages rely on is section 4.4: what a stage, a source, a sink and
   a stop are, what being made for a run means, and what a stage may
   ask about its run. Ekorn's classes, words and ready-made parts are
   for its users, not for other packages to extend. Changing a
   protocol is a v0.3.0.
4. **Factories are words, in a module of words.** A short,
   keyword-like function that makes one of the types, such as
   `pipeline` or `source {...}`, is syntax, not behaviour. It lives in
   Ekorn::Pipeline::Factories, as one line over a class method, not in
   the class it makes.
5. **Names are resolved where the user writes them.** Only a word the
   user calls reads names, in the user's own package. `new` reads
   none, as it's called by code in between: Pipes, DBIx::Squirrel's
   `iterate`, any function taking stages from its caller.
6. **Every type is an Element, called as a code reference** (settled
   by Iain, 2026-11-12). Each of Ekorn's types, the pipeline included,
   is an object of a class built on Ekorn::Pipeline::Element: a hash
   holding what it was made with, overloading `&{}`, so it's called as
   a code reference wherever one is. A plain code reference given to
   a pipeline is made a Stage, so a pipeline is made of Elements.
   `is_stage` takes a plain code reference, or an Element that goes
   where a stage goes, so every function taking stages today takes the
   new types unchanged. Code that checks for a code reference by its
   type, `ref` or Ref::Util's `is_coderef`, doesn't see one.
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
| **Sink** | consumes every value, and gives its result when they run out: one value, or a list | each value | nothing, until its result is given | nothing yet: a call in list context, `all`, `count` |
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
  the values that come out of the stages. Ending in a sink, it gives
  the sink's result, so it can feed another pipeline:

  ```perl
  my $artists = Ekorn::Pipeline->new(stage { $_->{artist} }, to_array)
      ->iterator(from_arrayref(\@tracks));
  my $next = Ekorn::Pipeline->new(take(2))->iterator($artists);
  ```

  The first pull reads all of the inner source, as the inner sink
  holds back every value until its input runs out. The inner run ends
  when the inner iterator does: read to its end, finished, or let go,
  as when the outer run ends. Only then are the inner source and sink
  told how it ended (section 5.4): `done`, as their input ran out,
  unless the outer run died, when they're told `died`.
- **A gather is a stage** whose state lasts a run, with an end that can
  let out what it held.
- **A sink is a stage that holds back every value,** and lets out its
  result when its input runs out (proposed, **Q8**): one value, such as a count, or
  a list, such as every value. So it's a flatMap of the whole stream,
  shaped as a gather is. It's usually last, and then its result is
  what the run gives: pushed values in, the result out; or, pulled
  from a source, an iterator that hands out the result. Anywhere else,
  its result goes on through the stages after it, as a gather's does:
  `to_array` there passes on the same values, once it has them all,
  and `count` passes on one number. Nothing has to follow a sink, and
  nothing is forbidden to.
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

### 4.4 The protocols: Ekorn's contract with other packages

A package that keeps these works with Ekorn, without subclassing or
wrapping anything of it (principles 2 and 3; the list proposed):

| Protocol | The contract |
|---|---|
| **Stage** | called with a value, in `$_` and `@_`; returns a list, of none, one or several values |
| **Source** | called with nothing; returns the next value or values, or an empty list when there are no more |
| **Made for a run** | an object offering a role by a method the core calls at the start of each run, returning its step and its end (section 5.2): `as_source`, to be read from; `as_stage`, to pass values through; or, to be a sink, `as_scalar` or `as_list`, at most one of them. The role it's given in decides which is called, so one object can offer several. A code reference offers none, and takes the role it's given in, with no end |
| **Sink** | an object with `as_scalar`, its result one value, or `as_list`, its result a list, returning its step, whose return is ignored, its result, called when its input runs out, and, optionally, its end, called when the run has ended, told how (sections 5.4, 9) |
| **Stop** | thrown from a stage, with `Stop(...)`, to end the run, the values it carries going on (section 5.3) |
| **What a stage may ask** | `Ekorn::Pipeline::ending()`, true while values come from an end (section 5.6); and `Ekorn::Pipeline::run_context()`, the context its run's source gave, if any (section 12.7) |
| **A run's context** | the third value `as_source` may return, after its step and its end: anything the source knows about this run, such as a statement's columns, for its stages to ask for. An iterator used as a source passes on the context of the run inside it |

These are what Ekorn versions, and what DBIx::Squirrel's range on
Ekorn's version protects. Everything else a package needs, it gets as
any user does: pipelines from `new`, words from Factories, ready-made
parts from their modules.

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
sub from_file ($path) {
    return source {
        open my $fh, '<', $path or die "Can't read $path: $!\n";
        return (
            sub ()     { my $record = readline $fh; return unless defined $record; chomp $record; $record },
            sub ($how) { close $fh },
        );
    };
}
```

So there's one shape to learn, state lives in plain lexicals, and the
core needs one protocol: an object it's given as a source, a stage or
a sink can be **made for a run**, by a method for that role, which the
core calls at the start of each run, and which returns the step and
the end: `as_source`, `as_stage`, and `as_scalar` or `as_list` for a
sink (section 4.4; 2026-0022's D5). An object without the method for
the role it's given in can't take that role. A code reference is used
as it is, as every one is today.

### 5.3 How a run ends

A run ends in one of three ways, and each part of it is told which,
**from where it stands** (proposed, **Q3**). What each word means to
the part told it:

- **`died`:** the run died, anywhere, before it ended. A sink rolls
  back, whether the die came before it or after it.
- **`stopped`:** its input was cut short: by a stop at or after it
  while it still had values to come, or by the run being ended from
  outside, by `finish` or as its iterator was let go, before its input
  ran out. A sink that stops the run itself is the exception: it had
  enough, and is told `done`.
- **`done`:** its input ran out, and the run didn't die.

So, for the commonest runs:

| The run | The source, and stages up to and including the one that stopped | Stages after the one that stopped |
|---|---|---|
| ran out of values | `done` | `done` |
| was stopped by a stage | `stopped` | `done` |
| had a stage or an end die | `died` | `died` |
| was ended from outside | `stopped`, for each part whose input hadn't run out; `done` for the rest | the same |

That's how a stop works already. After a stop, the stages after the
one that stopped go on, and their ends are called with the values from
before the stop and the ones it carries: for them, the stream ended
normally. The stage that stopped, and those before it, are cut off:
a gather's end there isn't called, and the ends of what's made for a
run are told `stopped` once the run ends.

So `from_file($path) | take(5) | count` means: the source,
`from_file`, is told `stopped`, and closes its file; `count`, after
`take(5)`, is told `done`, and gives 5, the result.

### 5.4 What an end does

**A sink's result** (2026-0022's D6) is called once its input runs
out, as a gather's end is, and what it returns goes on through the
stages after it. It isn't told how the run ended, as the run hasn't:
the stages after the sink are still to see its result. If its input
is cut short, or the run dies first, it isn't called.

**A source's, a sink's, and a stage's end** made for a run (proposed,
**Q4**):

- **always runs, once, when the run has ended,** however it ended:
  when its values have all been handed out, when it's been finished or
  let go, or when it died. It's given how, `done`, `stopped` or
  `died`, from where it stands (section 5.3), as its argument. So a
  sink that commits only when told `done` never commits for a run that
  dies after it;
- **gives nothing:** what it returns is dropped. A sink's result comes
  from its result, not its end;
- **runs in order:** the stages' ends first, first stage first, and
  **the source's end last** (**Q5**);
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

**Proposed (Q7):** `iterator` returns an Ekorn::Pipeline::Iterator,
an Element (still called as `$next->()`, so nothing changes for its
callers), whose `DESTROY` ends the run, telling its source and sink
`stopped`, if it hasn't ended already. Its `finish` method ends the
run the same way, sooner, and a run ended either way hands out
nothing more. Perl calls `DESTROY` when the last reference
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

Each type is a class built on Ekorn::Pipeline::Element (principle 6),
made by its constructor, a class method that takes only real things
(code references, pipelines), never names:

| Class | Constructor | Notes |
|---|---|---|
| `Ekorn::Pipeline::Element` | (none) | the base: `call`, `&{}`, and `goes_as_stage`, true unless a class says not, as Source and Iterator do |
| `Ekorn::Pipeline` | `new(@stages)` | settled; strict: no names; makes a Stage of each plain code reference, and `stages` returns the Elements |
| `Ekorn::Pipeline::Stage` | `new($code)` | proposed; wraps the code given, never blesses it (**Q9**); a run calls the code as it is |
| `Ekorn::Pipeline::Gather` | `new($setup)` | as `gather` makes today, now an Element |
| `Ekorn::Pipeline::Source` | `new($setup)` | proposed; `$setup` returns the step and the end |
| `Ekorn::Pipeline::Sink` | `new($setup)` | proposed; `$setup` returns the step and the end |

And one more class method, which, with `named`, is all that reads
names (settled in 2026-0021 as a class method taking the package; its
name is **Q10**, here `pipeline_in`):

```perl
Ekorn::Pipeline->pipeline_in($package, @stages)
```

It makes a pipeline of its invocant's class, with each name among the
stages looked up in `$package` (section 7). Methods make their
invocant's class as a matter of course, so that a class can be
subclassed, but nothing in this design rests on one being.

### 6.2 The words: Ekorn::Pipeline::Factories

The words are the short forms users write, each one line over a
constructor (settled, 2026-0021):

| Word | Makes | Its block |
|---|---|---|
| `pipeline(@stages)` | a pipeline, its stages possibly names | (takes a list) |
| `stage {...}` | a Stage | the stage itself, called with each value |
| `gather {...}` | a Gather | a set-up, returning the step and, optionally, the end |
| `source {...}` | a Source | a set-up, returning the step and, optionally, the end |
| `sink {...}` | a Sink | a set-up, returning the step, the result and, optionally, the end |

The rule for the blocks: **a word for something made afresh for each
run takes a set-up; `stage` takes the stage itself.** A source with
nothing to open or close needs no word: any code reference is a
source, as today.

```perl
my $upper = stage { uc };

my $count = sink {
    my $n = 0;
    return (sub ($value) { $n++ }, sub () { $n });    # its step and its result
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
  a job of their own: `take(5)`, `from_file($path)`, `count`. They
  live by topic, as the canned stages do now: Ekorn::Pipeline::Stages::*,
  ::Sources, ::Sinks. Each is built with a word or a constructor.

So a user asks "which word makes a source?" in one place, and "is
there a source for a file's lines?" in another.

## 7. Names

Settled in 2026-0011. The names per class that 2026-0020 added are
undone (17.3): with no package subclassing Ekorn, there are no other
classes' names to keep apart.

- **A name** is identifiers, as Perl's, joined by `::`: `clean`,
  `My::Module::clean`.
- **The package a name is in says whose it is:** the package that
  called `named`, unless the name is qualified. So two modules can
  each have a `clean`. Used unqualified, a name is looked up in the
  package where it's written; qualified, it's found from anywhere.
- **`named` defines one:** `Ekorn::Pipeline->named(clean => @stages)`
  makes a pipeline; `$p->named('clean')` names one you have. A name
  can't be defined twice; naming the same pipeline again is no
  mistake. A name can't be removed.
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
section 9. They're Elements (principle 6), called as code references,
so everything that calls them, or takes them with `is_stage`, works as
now; code that checks the type, `ref` or `is_coderef`, sees an object,
not a code reference (**Q12**). Those made with `gather` are Elements
already.

### 8.2 Sources: Ekorn::Pipeline::Sources (2026-0016)

Using only what comes with Perl. Nothing exported by default.

| Source | Gives | Its end |
|---|---|---|
| `from_array(@values)` | the values given | none |
| `from_arrayref(\@array)` | an array's values, read as asked for | none |
| `from_fh($fh)` | a filehandle's records, as `$/` divides them: its lines, unless `$/` is changed; each chomped | none: you opened it |
| `from_file($path)` | a file's records, as `$/` divides them: its lines, unless `$/` is changed; each chomped | closes the file, however the run ends |
| `from_hash(%hash)` | the keys and values given, as pairs | none |
| `from_hashref(\%hash)` | a hash's keys and values, as pairs, read as asked for | none |
| `counter($start, $step)` | 1, 2, 3 and on, without end | none |
| `unfold($seed, sub {...})` | a sub applied again and again, until it gives nothing | none |
| `cycle(@values)` | the values, round and round | none |
| `concat(@sources)` | each source in turn | ends each source it read |
| `interleave(@sources)` | one value from each source in turn | ends each source it read |

Each `from_` source says what it takes: a list or a reference, of an
array or a hash, a filehandle or a file. A pair is a two-element array,
`[$key, $value]`, in the order Perl gives the hash's keys.

### 8.3 Sinks: Ekorn::Pipeline::Sinks (2026-0017)

Each `to_` sink is the counterpart of a `from_` source, so what one
reads, the other writes. The rest have names that can't clash with
Perl's built-ins or List::Util's. Nothing exported by default.

| Sink | Gives | Stops the pull early? |
|---|---|---|
| `to_array` | every value, as a list (`as_list`) | no |
| `to_arrayref`, `to_arrayref(\@array)` | an array reference of every value: your array, with each pushed onto it, or a new one (`as_scalar`) | no |
| `to_fh($fh)` | prints each value to your filehandle, followed by `$/`; gives how many | no; you close it |
| `to_file($path)` | writes each value to the file, followed by `$/`; gives how many | no; its end closes the file |
| `to_hash` | every pair's key and value, as a list to assign to a hash (`as_list`) | no |
| `to_hashref`, `to_hashref(\%hash)` | a hash reference of every pair: your hash, with each put into it, or a new one (`as_scalar`) | no |
| `group_by(sub {...})` | a hash of arrays | no |
| `count` | how many values there were | no |
| `first_value` | the first value | yes |
| `last_value` | the last value | no |
| `any_value(sub {...})` | true at the first value the sub is true of | yes |
| `every_value(sub {...})` | false at the first value the sub is false of | yes |
| `fold($init, sub {...})` | a running total, of any kind | no |
| `joined($separator)` | the values joined into one string | no |
| `for_each(sub {...})` | calls the sub with each value; gives how many | no |

`from_fh` and `from_file` remove `$/` from each record, and `to_fh` and
`to_file` add it back, so a file read with one is written unchanged by
the other. `from_hash` and `from_hashref` give pairs, and `to_hash` and
`to_hashref` take them; to key values by something of their own, a
stage makes the pairs first: `stage { [$_->{id}, $_] }`.

A sink that stops early is told `done`, as the stage that decided the
run had enough; the source and stages before it are told `stopped`.

## 9. Operators (2026-0018)

An opt-in layer, Ekorn::Pipeline::Operators, on the typed objects of
section 6 only. It's a shorthand for the commonest shapes, not the
whole model: what it can't say, a pipeline made with `new`, pulled
with `iterator`, can, as the points below show.

```perl
my $clean = $trim | $lowercase | $dedupe;               # Stage | Stage: a chain of stages
my $names = $src | take(10) | stage { $_->{name} };    # Source | Stage: a source
my $n     = $src | stage { $_->{name} } | count;       # Source | ... | Sink: the result
my @names = @{ $src | take(10) };                       # @{} drains a source
```

- **An operator works on any part that keeps the protocols** of
  section 4.4 and is one of the typed objects, whichever package made
  it, so a DBIx::Squirrel source chains with Ekorn's stages and sinks.
- **Perl calls an overload only if one side is an object.** Between two
  plain code references, `|` silently ORs their addresses. The docs
  must say loudly: in a chain, every stage is a `stage {...}`, or a
  ready-made part, which section 8.1 makes objects.
- **An operator returns one scalar,** so only a scalar sink, one with
  `as_scalar`, can end a chain, and its result is what `|` gives. A
  list sink, such as `to_array` or `to_hash`, croaks there, as its list
  can't be given: its scalar counterpart, `to_arrayref` or
  `to_hashref`, gives the same as a reference, saying so in its name.
  Or `@{}` drains a chain without a sink.
- **Nothing can be chained after a sink.** Not because a sink must be
  last, which it needn't be (section 4.2), but because a chain ending
  in a sink has already run: what `|` gives is the result, not a part
  that more can be joined to. In a pipeline made with `new`, or
  spliced as a stage, a sink can have stages after it.
- **A chain from a source to a sink is a result, not a source.**
  `$src | count` is a number, at once: `|` is for getting the answer
  in one expression, and giving a source instead would make
  `my $n = $src | count` an object to drain. For a source that gives
  a sink's result, use `iterator` (section 4.2).
- A pipeline made with `new` gets no operators: only the chains `|`
  makes, and the typed objects, do. So `Stage | Stage` makes a chain
  of stages, not a pipeline, which `|` can extend, and which can be
  given wherever a pipeline can.
- **`|=` makes a new chain,** and puts it in the variable: `$chain |=
  $stage` is `$chain = $chain | $stage`. Nothing made is changed in
  place.

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
- **It names the only pipelines there are, Ekorn's.** A package such
  as DBIx::Squirrel names none of its own: its users name pipelines
  with this Sugar, or `named`, and use the names wherever stages go,
  a statement's stages included.
- `import_into($package, ...)` lets a module add to it for its caller.

Proposed: DBIx::Squirrel's Sugar keeps its own helpers, for checking a
name and installing a function, rather than calling Ekorn's, so
neither depends on the other's internals.

## 11. The modules

### 11.1 Ekorn

| Module | Layer | Gives | Exports |
|---|---|---|---|
| `Ekorn::Pipeline` | core | the class; `new`, `pipeline_in`, `named`, `iterator`, `stages`; the lifecycle (section 5) | `is_stage` (and `is_source`, **Q13**) on request |
| `Ekorn::Pipeline::Stop` | core | `Stop`, `throw` | `Stop` by default |
| `Ekorn::Pipeline::Gather` | core | the Gather class; `gather` | `gather` by default |
| `Ekorn::Pipeline::Errors` | core | `croakf`, `@INTERNAL` | `croakf` on request |
| `Ekorn::Pipeline::Pipes` | core | `pipe` and `tap`, for a class's objects to make pipelines with | none: a parent class |
| `Ekorn::Pipeline::Element` | core | the base class of every type | none |
| `Ekorn::Pipeline::Iterator` | core | what `iterator` returns | none |
| `Ekorn::Pipeline::Stage`, `::Source`, `::Sink` | 1 | the classes | none |
| `Ekorn::Pipeline::Factories` | 1 | the words | on request |
| `Ekorn::Pipeline::Stages::Flow`, `::Batch`, `::Taps` | parts | canned stages | as now |
| `Ekorn::Pipeline::Sources`, `::Sinks` | 2 | ready-made sources and sinks | on request |
| `Ekorn::Pipeline::Sugar` | names | compile-time naming | its import list |
| `Ekorn::Pipeline::Operators` | 3 | `\|`, `\|=`, `@{}` on the types | none: loading it switches them on for the typed objects |

Each new module that croaks joins `@Ekorn::Pipeline::Errors::INTERNAL`,
so errors are reported at the caller's line.

### 11.2 DBIx::Squirrel

Proposed: no module of DBIx::Squirrel's subclasses or wraps one of
Ekorn's (principle 2). Its modules are its own, delivering parts:

| Module | Today | Proposed |
|---|---|---|
| `DBIx::Squirrel::Pipeline`, `::Pipes`, `::Stop`, `::Gather`, `::Stages::Flow`, `::Batch`, `::Taps` | facades over Ekorn's: subclasses, and re-exports | no subclasses; whether it keeps re-exporting Ekorn's functions as they are is **Q20** |
| `DBIx::Squirrel::Iterator` | statements' rows, through a pipeline of its own class | a Source (section 12.3), run in Ekorn's pipelines |
| `DBIx::Squirrel::Stages::Rows` | `pluck`, `as_hash`, through Context | stages of its own, finding their columns with `run_context()` (section 12.7) |
| `DBIx::Squirrel::Sinks` | (new) | `insert_into` (its 2026-0012), a Sink |
| `DBIx::Squirrel::Sugar` | databases, statements | as now, its statements' stages able to use Ekorn's names; no `pipeline` key |

## 12. DBIx::Squirrel: a user of Ekorn

From DBIx::Squirrel's code on its `pipeline-experimental`, as read on
2026-11-11. Everything here is DBIx-Squirrel's to design; this section
shows that it needs nothing of Ekorn beyond section 4.4's protocols
and what any user has.

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

Of these, only the facade, the subclass `DBIx::Squirrel::Pipeline`
with no code of its own, goes against principle 2. Everything else
already uses Ekorn as any user would.

### 12.2 What it delivers

Three kinds of part, each one of section 4.4's protocols, and nothing
else:

- **Sources:** a statement's rows (12.3).
- **Sinks:** a table to insert into (12.4).
- **Stages that need its knowledge:** `pluck` and `as_hash` (12.7).

And functions that take stages, `iterate` and the like, as any user of
Ekorn writes: they find their stages with `is_stage`, and run them with
`Ekorn::Pipeline->new(@stages)->iterator($source)`.

Its users compose its parts with Ekorn's, and nothing in the result
knows which package made which part:

```perl
my $names = Ekorn::Pipeline->new(pluck('name'), take(5))->iterator($sth->source);
my $n     = $sth->source | stage { [$_->{id}, $_->{name}] } | insert_into($archive, 'people');
```

### 12.3 Its iterator as a source

A statement is a natural source, made for a run like any other: its
set-up executes the statement, its step fetches, its end finishes the
statement handle. With section 5, a statement's rows read through
`take(5)` finish the handle when the stop comes, and an iterator
dropped half-read finishes it too.

How DBIx::Squirrel::Iterator becomes one is DBIx-Squirrel's to design
(**Q14**). It's a hash-based object today, with `next`, `all`,
`reset`, `single`, `count`, not a code reference, so it would either
offer a Source (say `$it->source`) or become callable. Its `reset` is
the set-up; its `_finish` the end.

### 12.4 A database as a sink

`insert_into($dbh, $table)`, in DBIx::Squirrel::Sinks (its 2026-0012):
its set-up prepares the INSERT and begins a transaction; its step
executes it for each value; its result is how many rows went in; and
its end, once the run has ended, commits if it's `done`, and rolls
back if not, so a run that dies after it inserts nothing:

```perl
sub insert_into ($dbh, $table) {
    return sink {
        my $sth = $dbh->prepare(...);
        my $n   = 0;
        $dbh->begin_work;
        return (
            sub ($row) { $sth->execute(@$row); $n++ },
            sub ()     { $n },
            sub ($how) { $how eq 'done' ? $dbh->commit : $dbh->rollback },
        );
    };
}
```

It needs Ekorn's Sink and section 5's ends. Which columns, how often to
commit, and what it gives back are DBIx-Squirrel's questions.

### 12.5 Its Sugar

DBIx::Squirrel::Sugar defines databases and statements, as now. It
names no pipelines: its users name them with Ekorn's Sugar or `named`,
and a statement's stages can use those names, resolved by Ekorn's
`pipeline` in the user's package. Whether a statement's definition can
name a pipeline by a string, and how that's told from anything else in
a definition, is its question (**Q15**).

### 12.6 What it gives its users

Its users write `use DBIx::Squirrel::Stop` and the like today, and get
Ekorn's functions through its facades. It can keep giving them, as
plain re-exports of Ekorn's functions, unchanged, or point its users
to Ekorn's own modules (**Q20**). Either way, a user can mix the two
freely, as the functions are the same.

### 12.7 A stage that needs to know its source

`pluck('name')` needs the statement's column names. Today Context gives
them, because DBIx::Squirrel runs the pipeline. When a user joins
`$sth->source | pluck('name')` themselves, DBIx::Squirrel runs
nothing. This is the one place its parts need more than they're given.

Settled (Iain, 2026-11-12, 2026-0022's D7): **a source gives a context
for each run, and a stage asks for it.** `as_source` may return a
third value, after its step and its end, anything the source knows
about this run; a stage calls `Ekorn::Pipeline::run_context()` for it,
as it calls `ending()`. A statement's set-up executes it, and gives
`{columns => [...]}`:

```perl
sub pluck ($name) {
    return sub ($row) {
        my $columns = Ekorn::Pipeline::run_context()->{columns};
        my($at) = grep { $columns->[$_] eq $name } 0 .. $#$columns;
        return $row->[$at];
    };
}
```

- **Each run has its own,** so two runs of one statement at once each
  see their own columns.
- **An iterator used as a source passes on the context of the run
  inside it,** so `pluck` sees the statement's columns behind a
  pipeline between them.
- **A pushed run has none,** and `run_context()` gives nothing; nor
  does a run whose source gives none.
- **It's generic:** a CSV source could give its header the same way,
  and no provider needs more of Ekorn than this function.

Weighed and set aside (17.16): asking for the source object itself,
which every run shares; values that carry it, as rows that know their
columns, which changes what users get; and the stage given it,
`pluck($sth, 'name')`, which repeats what the source knows.

### 12.8 What could bite

Found by reading both sides together; each has an answer above or a
question below.

- Code in DBIx::Squirrel, or its tests, that checks a pipeline `isa`
  DBIx::Squirrel::Pipeline, which goes.
- `Stop` from DBIx::Squirrel::Stop throws Ekorn's class already, so
  catching it is unchanged.
- If `iterator` returns an object (section 5.5), DBIx::Squirrel's
  `$self->{next}->()` keeps working, as it's called as a code
  reference, though it isn't one to `ref` or `is_coderef`.
- If the canned stages become objects (**Q12**), any test in
  DBIx::Squirrel comparing `ref` to `CODE`, or using `is_coderef`,
  would fail.
- Its CI installs Ekorn from CPAN, and runs only on `main` and
  `develop`, so it can't test against Ekorn's `pipeline-experimental`
  yet (**Q16**).

## 13. Compatibility and versions

Settled by Iain, 2026-11-12: **the changes this design makes ship
together as v0.3.0,** and until then everything stays on
`pipeline-experimental`. Nothing of it reaches `develop` or `main`
before. A v0.2.x from `develop` in the meantime only fixes.

| Change | Breaks anything? |
|---|---|
| The lifecycle protocol; sources' and sinks' ends | no: only the new types use them |
| `gather` | unchanged |
| `iterator` returning an Iterator, an Element | no, unless code checks the type, with `ref` or `is_coderef` (**Q7**) |
| Gather, and the canned stages made with it, become Elements | `ref` and `is_coderef` change: an object, called as a code reference |
| `stages` returns Elements: a code reference given comes back as a Stage of it | code comparing them with what it gave |
| Stage, Source, Sink, Factories, Sources, Sinks, Sugar, Operators | no: new modules |
| `pipeline` and `named`, names per package | no: new, unreleased |
| Canned stages returning objects | `ref` changes from `CODE` (**Q12**) |
| A pipeline's name in its stages' errors (2026-0013) | messages change (**Q22**) |
| A strict `is_stage` by default (2026-0019) | behaviour changes; not proposed (**Q18**) |

As a v0.3.0 may change behaviour, what was held back for one can join
it, rather than wait for another: the canned stages as objects, and a
pipeline's name in its errors, if Iain wants it now.

v0.3.0 is outside DBIx::Squirrel's range, `>= v0.2.0, < v0.3.0`, so it
reaches DBIx::Squirrel's users only when DBIx::Squirrel moves the
range, with a task handed to it as the release comes: it tests
against v0.3.0, and can drop its facades then, for Ekorn as it is
(section 12), as it chooses. Until then, its users keep v0.2.x.

## 14. What's built already

On Ekorn's `pipeline-experimental`, unreleased, and provisional until
this design is approved:

| Built | In this design |
|---|---|
| `pipeline(...)`, exported by Ekorn::Pipeline, with an `import` of its own that makes it for a subclass (2026-0011, 2026-0020) | moves to Factories, over `pipeline_in`; Ekorn::Pipeline's own `import` goes (2026-0021) |
| `named`, names per package and per class, inherited one way, overridable | names per package kept; per class goes, back to 2026-0011's (section 7) |
| Pipes' `pipeline_class` | goes: no package needs `pipe` to make a class of its own |
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
  core lifecycle + Source    -> its iterator as a source (12.3)
  core lifecycle + Sink      -> insert_into (12.4)
  a run's context            -> pluck and as_hash as parts (12.7)
```

`pipeline` moving to Factories needs only `pipeline_in`, so it can come
first, before any of the lifecycle work.

## 16. Open questions

Each says whose it is, and recommends an answer where there's one.

| | Question | Whose | Recommended |
|---|---|---|---|
| **Q1** | Do sources, sinks and operators belong in Ekorn, a step toward a stream library beyond the README's pitch? | Iain | Yes, opt-in, as the pull is what makes stages safe for files and databases; the README says so in a section of its own |
| **Q2** | The lifecycle method's name? | Ekorn | Settled by 2026-0022's D5: one method per role, `as_source`, `as_stage`, `as_scalar`, `as_list` |
| **Q3** | Each part told how the run ended from where it stands (5.3)? | Ekorn | Yes: it's how a stop works today |
| **Q4** | A source's and a sink's end always runs, once the run has ended, told how; a sink's result comes from a closure of its own, when its input runs out (2026-0022's D6)? | Ekorn | Yes |
| **Q5** | The source's end runs last, after every stage's? | Ekorn | Yes |
| **Q6** | An end that dies during a die: warn, keeping the first error? | Ekorn | Yes, with a message saying which end |
| **Q7** | `iterator` returns an Iterator whose `DESTROY` ends an abandoned run? | Ekorn, DBIx-Squirrel to confirm | Yes |
| **Q8** | A sink is made for a run, holds back every value, and gives its result, one value or a list, when its input runs out: usually last, its result going on through any stages after it? | Ekorn | Yes |
| **Q9** | `stage(\&trim)`: wrap, never bless the sub given? | Ekorn | Always wrap |
| **Q10** | The name-reading class method: `pipeline_in` or `new_in`? | Ekorn (2026-0021 D6) | `pipeline_in` |
| **Q11** | Named sources (2026-0012) now, or later? | Iain | Later |
| **Q12** | Canned stages return objects, changing their `ref`? | Iain, DBIx-Squirrel to check its tests | Yes, in v0.3.0, said plainly in `Changes` |
| **Q13** | `is_source`, exported like `is_stage`? | Ekorn | Yes, if `iterator` must tell a Source from a code reference |
| **Q14** | How DBIx::Squirrel::Iterator becomes a source? | DBIx-Squirrel | |
| **Q15** | Can a statement's definition in its Sugar name a pipeline by a string? | DBIx-Squirrel | |
| **Q16** | Its CI testing against Ekorn's `pipeline-experimental`? | DBIx-Squirrel | Yes, as on its `ekorn-pipeline` branch in November |
| **Q17** | Ekorn::Pipeline still re-exporting `pipeline` (2026-0021 D7)? | Iain | No |
| **Q18** | A strict `is_stage` (2026-0019) at all, given pipeline-last? | Iain | Not now: pipeline-last answers the need |
| **Q19** | The code that proves the design (section 19): kept, as where the items start, or written again item by item? | Iain | Kept where it holds, each item taking in its part and finishing it, with its tests, docs and coverage |
| **Q20** | Does DBIx::Squirrel keep exporting Ekorn's functions, such as `Stop` and `take`, as they are, or point its users to Ekorn's modules? | DBIx-Squirrel | Keep them, as plain re-exports, so its users' code keeps working |
| **Q21** | How does a stage that needs to know about its source, such as `pluck`, find it out (section 12.7)? | Ekorn | Settled by 2026-0022's D7: the source gives a context for each run, and the stage asks `run_context()` |
| **Q22** | Does a pipeline's name in its stages' errors (2026-0013) join v0.3.0? | Iain | Yes: it's the release that may change messages, and the next is a long way off |

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
  `pipeline`. And `My::Pipeline->pipeline(...)`, the call a
  factory looks like, read the class's name as a pipeline's.
- **Ekorn::Pipeline::Sugar.** Its import list takes definitions,
  `use Ekorn::Pipeline::Sugar pipeline => {...}`, so `pipeline` would
  mean two things on one line. And sugar in Perl usually means
  definitions made as the program compiles, where the words are used in
  expressions as it runs.
- **Ekorn::Pipeline::Blocks.** It names what some of the words take,
  not what they do, and `pipeline` takes no block.
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

### 17.3 Other packages use Ekorn as it is

(Principles 2 and 3, section 4.4, section 12; Iain, 2026-11-12:
DBIx::Squirrel should be able to use Ekorn as it is.) DBIx::Squirrel,
and any package like it, delivers sources, sinks and stages that keep Ekorn's
protocols, and runs them in Ekorn's own pipelines. What it brings is a
database's knowledge, not a pipeline of its own, and the protocols are
all the parts need to work together. So a package can be built on
Ekorn by anyone, from its documented protocols alone, and a change
inside Ekorn can't break it unless it changes a protocol, which is a
v0.3.0.

Weighed and set aside:

- **DBIx::Squirrel as a descendant of Ekorn,** each of its modules a
  subclass or facade of Ekorn's, as decided on 2026-11-11. To keep its
  own class flowing through, it needed names per class, inherited one
  way; Pipes' `pipeline_class` to override; words of its own in a
  DBIx::Squirrel::Factories; a Sugar defining its own pipelines; a
  `Stop` of its own to throw a subclass; and a rule that the two
  namespaces' things never cross. Each was found as a bite, after
  something was built, and none of it did anything a database needs:
  its pipeline subclass has no code. It tied the two designs together,
  and would have done the same to any other package built that way.
- **Hooks in Ekorn for one package,** such as a class to make that
  DBIx::Squirrel could set. Ekorn would bend to one user, and every
  hook would be a protocol to keep.

### 17.4 Names belong to a package

A name is kept in a package, which says whose it is, and is found from
anywhere by its qualified name. (2026-0011.)

Weighed and set aside:

- **Names per class, inherited one way, overridable** (2026-0020). It
  kept one class's names from another's, which only matters when
  another package subclasses Ekorn to make pipelines of its own, as
  principle 2 says none does.
- **One registry, unqualified.** Two modules would clash over `clean`.

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
  write (**Q18**).

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

### 17.9 A sink is a stage, usually the last

(Section 4.2, **Q8**.) A sink holds back every value and lets out its
result when its input runs out, so it's a flatMap of the whole stream,
the same shape as a gather. What sets it apart is its end, which
always runs, once the run has ended, and is told how (17.7, 17.15), so
it can roll back or close a file after a die, where a gather's end
isn't called.

Weighed and set aside:

- **A sink is a gather.** The same shape, but a gather's end isn't
  called after a die, or after a stop in a stage after it, and
  changing that would change behaviour code relies on (17.7).
- **A sink must be last,** with an error for a sink given anywhere
  else, and no stages, or `|`, after it. A sink's result is values,
  and the stages after it can take them as they take any others:
  `to_array` passes on what it holds, `count` one number. A rule
  would forbid that for nothing, and need an error, and a check
  wherever pipelines are spliced or names expanded. `|` can't follow a
  sink anyway, for its own reason (section 9).
- **A sink as something outside the pipeline,** taking a source and
  returning a result. It would need a second way of running a
  pipeline, where a stage already gives push and pull for free:
  pushed values in, the result out; pulled, an iterator of the result.

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

The sources are named for what they take, `from_array`,
`from_arrayref`, `from_hash`, `from_hashref`, `from_fh` and
`from_file`, so a reader knows from the call whether a list, a
reference, a filehandle or a path goes in, and the family reads as
one. The `to_` sinks are their counterparts, named for where the values
go, so a value read with one is written with the other. The other
sinks are `first_value`, `any_value`, `joined` and the like: each
avoids a built-in (`join`, `each`, `keys`) or a List::Util
function many import (`first`, `any`, `all`, `pairs`, `sum`,
`reduce`). And nothing is exported by default, so a ready-made part
never replaces a function already in the user's package. (2026-0016,
2026-0017.)

Weighed and set aside:

- **`from` and `lines`,** shorter, but saying nothing of what they
  take; and `lines` alone in a package reads as a variable's name.
- **`hash_pairs`,** named for what it gives, where the rest are named
  for what they take.
- **`into(\@array)`,** for pushing onto your array. `to_arrayref`
  says the same, and pairs with `from_arrayref`.
- **`to_array` giving an array reference from `|`,** as an operator
  must give one scalar. The name would say a list and the result be a
  reference; `to_arrayref` says what it gives, and `to_array` croaks
  there (Iain, 2026-11-12, 2026-0022's D10).
- **`to_hash(sub {...})`, keying each value by what a sub gives.** It
  wouldn't be the counterpart of `from_hash`, which gives pairs; a
  stage making pairs, then `to_hash`, does the same.

### 17.13 Ekorn's types are Elements

(Principle 6; Iain, 2026-11-12.) Each type is a class on
Ekorn::Pipeline::Element, a hash overloading `&{}`, as Ekorn::Pipeline
always was, and a pipeline is made of Elements.

Weighed and set aside:

- **Blessed code references,** which the prototype first built. A
  code reference has no fields, so Source, Sink and Iterator kept what
  they were made with in hashes keyed by their address, cleaned up in
  `DESTROY`, and reached by their methods through them. And each had
  to close over something: Perl gives every evaluation of an anonymous
  sub that refers to no outer variable the same code reference, so
  every Sink was one object until the prototype's tests caught it. It
  also left the pipeline, a hash, as a second model beside them. In
  their favour, they were code references to any code checking the
  type, which Elements aren't.
- **Plain code references kept as they are in a pipeline,** beside
  Elements. The core would meet two kinds of stage, and `stages` two
  kinds of answer. Made a Stage, a code reference costs nothing per
  value: a run calls the code as it is.

### 17.14 One method per role

(Section 4.4; Iain, 2026-11-12, 2026-0022's D5.) A part says what it
can be by its methods: `as_source`, `as_stage`, and, for a sink,
`as_scalar` or `as_list`. The core and the operators ask only these,
so a package's own parts take any role Ekorn's can, without loading
Ekorn, and one object, such as a table, can be read from and written
to. A sink's own methods let its protocol differ from a stage's, and
say whether its result is one value or a list, which `|` needs.

Weighed and set aside:

- **One method, `for_run`, for every role,** which the prototype
  built. The core then told a source from a sink by Ekorn's classes
  and by position, so a package's own parts couldn't take every role:
  the cold review's S1.
- **`for_run`, and a `role` method saying which it is.** An object
  could take only one role, and the method would exist only to say
  what the other meant.
- **The role decided by where a part is given, unchecked.** Mistakes
  crashed mid-run, and `|` couldn't tell a sink from a stage.
- **`as_sink`, with `gives_list` for a sink giving a list.** A flag
  beside the method, where two methods, after Perl's own scalar and
  list context, say it in the method's name.

### 17.15 A sink's result and its end are separate

(Section 5.4; Iain, 2026-11-12, 2026-0022's D6.) A sink gives its
result from a closure of its own, when its input runs out, and its
end is told how the run ended only once the run has ended. Every end
waits for the run to end, so a sink that commits when told `done`
never commits for a run that dies after it, and section 5.3's table
holds as written.

Weighed and set aside:

- **One end, giving the result and told how, called when the sink's
  input runs out,** which the prototype built. A stage dying after the
  sink left it told `done`, and committed: the cold review's S2.
- **One end, called only when the run has ended.** The stages after a
  sink need its result while the run goes on, so it would work only
  if a sink had to be last, which section 4.2 rejects.
- **Keeping it, and saying a part's verdict is final once its input
  runs out.** Simplest, but `insert_into` would commit and then the
  run die, where a sink matters most.

What it costs: a pipeline ending in a sink, pulled as a source, keeps
its own source open until its run ends, not only until its first
value is given; its source is told the truth, a little later.

### 17.16 A stage asks for its run's context

(Section 12.7; Iain, 2026-11-12, 2026-0022's D7.) A source gives a
context for each run, as the third value of `as_source`, and a stage
asks `run_context()` for it.

Weighed and set aside:

- **The source object, from `run_source()`,** which the prototype
  built. Every run of a source shares the object, so what's known per
  run, such as a statement's columns after it's executed, had nowhere
  of its own: two runs at once each saw the other's. Behind an
  intermediate iterator a stage got the iterator, and in a pushed run
  Ekorn's own closure: the cold review's S3.
- **Values that carry it,** as rows that know their columns. It
  changes what users get as rows.
- **The stage given it,** `pluck($sth, 'name')`. Clumsy, and it repeats
  what the source already knows.

## 18. Where each roadmap item lands

| Item | Section | In this design |
|---|---|---|
| Ekorn 2026-0010, Sugar | 10 | as its record, makes only Ekorn's |
| Ekorn 2026-0011, `pipeline` and names | 6.2, 7 | names kept; `pipeline` moves |
| Ekorn 2026-0012, a named source | 7 | later (**Q11**) |
| Ekorn 2026-0013, names in errors | 13 | may join v0.3.0 (**Q22**) |
| Ekorn 2026-0014, the lifecycle | 5 | the core change everything that opens something rests on |
| Ekorn 2026-0015, words for sources, stages and sinks | 6 | in Factories |
| Ekorn 2026-0016, sources | 8.2 | as listed |
| Ekorn 2026-0017, sinks | 8.3 | as listed (**Q8**) |
| Ekorn 2026-0018, operators | 9 | as listed |
| Ekorn 2026-0019, strict `is_stage` | 13 | not now (**Q18**) |
| Ekorn 2026-0020, `pipeline` through a subclass | 14 | undone: `pipeline` moves to Factories, names are per package, and `pipeline_class` goes (17.3, 17.4) |
| Ekorn 2026-0021, Factories | 6.2 | as its record |
| DBIx-Squirrel 2026-0003, add-on distributions | 8 | those needing no database may move here |
| DBIx-Squirrel 2026-0009, export `pipeline` | 12.6 | Ekorn's, re-exported as it is, if at all (**Q20**) |
| DBIx-Squirrel 2026-0010, Sugar's `pipeline` key | 12.5 | not needed: Ekorn's Sugar names pipelines its statements can use |
| DBIx-Squirrel 2026-0011, Ekorn's helpers | 10 | not needed: its Sugar keeps its own |
| DBIx-Squirrel 2026-0012, `insert_into` | 12.4 | needs Sink and ends |

When the design is split into items, the proofs of section 19 go with
them as tests, in the Done when of each item they rest on: the
lifecycle (2026-0014), the words (2026-0015), sources (2026-0016),
sinks (2026-0017) and operators (2026-0018). So each item shows it
still holds the design together, rather than that being found at the
end.

## 19. Proving the design

The design is tested by building it: experimental code on
`pipeline-experimental`, enough to run the proofs below, before Iain
approves the design and it's split into items. What the code finds
goes back into this document, and the drafts, as any other change
does. Whether the code is kept is **Q19**.

Two compositions prove that the types fit together as section 4 says.
Neither needs a stage between its parts, so each tests the types and
their ends alone.

### 19.1 A source joined directly to a sink

```perl
my $copied = from_file('a.txt') | to_file('b.txt');
my($also)  = Ekorn::Pipeline->new(to_file('b.txt'))->iterator(from_file('a.txt'))->();
```

It proves the ends of section 5, with nothing else in the run:

- **It copies:** `b.txt` is `a.txt`, record for record, as `$/`
  divides them, and the result is how many there were. A file whose
  last line has no newline gains one, as `to_file` writes `$/` after
  each record.
- **Both files are closed, once each, however the run ends:** run
  out, both are told `done`; with `first_value` as the sink, the
  source is told `stopped` after one record, and the sink `done`; when
  the sink dies on a record, both are told `died`, and the error is
  thrown again; when it can't be set up, such as when `b.txt` can't be
  opened, it has no end yet, and only the source is told `died`.
- **The source's end runs last** (**Q5**), after the sink's.
- **Both forms agree:** `|`, and `new` pulled with `iterator`, give
  the same result and the same ends.

### 19.2 A complete pipeline as a source

```perl
my $lines = Ekorn::Pipeline->new(stage { uc }, to_array)->iterator(from_file('a.txt'));
my $next  = Ekorn::Pipeline->new(take(2))->iterator($lines);
```

It proves that a whole run, with its ends, can be one part of another
run, without the ends of either reaching the other:

- **The first pull reads the inner source to its end:** its sink
  holds back every value, so all of `a.txt` is read before the outer
  run has its first value. Neither the inner source nor its sink is
  told anything yet, as the inner run hasn't ended.
- **The outer run's ending ends the inner run:** `take(2)` stops the
  outer run, which finishes the inner iterator; the inner source and
  sink, whose input had run out, are told `done`, the source last. Had
  the outer run died, they'd be told `died`.
- **A result of one value is a source of one value:** with `count` as
  the inner sink, the first pull gives the count, and the next an
  empty list.
- **Without a sink, the inner run is pulled only as needed:** with
  `to_array` taken out, `take(2)` reads two lines of `a.txt`, and the
  inner source is told `stopped`. So it's the sink that makes the
  inner run read everything first.
- **Abandoned, it ends:** the outer iterator let go after one pull
  ends its run, as section 5.5 says, and so the inner's.

### 19.3 What the proofs need built

The least of each part they use: the lifecycle (section 5), with
`for_run`, the ends and `DESTROY`; the Source and Sink classes, and
the words `source`, `sink` and `stage`; `from_file`, `to_file`,
`to_array`, `count` and `first_value`; and `|` between a source, a
stage and a sink. (As built, before 2026-0022's D5 to D7 and D10:
`for_run` is now one method per role, and `|` ends in `to_arrayref`,
not `to_array`.) Built in that order, as section 15 has it.
