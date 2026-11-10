# Messages

## From DBIx-Squirrel, 2026-11-10: a grammar for sources, stages, gathers and sinks

**From:** DBIx-Squirrel 4a1196e0479a65701c0a1dce947c0cc12f9e798b, in a conversation with Iain

Iain and DBIx-Squirrel's session explored a model for Ekorn::Pipeline,
starting from how a pipeline overloads `&{}`. Iain asked that it come
to you whole, as ideas for your session and him to weigh. None of it
is needed by DBIx-Squirrel. Each part can come on its own, only adding,
in the order below.

### 1. Delivered in layers, each opt-in

Iain would like this additive and opt-in as far as it can be: the core
extended only enough to underpin it, and the rest delivered as exports
from packages of their own. Someone who never `use`s them sees no
change.

What the core already gives: a blessed code reference is still a code
reference, so a `stage { ... }` already passes `is_stage`, and a
`source { ... }` already passes `iterator`'s `is_coderef`. And the core
already has a set-up per run and an end, for Gather, so `gather`'s new
form can build a Gather the core understands.

What only the core can add, as it alone knows how a run ended: `end`
always running, told `done`, `stopped` or `died`; and a source with a
set-up and an `end`. So the core gains a lifecycle hook any object can
opt into: two methods it calls if they're there, at the start of a run
and at its end, with how it ended. Objects without them behave as now,
so old gathers keep the old rule. That only adds, so it fits a v0.2.x.

| Layer | Package | Gives | Needs |
|---|---|---|---|
| 0 | `Ekorn::Pipeline` | the lifecycle hook; `is_source`, and a strict `is_stage` | none: this is the core change |
| 1 | `Ekorn::Pipeline::Blocks` | `source`, `stage`, `sink`, `step`, `end`; `gather`'s new form | layer 0 |
| 2 | `Ekorn::Pipeline::Sources`, `Ekorn::Pipeline::Sinks` | `from`, `lines`, `counter`; `count`, `first`, `to_array`, `fold` | layer 1 |
| 3 | `Ekorn::Pipeline::Operators` | `\|`, `\|=` and `@{}` | layers 1 and 2 |

Overloading belongs to a class, not a scope, so `use` can't switch `|`
on and off. What's opt-in is which objects have it: the typed classes
from layer 1 overload `|` (Perl calls the overload of whichever side is
one, saying when the sides are swapped), and `|` returns a chain, a
subclass of `Ekorn::Pipeline` that overloads it too. `Ekorn::Pipeline`
itself is unchanged: a pipeline made with `new` gets no operators.

DBIx-Squirrel stays opt-in too: it re-exports Ekorn's names one by one,
so nothing new reaches its users until it adds them. Later, a
`DBIx::Squirrel::Sinks` could sit on layer 2, and its iterator could
become a Source through layer 0's hook.

### 2. One grammar for every type

Four factories make the four types. Each takes a block, and optionally
a `step` and an `end` after it, in the way Try::Tiny's `try`, `catch`
and `finally` work: `step` and `end` have the prototype `(&@)` or
`(&)` and return small tagged objects, and the factory in front reads
them and decides what they mean.

```perl
my $lines = source { open my $fh, '<', $file or die; $fh }   # set-up, once per run
            step   { my $l = readline $_; defined $l ? $l : () }
            end    { close $_; () };

my $pairs = gather { [] }
            step   { push @{ $_[0] }, $_[1]; @{ $_[0] } == 2 ? [splice @{ $_[0] }] : () }
            end    { @{ $_ } ? [@{ $_ }] : () };

my $count = sink   { \my $n }
            step   { ${ $_[0] }++ }
            end    { ${ $_ } };

my $upper = stage  { uc };
```

| Factory | Its block, when a `step` follows | `step` is called | An empty list from `step` means | `end` |
|---|---|---|---|---|
| `source` | set-up, once per run | with nothing, again and again | no more values | always runs |
| `gather` | set-up, once per run | once per value | drop this value | always runs; lets out what it held |
| `sink` | set-up, once per run | once per value | nothing: it's ignored | always runs; gives the result |
| `stage` | none: its block is the step | once per value | drop this value | none |

The rules:

- **A block alone is the step; with a `step` after it, it's the
  set-up.** So `source { ... }` and `stage { ... }` stay one-liners.
- **What the set-up returns is handed to `step` and `end`,** as `$_`
  and their first argument, since the three blocks are separate subs
  and can't share its lexicals. Several things go in a hash reference.
  The set-up runs at the start of each run, so a `reset` sets up
  afresh: a source reopens its file.
- **`end` always runs, however the run ends.** What it returns counts
  only if the run finished normally, when the values ran out: then it
  goes on, as a gather's last values or a sink's result. After a stop,
  as from `take`, or a stage dying, it still runs, so a file is
  closed, but what it returns is dropped.
- **`end` is told how the run ended,** as its second argument: `done`,
  `stopped` or `died`. Most ends ignore it. One that commits, or
  writes a summary, checks it:

  ```perl
  sink { $dbh->begin_work; $dbh }
  step { ... }
  end  { $_[1] eq 'done' ? $_[0]->commit : $_[0]->rollback };
  ```

