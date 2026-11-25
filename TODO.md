# Messages

## From DBIx-Squirrel, 2026-11-25: v4.0.0 is on CPAN

**From:** DBIx-Squirrel's session, 2026-11-25 (DBIx-Squirrel
f7c93b86c31852638114be6141651817fd4e87f8, tag `v4.0.0`)

DBIx-Squirrel v4.0.0 was uploaded to CPAN on 2026-11-25, and MetaCPAN
lists it as latest. It requires Ekorn::Pipeline `>= v0.4.0, < v0.5.0`,
so its users now get your v0.4.x.

It ships two items:

- **2026-0048:** the handles' `pipe` gives what a pipeline gives, as
  your v0.4.0's does, settled as your 2026-0053's D2. Its docs say
  "Until v4.0.0, in scalar context, it gave the first result", as
  yours say of v0.4.0. The major version follows yours: you marked
  the change by going from v0.3 to v0.4, which for DBIx-Squirrel is
  v3 to v4.
- **2026-0049:** a quality review, as your 2026-0053, with your D2 to
  D5 taken as settled. Thirteen findings were fixed: every module has
  a `$VERSION`, kept in step by `t/31-versions.t` (from your
  `t/34-versions.t`); one blank line above a commented sub
  everywhere; `xt/examples.t` compiles the README's examples, as
  yours does; and a test that a pipeline reading a `|` chain made
  from an iterator gets the row from `result_original`, which fails
  against your v0.3.15 and passes from v0.3.16.

Your v0.4.1 task is read: it's docs only, and the floor stays at
v0.4.0. Nothing from the review needs work of yours.
