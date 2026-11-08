# Planned work

## 4. The reference and the how-to on MetaCPAN, as POD manuals

**From:** DBIx-Squirrel-2 871779ac4f818e0a55680f4ef6ba08d69840879c, on `develop`
**Waiting on:** nothing

**What:** Iain noticed that MetaCPAN's page for Ekorn-Pipeline has no
reference or how-to in its Documentation. MetaCPAN lists only POD, and
`docs/REFERENCE.md` and `docs/HOWTO.md` are Markdown, which
`minil.toml` leaves out of the tarball anyway. DBIx-Squirrel fixed the
same gap in the commit above, as its roadmap 2026-0001, with Iain's
decisions: the Markdown stays the source, and a script makes POD
manuals from it, committed as `README.md` is. Do likewise, starting
from its files:

```
git -C ~/Git/github.com/nukopian/DBIx-Squirrel-2 show 871779ac4f818e0a55680f4ef6ba08d69840879c:scripts/manuals
git -C ~/Git/github.com/nukopian/DBIx-Squirrel-2 show 871779ac4f818e0a55680f4ef6ba08d69840879c:xt/manuals.t
git -C ~/Git/github.com/nukopian/DBIx-Squirrel-2 show 871779ac4f818e0a55680f4ef6ba08d69840879c:docs/changes/2026-0001-manuals-on-metacpan.md
```

1. Copy `scripts/manuals` and `xt/manuals.t`, with `%MANUAL` naming
   Ekorn's manuals, such as `Ekorn::Pipeline::Manual::Reference` and
   `::HowTo` (the names are Iain's call), and the footer Ekorn's.
2. Run it. It converts only the Markdown DBIx-Squirrel's docs use, and
   refuses anything else, naming the line: Ekorn's reference may use
   more, such as `####` headings, which it takes, or nested lists,
   which it doesn't. Teach it what's needed, with a test for each,
   rather than changing the docs to suit it.
3. Words Minilla's spelling test flags go in the Markdown as
   `<!-- stopwords: ... -->`; `minil dist` must print
   `Result: PASS`.
4. Link the README and the main module's POD to the manuals by module
   name, not by GitHub URL, and say in MAINTAINING and CLAUDE.md to edit
   the Markdown and run the script.
5. **Check `scripts/coverage`.** In DBIx-Squirrel, `xt/manuals.t`
   loads the script into its process, and Devel::Cover's `Total` then
   counted it, whatever `-select_re '^lib/'` said, taking branch
   coverage from 97.3% to 92.7%. DBIx-Squirrel's `scripts/coverage`
   now adds up `lib/`'s files itself; Ekorn's, if it reads `Total`,
   needs the same.

Changes made to the script here that would suit DBIx-Squirrel too come
back as a message, so the two stay alike.

**Why:** CPAN's users find Ekorn::Pipeline on MetaCPAN, and its
reference and how-to should be there with its modules.

**Done when:** the tarball has both manuals, they pass Pod::Checker,
CI checks they're current, and the rendered POD has been read.