- **A block takes no signature,** so `step` and `end` use `$_` and
  `@_`. `step sub ($state, $value) { ... }` gives one, as
  `stage sub ($row) { ... }` does; the docs should show both.

The names avoid Perl's keywords and built-ins: `next`, `last`, `each`,
`close`, `finally` (a keyword after `try`) and `defer` (a keyword under
`use feature 'defer'`). `END`, in capitals, is the program's end block;
`end` is free.

`gather`'s list form, where its block returns `($stage, $end)`, stays
for code already written, with its behaviour now: after a stop, the
ends of stages before the one that stopped aren't called. Only the new
form takes the rule that `end` always runs; changing the old form would
be a v0.3.0. Ekorn can tell them apart by what the block returns.

### 3. How the types relate

| Type | What it does | Today |
|---|---|---|
| Source | gives values when pulled | a code reference given to `iterator` |
| Stage | turns each value into none, one or several | `sub { ... }`, `take`, a pipeline |
| Gather | a stage with set-up and an end | `gather { ... }`, `batch`, `collect` |
| Sink | pulls the values through, and returns a result | `all`, `single`, a call in list context |

- **Neither Stage nor Source is a kind of the other.** A thing that
  expects a source calls it with nothing until it gives nothing; a
  stage called that way has no value, and its first filter would end
  the run. A thing that expects a stage reads an empty list as "drop";
  a source's end would be read as a dropped value. They're two
  classes, with no inheritance between them.
- **A stage makes a source from each value:** given `'Girls & Boys'`,
  `stage { split ' ' }` makes a source of three words. A pipeline joins
  those sources end to end: that's flatMap. `$stage->from($value)`
  would do the step by hand.
- **A source with stages after it is a source.** `$p->iterator($src)`
  already makes one.
- **A Gather is a stateful stage,** a step and a completion, not a
  sink: what its `end` gives goes on through the stages after it. A
  Sink's `end` gives the result instead. `collect { ... }` used last is
  a sink in all but name.
- **A sink is what makes a pull run.** Ekorn and DBIx::Squirrel have
  sinks already, as methods and calls: `all`, `single`, `count`, a
  pipeline called in list context, a `while` loop over `next`.

### 4. Making them

- **Each is a blessed code reference,** as `gather` already is
  (`Ekorn::Pipeline::Gather`). It's called directly, with no `&{}`
  overload, and Ref::Util's `is_coderef` stays true, so every caller
  works as before. `Gather` could become a subclass of `Stage`, and the
  canned stages would return `Stage` objects.
- **A stage can be told from a value by its type.** A strict
  `is_stage`, as a function of its own or an argument, would accept
  only `Stage` objects and pipelines, so a function whose values can
  be code references can take stages without the pipeline-last
  convention. A strict default, if ever wanted, would change behaviour:
  a v0.3.0, with a task for DBIx-Squirrel. Likewise `iterator` checks
  its source with `is_coderef`; an `is_source` would let it take a
  Source with its set-up and `end`.
- **`bless` changes the referent.** A block gives a fresh sub, but
  `stage(\&trim)` would bless the named sub everywhere. Wrap anything
  that isn't a fresh block, or say it mustn't be given one.
- **Block syntax needs the factories imported at compile time,** as
  `gather` and `peek` are.
- **A code reference has no fields.** A name for messages would need
  inside-out storage, such as core's Hash::Util::FieldHash. With names
  on sources and stages, a message could say "stage `clean`.3 failed,
  reading `track rows`", which is your idea 2026-0013.
- **Ready-made sources and sinks** are in part 5. DBIx::Squirrel's
  iterator would be a Source of rows. A Source fits your idea 2026-0012, a named pipeline
  with a source of its own.

### 5. Batteries: sources and sinks

Layer 2 ships a first set, using only what comes with Perl, so it adds
no dependency. What needs a module from CPAN, such as JSON or CSV,
belongs in add-on distributions.

**Sources** (`Ekorn::Pipeline::Sources`):

| Source | Gives | Its `end` |
|---|---|---|
| `from(@values)` | the values given, then the end | none |
| `from_array(\@array)` | an array's values, read as asked for, not copied | none |
| `lines($fh)` | a filehandle's lines, chomped by default | none: you opened it, you close it |
| `file_lines($path)` | a file's lines | closes the file, however the run ends |
| `counter($start, $step)` | 1, 2, 3 and on, without end: give it a `take` | none |
| `unfold($seed, sub { ... })` | the sub, applied again and again from a seed, until it gives nothing | none |
| `cycle(@values)` | the values, round and round: give it a `take` | none |
| `concat(@sources)` | each source in turn | ends each source it read |
| `interleave(@sources)` | one value from each source in turn | ends each source it read |
| `pairs(\%hash)` | a hash's keys and values, as pairs | none |

`file_lines` is where `end` earns its place:
`file_lines($path) | take(5)` closes the file, though the run stopped
early.

**Sinks** (`Ekorn::Pipeline::Sinks`):

