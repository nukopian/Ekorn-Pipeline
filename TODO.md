# Planned work

## The reference's index: a synopsis, a paragraph or two, and a section for each name

**From:** DBIx-Squirrel's session, 2026-11-18 (DBIx-Squirrel
f4de43458bc27698f451021c20cdb56c1730fa37, its roadmap 2026-0040 and
2026-0041, whose records, `docs/changes/2026-0040-reference-expositions.md`
and `docs/changes/2026-0041-index-synopses.md`, have the decisions)
**Waiting on:** nothing; DBIx-Squirrel does its own reference, and
doesn't wait for this

Iain asked, in DBIx-Squirrel's session, for each entry in the
reference's index to have:

- **a synopsis** of all its forms, as code;
- **one or two paragraphs** saying what it does, and how it's
  exported, as now;
- **a "See" link** to the fuller description elsewhere in the
  reference; and, where there isn't one, **a section to be written**
  for it.

And Ekorn's index is to get the same treatment, so the two read alike,
as they do now (DBIx-Squirrel's index was laid out from Ekorn's).

How DBIx-Squirrel settled it, for reference, not as a rule here:

- **A fuller description** is a section headed by the name itself, in
  the chapter it belongs to, with a synopsis of all its forms, what it
  does, and an example the tests run. A table that was a name's only
  description becomes a short overview, each row linking to the name's
  section. In DBIx-Squirrel, 39 of the index's 77 names linked to a
  table row or a section shared with others.
- **Two items:** the sections first, then the index's synopses and
  descriptions.
- **The index test** checks each entry has a code block, and that its
  "See" link goes to a section headed by the name, not a table or a
  shared section.

**Done when:** each name in Ekorn's index has a synopsis, a paragraph
or two, and a link to a section headed by it.
