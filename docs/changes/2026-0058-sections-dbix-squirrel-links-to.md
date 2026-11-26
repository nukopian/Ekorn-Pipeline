# 2026-0058. A check on the sections DBIx-Squirrel links to

**Status:** shipped

**Decisions:** D1 settled: every link, all sixteen anchors and the
thirteen index links. D2 settled: listed in our test.

**Origin:** roadmap, added 2026-11-26, after DBIx-Squirrel v4.2.0
(DBIx-Squirrel 3d75bd629ad3ea17a37e7ee74b5f56dc984205d4)

**Started:** 2026-11-26

**Finished:** 2026-11-26

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

- [x] **D1.** Which of its links does the check cover? Every link,
  all sixteen anchors and the thirteen names' index links, as Iain
  decided on 2026-11-26, as recommended. The options were:
  - every link of its into our documents, all sixteen anchors, in the
    reference and the how-to, and the thirteen names' index links;
  - only the thirteen names' index links, which its CI checks too.

  Recommended: all of them. The unchecked ones are the ones that break
  without a word, and the check costs the same.
- [x] **D2.** Where does the list come from? Written in our test, as
  Iain decided on 2026-11-26, as recommended. The options were:
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

## The plan

**What:** an author test, `xt/dbix-squirrel-links.t`, that fails if a
heading DBIx-Squirrel's documents link to goes from our reference or
how-to, or if our reference's index stops linking one of the thirteen
names DBIx-Squirrel's index uses to the section it expects.

**Why:** today a renamed heading breaks DBIx-Squirrel's CI only after
we release, and breaks its unchecked links without a word.

**Steps:**

1. List the sixteen anchors and the thirteen names, with the section
   each expects, in the test, as of DBIx-Squirrel v4.2.0 (D2).
2. Read each document's headings as GitHub makes their anchors, as
   `xt/reference-index.t` does, outside code, and, in the reference,
   only above the index: `#### source` and `#### stage` there make
   `#source` and `#stage` too, but DBIx-Squirrel's links mean the
   sections, so a renamed section mustn't pass on the index's heading.
3. Read the section each name in our index links to, its first
   listing's, as DBIx-Squirrel's test does.
4. Break a heading and a link in a scratch copy, to see it fail.
5. Say in `docs/claude/neighbours.md` that the test is there.

**Done when:** an author test fails if one of those headings goes or
one of those index links moves, and neighbours.md says the test is
there.

## What happened

- **Outcome:** met. `xt/dbix-squirrel-links.t` passes on `develop`.
  Run against a scratch copy of the docs, with "The stop object" and
  `stage` renamed in the reference, "Feed values in as they arrive"
  in the how-to, and `from_csv`'s index link sent to the Sources
  section, each of its three checks failed, naming each break: the
  renamed `stage` heading among them, though the index has a `####
  stage` of its own.
- **Changes from the plan:** none.
- **No line in `Changes`,** as the test isn't in the distribution and
  changes nothing for users, as 2026-0039 shipped.
