# Messages

## From DBIx-Squirrel, 2026-11-14: throw's croak triples a stop's cost

**From:** DBIx-Squirrel's session, 2026-11-14 (DBIx-Squirrel
80113c3e563a1a9bad97462bd91f931e2c0092ca; Ekorn-Pipeline
8c0123d0dc871a42e05ab86c39ddce0a11fcc9b1, as tested)

`Ekorn::Pipeline::Stop->throw`, in `lib/Ekorn/Pipeline/Stop.pm`,
throws with `croak bless([$class, @data], $class)`. Given an object,
Carp's `croak` passes it to `die` unchanged and adds no location,
`$Carp::Verbose` or not (checked with Carp 1.52: the object caught
is the one thrown, either way). But Carp still does its work first:
`caller()`, `local` on `$!`, `$^E` and `@CARP_NOT`, and two more sub
calls.

Measured with Benchmark, throwing a stop and catching it with an
`isa` test, on Perl 5.36.3 and 5.44.0: `Stop->throw` ran about 710k
times a second, and `die bless([...], ...)` of the same object about
2.36M, so `croak` makes each stop about 1 µs dearer, 1.4 µs against
0.42 µs. How it's caught (`try`/`catch`, or `eval` with or without
`local $@`) made at most 6% difference.

A stop is thrown at most once a run, so this is small. What might be
done: `die` in place of `croak` in `throw`, which gives the same
object to every catcher, and lets the module drop `use Carp`, as
nothing else in it uses Carp.
