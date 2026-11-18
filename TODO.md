# Planned work

## The reference's index says how to use a name; the reference text shows it in context

**From:** DBIx-Squirrel's session, 2026-11-18 (DBIx-Squirrel
9d81728743078097f3c74518c15ff40368ddf98c, its roadmap 2026-0040 to
2026-0042, whose records, in `docs/changes/`, have the decisions).
Revised the same day: the first version of this task, in 6437537,
asked for a section headed by each name, which DBIx-Squirrel then
reversed.
**Waiting on:** nothing; DBIx-Squirrel does its own reference, and
doesn't wait for this

Iain asked, in DBIx-Squirrel's session, for the reference's index and
its text to divide the work, and for Ekorn's to get the same
treatment, so the two read alike:

- **The index is for direct lookup.** Each entry has a synopsis of all
  the name's forms, as code; a paragraph or two saying what it's for,
  and how it's exported; and a "See" link to where the reference text
  shows it in use.
- **The reference text is for use in context.** The section the index
  links to discusses the name in context, with examples, in much
  greater detail. It doesn't repeat the synopsis or the defining
  paragraph, which are the index's. Where no section shows a name in
  use, one is written.
- **An entry says "Exported by default." or "Exported on request.",**
  not "By default." or "On request.", which Iain found read worse,
  leaving the reader to work out what was by default. Added to this
  task the same day (DBIx-Squirrel
  ddafdd77b1e892e4838ac8e1b23085b632e70317, where its index test
  looks for the new wording).

How DBIx-Squirrel settled it, for reference, not as a rule here:

- **Every section the index links to** dropped its synopsis and its
  defining paragraph, the long-standing ones included, and opens on
  when or why to use the name. A section showing forms that have no
  index entry, such as the `use` forms or the functions the Sugar
  makes, keeps its synopsis, as it's the only place they're shown.
- **Names are discussed together** where they're used together: one
  section for the iterator's methods, for the select methods, for
  taking and dropping, and so on, with examples of each. Tables that
  only defined each name went, as the index has the definitions.
- **The index links** each name to the heading of the section that
  discusses it, not necessarily one named for it.
- **The index test** checks each entry has a synopsis, that its link
  reaches a section of the reference, and that none of those sections
  opens with a synopsis.

**Done when:** each name in Ekorn's index has a synopsis, a paragraph
or two, and a link to a section showing it in use that doesn't repeat
them.
