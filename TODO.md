# Messages

## From DBIx-Squirrel, 2026-11-25: our iterator's all_arrayref shipped

**From:** DBIx-Squirrel's session, 2026-11-25 (DBIx-Squirrel
42c61527fe1c2050270d09c5fa063d2cc0a48464)

DBIx::Squirrel::Iterator has its own `all_arrayref`, matching yours
from 2026-0055: DBIx-Squirrel's roadmap 2026-0050, now on `develop`,
unreleased. It's `return scalar $self->all`, the same name, and gives
an empty array reference when no results are left, with the run ended
`done` and the statement finished.

It doesn't call Ekorn's `all_arrayref`, so it needs no Ekorn release:
our range stays at >= v0.4.0, < v0.5.0, and v0.4.2 needs nothing from
us. Our tests passed on 5.36 and 5.44 against your working copy at
60754fd66a6a2711af43e0676fe0db14b58e9679, and in CI against CPAN's
Ekorn::Pipeline.

# Planned work

## betterleaks passes over cover_db in a scan of the working tree

**From:** DBIx-Squirrel's session, 2026-11-25 (DBIx-Squirrel
42c61527fe1c2050270d09c5fa063d2cc0a48464), at Iain's request.
**Waiting on:** nothing; DBIx-Squirrel gates its messages here on a
scan of the file it commits, and doesn't wait for this

`betterleaks dir . --config .betterleaks.toml` fails in a working copy
that has run `scripts/coverage`: it reports `generic-api-key` twice,
on line 1 of `cover_db/digests`, Devel::Cover's digests of the files
it covered. They aren't secrets, and `cover_db/` is git-ignored, so
`betterleaks git` and CI never see it; but a scan of the working tree,
as before a commit, stops on them, and a finding stops the work. A
fingerprint in `.gitleaksignore` won't hold, as the digests change
with each coverage run.

**What:** a second allowlist in `.betterleaks.toml`, by path, below
dump_to's, with a comment saying why. This one was tried against
Ekorn-Pipeline 31d92d618971f838963279475a8aaf20994a330e, on a copy of
the config, and both `betterleaks dir .` and `betterleaks git .` were
clean with it:

```toml
# Devel::Cover's coverage database, git-ignored, never committed.
[[allowlists]]
description = "Devel::Cover's cover_db, which scripts/coverage writes"
paths = ['''(?:\A|/)cover_db/''']
```

**Done when:** after `scripts/coverage`, `betterleaks dir . --config
.betterleaks.toml --no-banner` exits 0, and `betterleaks git . --config
.betterleaks.toml --redact --no-banner` still does.
