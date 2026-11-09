# 2026-0006. Plain docs

**Status:** in progress

**Decisions:** None.

**Origin:** roadmap, added 2026-11-09, after 2026-0004's text was
rewritten plainly and read more easily; Iain moved it to Now the same
day, ahead of v0.1.3

**Started:** 2026-11-09

## Background

The docs grew a house style, written to match one another, that makes
them hard to read: the same word several times in a sentence; chains
of "as X says"; long sentences joined by commas, colons and
semicolons; and qualifiers that repeat each other. 2026-0004's text
(adf919e64fc2028238bb408e98a9b4f587b0845f) was rewritten without them,
and read better.

## The plan

**What:** a plainness pass over the README (`README.pod`), the POD of
every module, `docs/REFERENCE.md`, `docs/HOWTO.md` and
`docs/MAINTAINING.md`.

**Why:** a reader new to the pipeline meets the docs before the code;
they should be easy to read.

**Rules for the pass:**

- Say what the text said: no claim added, dropped or changed. Where a
  sentence turns out to be wrong or unclear in what it says, fix it,
  and note it here.
- One idea a sentence, where that reads better. A short sentence
  beats a list of clauses.
- Name a thing once, then "it", unless that's unclear.
- Link once to a section, and not in a chain of "as X says".
- Keep the examples, the headings and the anchors other pages link to,
  and the DIAGNOSTICS entries, which match the messages.
- Plain words: "use" not "make use of", "unchanged" not "as they are".

**Steps:** one commit for each: the README; the modules' POD; the
reference; the how-to; MAINTAINING. Each regenerates the manuals or
`README.md` as needed, and passes the tests, `xt/manuals.t`,
`podchecker` and Minilla's spelling test.

**Done when:** each document has had the pass, every example still
prints what it says, and Iain has read the PDFs of the README, the
how-to, the reference and MAINTAINING.

## What happened

- **The README:** rewritten. Two claims were out of date and are
  fixed: "It isn't on CPAN yet" (v0.1.1 and v0.1.2 are), now with
  `cpanm Ekorn::Pipeline`; and "DBIx::Squirrel is moving onto it",
  which it did in v2.0.5. The parts for building a module of stages
  are a list.
- **The modules' POD:** rewritten. Gather's DIAGNOSTICS still gave its
  message as "#%d"; it's "#%s" since 2026-0004, and now says so.
- **The reference:** rewritten. Its section on `gather` still gave the
  bad-block message as "#%d"; it's "#%s". "Say what the first stage is
  given, and number your own stages into it" was unclear: it now says
  that a function putting its own stages first should say so, as error
  messages count them in a stage's position. Its 48 examples print what
  they say.
- **The how-to:** rewritten. Its examples print what they did before
  the pass, compared run against run.
