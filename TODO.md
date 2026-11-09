# Messages

## From DBIx-Squirrel, 2026-11-09: Iain on 2026-0008, messages that say what's accepted

**From:** DBIx-Squirrel 5a9a38d44b2ba52b4c0ac8a2ad9bc15ba15dde62

Iain said, on 2026-11-09, in DBIx-Squirrel's session: "We dropped the
ball in Ekorn-Pipeline on this one: let's make sure that every
diagnostic message that is emitted because we did not supply a code
reference or a pipeline says that, and every reference to those
messages in documentation and comments also says that. We are no
longer JUST accepting code-references."

That's your roadmap 2026-0008, and it widens its Done when a little:
**comments** too, not only messages, DIAGNOSTICS, the reference and the
how-to. A sweep of `lib` at 182cf5ef0cad25b39fe3498df3459dc878b6c2d1
finds these where a stage is expected:

- `lib/Ekorn/Pipeline.pm` lines 39 and 43, and
  `lib/Ekorn/Pipeline/Errors.pm` line 72: "Expected stage #%d to be a
  code reference". Its DIAGNOSTICS, line 483.
- `lib/Ekorn/Pipeline.pm` line 127: "Expected stage #%s, made with
  gather, to return one or two code references". Its DIAGNOSTICS,
  line 493, and `Gather.pm` line 146.
- The manuals quote them: `docs/HOWTO.md`'s example printing "Expected
  stage #2 to be a code reference" (the how-to's POD, line 956), and
  `docs/REFERENCE.md` (the reference's POD, lines 199 and 692).

"Expected a code reference" is raised for a `gather` block, an
iterator's source, and the blocks of `take_while`, `drop_while`,
`collect`, `peek` and the batch stages, none of which is a stage, so it
looks right as it stands, unless you decide any of those should take a
pipeline.

DBIx-Squirrel has done its part (5a9a38d): its own message for a
statement's definition is now "Expected only code references or
pipelines after the statement for %s". Its copies of your two messages
wait for v0.2.0's task, and their explanations already say "a code
reference or a pipeline". If you word yours "...to be a code reference
or a pipeline", the two will read alike.
