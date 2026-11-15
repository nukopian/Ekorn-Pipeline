# 2026-0037. A module of gitleaks' rules

**Status:** open

**Decisions:** D1 open: the name, and a repository of its own. D2
open: released to CPAN. D3 settled: `/a`, `$` as `\z`, refuse what
won't translate, gitleaks' samples as tests. D4 open: keywords first.
D5 open: entropy written here. D6 open: crediting gitleaks. D7 open:
which allowlists to carry. D8 open: what's redacted. D9 open: rules
pinned to a gitleaks tag. D10 open: the interface.

**Origin:** roadmap, added 2026-11-15, split from 2026-0036

## Background

A dump is often written to a log, and a value holding a password, a
token or a DSN leaks it there. gitleaks keeps a maintained set of rules
for finding secrets, so a script can turn them into a Perl module, and
`dump_to` can use it when it's installed (2026-0038).

gitleaks' `config/gitleaks.toml`, at its `master`,
5f6ec56cfa6f8c67648d863582c7ae2f206d5c1c on 2026-11-15, is generated
from Go sources in `cmd/generate/config/`, which also hold true- and
false-positive samples for each rule. It has 222 rules: 221 with a
regex, one matching paths only; 130 with a minimum Shannon entropy;
221 with keywords; some with allowlists of their own, regexes or
stopwords. A global allowlist is mostly of paths. Only one rule names
a `secretGroup`.

All 221 regexes compile in Perl 5.36 as they are. 154 of them use `$`
as an anchor, 155 times in all, outside a character class and not
escaped, mostly in the end of a secret that most rules share,
`(?:[\x60'"\s;]|\\[nr]|$)`. None sets the `m` flag.

## Decisions

- [ ] **D1.** The module's name, and where it lives? Recommended: a
  distribution and repository of its own, as it's of use beyond
  pipelines, and Ekorn's tarball shouldn't carry some 200 generated
  regexes. A name not implying it's gitleaks' own, such as
  `Text::Redact::Secrets`, checked as free on CPAN.
- [ ] **D2.** Released to CPAN? Recommended: yes, or few of `dump_to`'s
  users will ever have it, and 2026-0038 would help almost no one.
- [x] **D3.** Go's RE2 regexes in Perl? **Each is compiled with `/a`,
  so `\w`, `\s` and `\d` are ASCII, as in RE2; each `$` that's an
  anchor is written `\z`; a regex that won't compile, or sets the `m`
  flag, stops the script; and gitleaks' samples become tests,** Iain
  decided on 2026-11-15. Without `m`, RE2's `$` matches only at the end
  of the text, as `\z` does, where Perl's `$` matches before a final
  newline too. Under `m` it would mean the end of a line, and `\z`
  would change the rule, so the script refuses it rather than guess. A
  `$` escaped or in a character class is a dollar, so the script finds
  the anchors by scanning, not by a search and replace. Compiling
  isn't agreeing, so the samples are what show the two agree.
- [ ] **D4.** gitleaks' keywords, checked first? Recommended: yes, as
  gitleaks does, on the text lowercased: one regex of every keyword
  finds which rules could match, and only theirs run. Measured on a
  typical dump before it's settled.
- [ ] **D5.** The entropy check written here, or
  Shannon::Entropy::XS? Recommended: here. It's about ten lines of
  plain Perl, run only on what a regex has matched; the XS module (1.18,
  2026-10-22) would add a compiled dependency to save almost nothing.
- [ ] **D6.** Crediting gitleaks, which is MIT-licensed? Recommended:
  its licence and copyright notice shipped as a file, and gitleaks, the
  tag and the commit the rules came from named in the POD.
- [ ] **D7.** Which allowlists to carry? Recommended: each rule's own
  regexes and stopwords, without which `generic-api-key` redacts
  placeholders; not those of paths, as the module sees strings, not
  files.
- [ ] **D8.** What's redacted? Recommended: the secret as gitleaks
  finds it: the `secretGroup`, or the first capture group that isn't
  empty, or the whole match. So `'password' => 'hunter2...'` keeps its
  key, and only the value becomes `*REDACTED*`.
- [ ] **D9.** How the rules are kept current? Recommended: the script
  fetches them from a gitleaks release tag, not `master`, and writes
  the tag and commit into the module, so a release can be made again
  exactly; updating is running it again, by hand, for a new release.
- [ ] **D10.** The interface? Recommended: `redact($string)`, returning
  a copy with each secret replaced; perhaps `find($string)` too,
  returning each secret found with its rule's id, for tests and for
  reporting what was found rather than hiding it. Both `@EXPORT_OK`.
