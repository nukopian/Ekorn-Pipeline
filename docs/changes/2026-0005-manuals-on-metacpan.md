# 2026-0005. The reference and the how-to on MetaCPAN

**Status:** shipped in v0.1.2

**Decisions:** D1 settled: Markdown stays the source; POD made from it. D2 settled: Ekorn::Pipeline::Manual::Reference and ::HowTo.

**Origin:** a TODO task from DBIx-Squirrel's session (DBIx-Squirrel-2
871779ac4f818e0a55680f4ef6ba08d69840879c), after Iain noticed that
MetaCPAN's page for Ekorn-Pipeline had no reference or how-to

**Started:** 2026-11-08

**Finished:** 2026-11-08

## Background

MetaCPAN's Documentation section lists a distribution's POD: its
modules, and `.pod` files under `lib/`. Ekorn-Pipeline's reference and
how-to are Markdown, in `docs/`, which `minil.toml` leaves out of the
tarball, so v0.1.1's users on MetaCPAN see neither; the README links
to them on GitHub. DBIx-Squirrel had the same gap, and closed it in
its roadmap 2026-0001 with `scripts/manuals`, which makes POD manuals
from the Markdown, and `xt/manuals.t`, which tests it.

## Decisions

- [x] **D1.** Which is the source, Markdown or POD? Markdown, with the
  POD made from it, as Iain decided for DBIx-Squirrel on 2026-11-08,
  and took here with the task on the same day. The Markdown is what
  GitHub shows and the PDFs are made from, and POD has no tables.
- [x] **D2.** What are the manuals called?
  Ekorn::Pipeline::Manual::Reference and
  Ekorn::Pipeline::Manual::HowTo, in `lib/Ekorn/Pipeline/Manual/`,
  Iain decided on 2026-11-08, matching DBIx-Squirrel's.

## The plan

**What:** DBIx-Squirrel's `scripts/manuals` and `xt/manuals.t`, from
871779ac4f818e0a55680f4ef6ba08d69840879c, with `%MANUAL` naming
Ekorn's manuals and the footer Ekorn's, making
`lib/Ekorn/Pipeline/Manual/Reference.pod` and `HowTo.pod` from
`docs/REFERENCE.md` and `docs/HOWTO.md`, both committed.

**Why:** CPAN's users find Ekorn::Pipeline on MetaCPAN, and its
reference and how-to should be there with its modules.

**Steps:**

1. Copy the script and its test, renamed for Ekorn.
2. Run it, teaching it any Markdown Ekorn's docs use that
   DBIx-Squirrel's don't, with a test for each, rather than changing
   the docs to suit it.
3. Words Minilla's spelling test flags go in the Markdown as
   `<!-- stopwords: ... -->`; `minil dist` must print `Result: PASS`.
4. Link the README and the main module's POD to the manuals by module
   name, and say in MAINTAINING and CLAUDE.md to edit the Markdown and
   run the script.
5. Make `scripts/coverage` add up `lib/`'s coverage from its files, as
   DBIx-Squirrel's does, if it reads Devel::Cover's `Total`.
6. Send DBIx-Squirrel a message with what was added to the script, so
   the two stay alike.

**Done when:** the tarball has both manuals, they pass Pod::Checker,
CI checks they're current, and the rendered POD has been read.

## What happened

- **Outcome:** against Done when, met. The tarball has both manuals;
  both pass Pod::Checker with no errors or warnings, every link between
  them resolving; `xt/manuals.t`, which CI's `yath test` runs, fails if
  they're not what the Markdown makes. The rendered POD was read
  through `pod2text`.
- **Changes from the plan:**
  - Ekorn's docs use three things DBIx-Squirrel's don't, which the
    script now handles, each with tests: quotes, the "For stage
    authors" notes, as indented paragraphs (`=over 4` with no items);
    italics, `*run*`, as `I<>`; and a link to `../Changes`, which POD
    can't make to a file, sent instead to where it is on MetaCPAN, by
    a table, `%ELSEWHERE`, of such files. A list in a list, which the
    script had folded into the item's text, is now refused, naming the
    line; the docs have none.
  - Minilla's spelling test flagged "21st" in the reference and
    "backtrace" in the how-to, which their Markdown now gives as
    stopwords. It skips without Test::Spellunker, which is now in the
    5.36 library. It passed at first only because Minilla packs the
    files git tracks, and the new manuals weren't yet; and `minil dist`
    exits 0 even when it fails, so read its `Result:` line.
- **Measurements:** with the old `scripts/coverage`, loading the script
  into `xt/manuals.t` took coverage from 100% branch to 86.5%, below
  every floor but pod's; added up from `lib/`'s files, it's 100%
  statement, branch and subroutine, and 96.3% condition, as before.
- **What's left:** nothing here. The message to DBIx-Squirrel, step 6,
  follows this commit.
