# 2026-0039. Scanning with betterleaks

**Status:** shipped

**Decisions:** D1 settled: betterleaks installed with Homebrew. D2
settled: it replaces gitleaks in CI, not beside it. D3 settled: a
`.betterleaks.toml` allows the redaction examples' placeholders,
rather than a `.gitleaksignore` of fingerprints.

**Origin:** roadmap, added 2026-11-15; started after a message from
DBIx-Squirrel's session, 2026-11-25 (DBIx-Squirrel
387b39980f9c782f82fc927cf7dc31ec12179cbd, its 2026-0029), saying what
its own switch found

**Started:** 2026-11-25, in ab29146f4d73b05ff97ad9db3922aaa959558ea8

**Finished:** 2026-11-25

## Background

gitleaks gets no new rules now; betterleaks, its successor, does. We
scan with gitleaks in CI's `secrets` job, over the whole history, by
hand before a tag (MAINTAINING.md's release step 1, and a trial's),
and on what a commit of docs, tests or a message changed, before it's
pushed (CLAUDE.md).

DBIx-Squirrel made the same switch first, as its 2026-0029, and its
message said what it learned: the Linux release is packaged as
gitleaks' was, a `betterleaks` binary in
`betterleaks_1.10.1_linux_x64.tar.gz`, and takes the same flags;
betterleaks reads a `.gitleaksignore`; and its rules differ from
gitleaks'. Its scans found nothing in DBIx-Squirrel's history.

Ours isn't so clean. Betterleaks 1.10.1, run on this repository on
2026-11-25, reported 9 findings in its history, where gitleaks
reports none, and more in its working tree. Each is a placeholder
in the examples of what `dump_to` redacts (2026-0038), not a secret:

- `generic-credential-uri` on `postgres://app:*REDACTED*@db/app`, the
  redacted DSN the reference, the how-to, their manuals and
  `t/26-dump-to-redacts.t` show, and on `postgres://app:$password\@db/app`
  in `t/26-dump-to-redacts.t` and `Ekorn::Pipeline::Stages::Taps`,
  where the password is interpolated from pieces;
- `generic-password` on `password => '*REDACTED*'` in the same test;
- `generic-credential-uri` on `postgres://user:password@host/db`, in a
  message from Text-Redact-Secrets once in `TODO.md`.

All came from two commits,
797d9074a6b502679a3925513e06657ab361589c and
ec5fe22a09be167503865a36cf1b72427038a1e8. Each finding's secret, as
betterleaks picks it out, is `*REDACTED*`, `$password` or `password`,
sometimes with the `\` of a `\@` after it.

A `.gitleaksignore` of fingerprints would silence the history's, as
DBIx-Squirrel's does `cover_db/digests`: but a scan of the working
tree, before a push, fingers these files by line, and would trip
whenever one is edited, and on each new example of redaction. A
config that keeps betterleaks' rules and allows only those three
secrets does neither. Tried on 2026-11-25, with
`\A(?:\*REDACTED\*|\$password|password)\\*\z` matched against the
secret, the history and every tracked file came up clean, exit 0.
Betterleaks loads a config from the repository only with
`--unsafe-auto-load-config`, so each scan names it with `--config`.

## Decisions

- [x] **D1.** Install betterleaks? Yes, Iain, 2026-11-25, as
  DBIx-Squirrel's D1: `brew install betterleaks`, 1.10.1, on his Mac.
  gitleaks stays installed, as other repositories still use it.
- [x] **D2.** Replace gitleaks in CI, or run both for a while?
  Replace, Iain, 2026-11-25, as DBIx-Squirrel's D3: one scanner, as
  the item said.
- [x] **D3.** The redaction examples' findings: a `.gitleaksignore` of
  their fingerprints, or a `.betterleaks.toml` that allows the
  placeholders? The config, Iain, 2026-11-25: its allowlist is narrow,
  three exact secrets, and holds when lines move and examples are
  added, which fingerprints don't. It costs a `--config` on every
  scan, and differs from DBIx-Squirrel's setup, whose history has no
  such examples.

## The plan

What: scan with betterleaks in place of gitleaks. Why: gitleaks gets
no new rules. Steps: a `.betterleaks.toml` extends betterleaks' rules
with an allowlist of the three placeholders, its comments saying why;
CI's `secrets` job downloads betterleaks 1.10.1, checked against its
SHA-256, and scans the history with the same flags and the config;
MAINTAINING.md's release and trial steps, Security checks and Tools,
and CLAUDE.md's rule on secrets, name betterleaks and the config. Done
when CI's `secrets` job passes with betterleaks, and a scan by hand of
the history and of the tracked files finds nothing.

## What happened

- **Outcome:** as planned. Locally, `betterleaks git --config
  .betterleaks.toml --redact --no-banner --exit-code 1 .` over the
  history, and `betterleaks dir` with the same config over every
  tracked file, find nothing, exit 0; without the config, the history
  gives the 9 findings above. A DSN with a made-up password of 16
  letters and digits, in a scratch directory, is still reported with
  the config, exit 1, so the allowlist lets through only the
  placeholders. CI's `secrets` job runs betterleaks on the commit
  that ships this.
- **Changes from the plan:** none. No `Changes` line, as nothing a
  user sees changed: `.betterleaks.toml`, like the other dotfiles, is
  for the repository.
- **What's left:** nothing here. DBIx-Squirrel's message, which
  started this, needed no answer, and its `TODO.md` entry goes in the
  commit that ships this.
