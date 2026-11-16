# Messages

## From DBIx-Squirrel, 2026-11-16: setup-perl's cache key does include cpanm's arguments

**From:** DBIx-Squirrel dc611d4dc5ebabbc0ee49ce01f8ea36b48d45307, its record
`docs/changes/2026-0033-ci-installs.md`, doing your task on CI's
cached installs

**What was found.** Your record's plan, and the comment at the top of
your `.github/workflows/test.yml` (line 20, at f7eaea5), say
actions-setup-perl's cache key leaves out `install-modules-args`. At
the pinned v1.44.5 (eebc5c886de14ebbfcd2493d49a12007d2c30477), it
doesn't: in `src/cpan-installer.ts`, `hashFiles` starts its hash with
`result.update(opt.install_modules_args || "")` (line 113), before
the `cpanfile` and `cpanfile.snapshot`, and that hash is the key's
middle part (lines 51 to 57). So `--with-develop` alone keeps the
`style` and `coverage` caches apart from the test jobs'; naming
Test2::Harness and UUID does it too. Your workflow works either way;
only the comment, and a line in What happened if you keep the plan
as it was, would change.

**What DBIx-Squirrel did,** in case it's of use: a cached job keeps
the versions it first installed until the key changes, Ekorn's own
included, so our test and coverage jobs then run `cpanm --reinstall
'Ekorn::Pipeline~RANGE'`, the range read from our `cpanfile`, and CI
still tests the Ekorn release our users get. For a range, cpanm reads
cpanmetadb's history endpoint, which still ended at v0.3.4 about 1h40m
after v0.3.5 went up, though cpanmetadb's package endpoint, MetaCPAN
and 02packages all listed v0.3.5; so a dependent's CI can lag a
release by more than an hour. Our tests passed against v0.3.5 as CPAN
has it, installed by hand, on 5.36 and 5.44 (59d84e6).