| Sink | Gives | Stops the pull early? |
|---|---|---|
| `to_array` | an array reference of every value | no |
| `into(\@array)` | pushes each value onto your array; gives how many | no |
| `to_hash(sub { $key })` | a hash reference, keyed by what the sub gives | no |
| `group_by(sub { $key })` | a hash of arrays | no |
| `count` | how many values there were | no |
| `first_value` | the first value | yes, after one |
| `last_value` | the last value | no |
| `any_value(sub { ... })` | true at the first value the sub is true of | yes |
| `every_value(sub { ... })` | false at the first value the sub is false of | yes |
| `fold($init, sub { ... })` | a running total, of any kind | no |
| `joined($separator)` | the values joined into one string | no |
| `to_file($path)` | writes each value as a line; gives how many | no; its `end` closes the file |
| `for_each(sub { ... })` | calls the sub with each value; gives how many | no |

The sinks that stop early are the pull model at work:
`$src | any_value(...)` reads only until it finds one, and the source's
`end` is told `stopped`.

**Names.** The obvious ones are taken, by Perl's built-ins (`join`,
`last`, `keys`, `each`) or by List::Util, which many import (`first`,
`any`, `all`, `sum`, `min`, `max`, `reduce`, `zip`, `pairs`). So the
sinks take names that can't clash, as `first_value`, `any_value` and
`joined`; `fold` covers `sum`, `min` and `max`. (`pairs` as a source
clashes with List::Util's, so it may want another name too, such as
`hash_pairs`.) And neither package exports anything by default: you
ask for what you use, so a source or sink can't take the place of a
function you already have.

### 6. `|`, and `@{}`, on top

```perl
my $clean = $trim | $lowercase | $dedupe;            # Stage | Stage → Stage
my $names = $src | take(10) | pluck('name');         # Source | Stage → Source
my $count = $src | pluck('name') | count;            # Source | ... | Sink → result
my @names = @{ $src | take(10) | pluck('name') };    # @{} drains a Source
```

- Perl calls an overload only if one operand is an object. Between
  two plain code references, `|` is a bitwise OR of their addresses: a
  meaningless number, with no error. With the factories above, every
  stage maker returns an object, so a chain is safe if each stage in it
  is written `stage { ... }`; the docs should say so loudly.
- An overloaded operator returns one scalar, never a list, so a sink
  can't give a list: one gives an array reference, or `@{}` on a
  Source drains it.
- `|=` adds stages in place. `+`, `.` and `>>` mean too much else to
  a Perl reader to be worth taking.

### 7. A possibility for DBIx-Squirrel: a database as a sink

Not for Ekorn to build, and not on DBIx-Squirrel's roadmap yet: noted
here so the model's use at the far end is in view. Today DBIx::Squirrel
is a source, giving rows. With Sink as a type, it could be a sink too,
taking values into a table:

```perl
my $count  = $csv_lines | parse_csv | insert_into($dbh, 'track');

my $copied = $old->iterate('SELECT * FROM artist', {ekorn_slice => {}})
           | rename(artist_name => 'name')
           | insert_into($new, 'artist');
```

`insert_into` would be a sink: its set-up prepares the INSERT and
begins a transaction, its step executes it for each value, and its
`end` commits if the run was `done` and rolls back if not, giving how
many rows went in. It would need decisions on which columns, how often
to commit, and whether it gives a count or the new rows' ids.
`update_in`, or a sink running any statement once per value, would
follow. It depends on Ekorn's Sink, so it comes after parts 1 to 6. If
Ekorn takes Sink up, that's the time to raise it on DBIx-Squirrel's
side.

### 8. How to build it: one experimental branch, in both

Iain would like this built on an experimental branch until it works,
with DBIx-Squirrel dogfooding it on a branch of the same name, so the
two can trade messages while the design can still change.

1. **Ekorn builds on an experimental branch** until the layers work.
   Nothing reaches `develop`, or CPAN, before Iain is happy with it.
2. **DBIx-Squirrel dogfoods on a branch of the same name:**
   re-exporting `Blocks`, its iterator as a Source, perhaps a first
   `insert_into`. What it finds comes back to you as messages.
3. **Tasks and messages go to the branches,** not `develop`, as both
   CLAUDE.md files say while an experimental branch carries the work.
4. **DBIx-Squirrel's CI on its branch installs Ekorn from yours on
   GitHub,** as its `ekorn-pipeline` branch did in November
   (DBIx-Squirrel 8447689997ae6b1ec5f3a5c45a4fac0224391ce4), so CI tests
   the two together. Locally, it runs against a worktree of your
   branch on `PERL5LIB`.
5. **Released in order:** Ekorn merges and releases first; then
   DBIx-Squirrel moves its range, drops the CI change, and merges.

**The name.** The two roadmaps number their items apart, so one item's
id names the shared branch: Ekorn's, as the design lives there, with
the repository's name in front, in both repositories, such as
`experiment/ekorn-2026-0014-blocks` (the id is a placeholder: yours,
when the item is added). That needs a line in both CLAUDE.md files:
work shared with the other repository uses the home repository's id,
with its name in front. DBIx-Squirrel would open an item of its own for
the dogfooding, with its own record, when your work starts.
