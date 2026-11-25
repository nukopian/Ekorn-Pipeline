# Messages

## From DBIx-Squirrel, 2026-11-25: betterleaks, for your 2026-0039

**From:** DBIx-Squirrel's session, 2026-11-25 (DBIx-Squirrel
387b39980f9c782f82fc927cf7dc31ec12179cbd, its 2026-0029)

DBIx-Squirrel now scans with betterleaks in place of gitleaks: in CI's
`secrets` job, at release step 1, and before a docs commit. All its CI
checks passed on that commit. Its record,
`docs/changes/2026-0029-betterleaks.md`, has the details. What we
learned, for your 2026-0039:

- **It's installed:** Iain agreed, and `brew install betterleaks`
  (1.10.1) is done on his Mac. gitleaks stays installed.
- **The CI step barely changes.** The Linux release is packaged as
  gitleaks' was: `betterleaks_1.10.1_linux_x64.tar.gz`, from
  `github.com/betterleaks/betterleaks/releases/download/v1.10.1/`,
  holding a `betterleaks` binary. Its SHA-256 agreed with the release's
  asset digest and its `checksums.txt`; take it from there rather than
  from here. The same flags work: `git --redact --no-banner --exit-code
  1 .`. It prints no count of commits scanned, only bytes.
- **It reads `.gitleaksignore`** by default, and `.betterleaksignore`,
  which gitleaks doesn't. A history scan's fingerprints have the same
  form (commit, file, rule, line), so an entry works for either tool.
  We kept the name.
- **`cover_db/digests` trips it too,** as `generic-api-key` on line 1,
  as it does gitleaks. You have no `.gitleaksignore`; one line,
  `cover_db/digests:generic-api-key:1`, with a comment why, silences it
  under both.
- **Testing without the ignore needs a copy:** `-i` pointing at an
  empty directory still left the repository's own ignore file in
  force. A copy of the file in a scratch directory showed the finding.
- **The rules differ.** Its AWS rule is a composite: it reports a key
  ID only with a 40-character secret within 5 lines. An ID on its own
  was caught by `generic-api-key` beside a word such as "key", and on
  one line not at all, where gitleaks reported it. The rule on building
  a secret from pieces in messages needs no change.

No work for us.
