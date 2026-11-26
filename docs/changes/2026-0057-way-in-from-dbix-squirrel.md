# 2026-0057. A way in for DBIx::Squirrel's readers

**Status:** open

**Decisions:** D1 open: where it goes. D2 open: what it covers.

**Origin:** a message from DBIx-Squirrel's session, 2026-11-26
(DBIx-Squirrel bfe99ae7d999121c933b1902df007b88752d51b9), added
2026-11-26

## Background

DBIx-Squirrel's README, user guide and reference now come in two parts
(its roadmap 2026-0052 to 2026-0058). Part 1 is DBIx::Squirrel alone:
placeholders, the iterator and stages. Part 2, "With Ekorn::Pipeline",
is data crossing the database's edge: query results to files, JSON and
CSV, loads in batches, and tees. It opens with why the two split, and
sends its readers to Ekorn's README, user guide and reference for the
rest.

So readers come to Ekorn's documents from DBIx-Squirrel's knowing
stages, an iterator's methods and a sink given last to a call, under
DBIx::Squirrel's names, but not Ekorn's sources, feeds or words.
DBIx-Squirrel suggests a short way in for them: what they know already,
under which of Ekorn's names, and where to start. It needs nothing:
its links work as they are.

Ekorn isn't tied to the DBI, so its documents are written for anyone
with values to hand out. A way in for one neighbour's readers mustn't
make the rest read as if Ekorn were part of DBIx::Squirrel.

## Decisions

- [ ] **D1.** Where does it go? A section of its own near the start of
  the how-to, "Coming from DBIx::Squirrel", with a line pointing to it
  from the README; or in the README; or in the reference. The how-to
  is where a reader learns, and its sections already go from stages to
  pipelines; the README is the case for Ekorn, and the reference
  looks up names. Recommendation: the how-to, with the README's line.
- [ ] **D2.** What does it cover? What a DBIx::Squirrel reader knows,
  each with Ekorn's name for it, as a short table or list: stages,
  `Stop` and `gather`, which are the same; an iterator, its methods,
  and Ekorn's way of calling it, which depends on 2026-0056; a sink
  given last; and what's new to them, sources, feeds and the words in
  Factories, each linked to its section. Then where to start.
  Recommendation: that, kept to a screen, its examples checked by
  `xt/howto.t` like the rest.
