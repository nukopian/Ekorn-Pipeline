# Roadmap

What Ekorn-Pipeline means to do, and why. [Changes](Changes) says what
each release did, and the [README](README.md) what it is now.

Last id: 2026-0039.

Items come in four groups:

- **Now:** being worked on, each with a paragraph and a link to its
  [change record](docs/changes/README.md); never more than three, so
  that it stays a queue;
- **Next:** decided, but not started: what, why, and when it's done;
- **Later:** meant to be done, but not yet planned, in a line or two;
- **Ideas:** might be done, or never; kept so they aren't lost, in a
  line or two, newest last.

Now, Next and Later put the most useful first.

Each item has an id, its year and a serial, such as 2026-0001. The year
is when the item was added, and the serial counts from 0001, starting
again each year. An id is given when the item is added, whichever group
it goes in, and is kept as the item moves, so that 2026-0001 means the
same item in a commit message years later. It names the item's change
record, its line in Changes ("(roadmap 2026-0001)") and any branch for
it. The line above gives the last id allocated.

Each item has a size too, a guess at how much work it is, as a T-shirt
size and its story points: XS 1, S 2, M 3 and L 5. Sizes compare items
with each other; they aren't a measure of time. An item bigger than L
is split into items that aren't, each saying what it was split from.
An item that can't be done before another says so ("Depends on:"), and
is never in a group ahead of it.

An item whose questions aren't all settled says so, and its record
lists them. Work on it starts only once each is settled, or moved to
another item or task.

When an item ships, it leaves here for Changes. An item that's
dropped is deleted, and the commit that drops it names its id.

## Now

Nothing yet.

## Next

### 2026-0038. Secrets redacted by dump_to

**Size:** S (2). **Split from:** 2026-0036. **Depends on:**
Text-Redact-Secrets 2026-0001, its first release.

`dump_to` redacts what it writes whenever
[Text::Redact::Secrets](https://github.com/nukopian/Text-Redact-Secrets)
is installed and passes a self-test, so a dump sent to a log doesn't leak
a password, a token or a DSN; it croaks if the module is there but
fails, and a `local`ised `$Ekorn::Pipeline::Stages::Taps::DumpSecrets`,
true, turns it off. Without the module, nothing changes, so it adds no
dependency. A v0.3.x. Every question is settled in its
[record](docs/changes/2026-0038-dump-to-redacts.md).

**Done when:** `dump_to` does so, tested with the module, without it,
and with one that fails, with `$DumpSecrets` too; documented in the
POD, its DIAGNOSTICS, the reference and the how-to, and in `Changes`;
and DBIx-Squirrel sent a message, as it imports `dump_to`.

## Later

Nothing yet.

## Ideas

An idea is a numbered heading, the date it was added, its size, and a
line or two on what and why. Each is kept, promoted to Later or Next
with its id, or dropped, as Iain decides.

### 2026-0039. Scan for secrets with betterleaks

Added 2026-11-15. **Size:** S (2).

Scan with betterleaks, gitleaks' successor, in place of gitleaks, once
it's settled: in CI's job over the whole history, and in the scans by
hand before a push and a tag that CLAUDE.md and docs/MAINTAINING.md
give. gitleaks gets no new rules, so its scans will slowly miss the
newer kinds of secret that only betterleaks finds.
