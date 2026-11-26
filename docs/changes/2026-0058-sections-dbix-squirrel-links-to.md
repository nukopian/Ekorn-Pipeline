# 2026-0058. A check on the sections DBIx-Squirrel links to

**Status:** open

**Decisions:** D1 open: which of its links to check. D2 open: where
the list of them comes from.

**Origin:** roadmap, added 2026-11-26, after DBIx-Squirrel v4.2.0
(DBIx-Squirrel 3d75bd629ad3ea17a37e7ee74b5f56dc984205d4)

## Background

DBIx-Squirrel's documents link to sections of ours on GitHub's `main`.
In its v4.2.0 they link to sixteen: fourteen in `docs/REFERENCE.md`
(`#csv-ekornpipelinecsv`, `#delivering-parts-for-ekorn`, `#gather`,
`#generator-and-yield`, `#json-ekornpipelinejson`,
`#making-each-kind-of-part`, `#named-pipelines`,
`#pipe-and-tap-ekornpipelinepipes`, `#sink_one-and-sink_many`,
`#sinks-ekornpipelinesinks`, `#source`, `#sources-ekornpipelinesources`,
`#stage` and `#the-stop-object`) and two in `docs/HOWTO.md`
(`#coming-from-dbixsquirrel` and `#feed-values-in-as-they-arrive`).

Only some are checked. Its reference's index links thirteen of the
names its Tooling imports from us to seven of those sections, and its
`xt/reference-index.t` reads our installed
Ekorn::Pipeline::Manual::Reference and fails if one of those links no
longer goes where our index sends the name (its 2026-0051;
[neighbours.md](../claude/neighbours.md)). That fails in its CI, and
only after we've released. Its other links, in its guide's and
reference's text, aren't checked by anyone: a heading of ours renamed
sends a reader to the top of the page, with no test failing.

Our `xt/reference-index.t` already checks that each name in our index
links to a heading of our reference. So what's missing is a check,
here and before a release, that the headings DBIx-Squirrel links to are
still there, and that our index still links its thirteen names where
it expects.

## Decisions

- [ ] **D1.** Which of its links does the check cover? The options:
  - every link of its into our documents, all sixteen anchors, in the
    reference and the how-to, and the thirteen names' index links;
  - only the thirteen names' index links, which its CI checks too.

  Recommended: all of them. The unchecked ones are the ones that break
  without a word, and the check costs the same.
- [ ] **D2.** Where does the list come from? The options:
  - written in our test, a list of anchors and of names with the
    section each links to, with a comment naming the DBIx-Squirrel
    release it was taken from; a release of its that adds a link sends
    us a message, as it does for other changes;
  - read from an installed DBIx::Squirrel's manuals, skipping when it
    isn't installed. It follows its links by itself, but it isn't in
    our perlbrew libraries or CI, which would need it, and it would
    make our author tests depend on a distribution that depends on us.

  Recommended: written in our test. It needs nothing installed, and
  the list changes only when DBIx-Squirrel's documents do.
