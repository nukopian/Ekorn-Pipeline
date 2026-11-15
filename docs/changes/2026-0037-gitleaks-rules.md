# 2026-0037. A module of gitleaks' rules

**Status:** moved to Text-Redact-Secrets, as its 2026-0001, on
2026-11-15. Its work goes on there, in
[its record](https://github.com/nukopian/Text-Redact-Secrets/blob/develop/docs/changes/2026-0001-gitleaks-rules.md),
which began as a copy of this one; this one stays as it was when it
moved, with this line.

**Decisions:** D1 settled: a distribution and repository of its own. D2
settled: released to CPAN. D3 settled: `/a`, `$` as `\z`, refuse what
won't translate, hand-written tests and gitleaks' false positives. D4
settled: keywords first. D5 settled: entropy written here. D6 settled:
gitleaks' licence shipped, and named in the POD. D7 settled: what
applies to strings carried, what applies to files not. D8 settled: the
secret as gitleaks picks it out. D9 settled: rules pinned to a gitleaks
tag. D10 settled: `redact` and `find`. D11 settled:
`Text::Redact::Secrets`. None open.

**Origin:** roadmap, added 2026-11-15, split from 2026-0036

## Background

A dump is often written to a log, and a value holding a password, a
token or a DSN leaks it there. gitleaks keeps a maintained set of rules
for finding secrets, so a script can turn them into a Perl module, and
`dump_to` can use it when it's installed (2026-0038).

gitleaks' `config/gitleaks.toml`, at its `master`,
5f6ec56cfa6f8c67648d863582c7ae2f206d5c1c on 2026-11-15, is generated
from Go sources in `cmd/generate/config/`, which also hold samples
for each rule: false positives written as strings, and true positives
made at random as the generator runs, so not in the source to be read
(`rules/github.go` at that commit). The rules are all in the TOML, so
keeping them current needs only it. It has 222 rules: 221 with a
regex, one matching paths only; 130 with a minimum Shannon entropy;
221 with keywords; some with allowlists of their own, regexes or
stopwords. A global allowlist has paths, and regexes and stopwords for
every rule (D7). Only one rule names a `secretGroup`.

All 221 regexes compile in Perl 5.36 as they are. 154 of them use `$`
as an anchor, 155 times in all, outside a character class and not
escaped, mostly in the end of a secret that most rules share,
`(?:[\x60'"\s;]|\\[nr]|$)`. None sets the `m` flag.

## Decisions

- [x] **D1.** Where does the module live? **In a distribution and
  repository of its own,** Iain decided on 2026-11-15, once it was
  plain how each would be kept current. There, new rules are a release
  of that module alone: the script fetches a tag's
  `config/gitleaks.toml`, writes the module, and the diff and tests
  show what changed, released only when the rules did; `dump_to` uses
  whichever version is installed, so Ekorn never releases for them,
  and DBIx-Squirrel has nothing to do. In Ekorn-Pipeline, each change
  to the rules would be an Ekorn release, perhaps a v0.4.0 with a task
  for DBIx-Squirrel, as what's redacted is behaviour users rely on, and
  it couldn't be optional, which 2026-0038 needs. A second distribution
  in Ekorn's repository goes against Minilla, and fetching the rules at
  install or run time needs the network and can't be made again
  exactly. Its name is D11.
- [x] **D2.** Released to CPAN? **Yes,** Iain decided on 2026-11-15:
  on GitHub alone, few of `dump_to`'s users would ever have it, and
  2026-0038 would help almost no one. On CPAN, `cpanm -U` brings new
  rules to them, as D1 has it.
- [x] **D3.** Go's RE2 regexes in Perl? **Each is compiled with `/a`,
  so `\w`, `\s` and `\d` are ASCII, as in RE2; each `$` that's an
  anchor is written `\z`; a regex that won't compile, or sets the `m`
  flag, stops the script; and the tests are written by hand, for the
  rules that matter most in a dump, with gitleaks' false positives
  added,** Iain decided on 2026-11-15, the tests changed the same day
  from gitleaks' samples, once its true positives were found to be made
  at random as its generator runs. The rules tested by hand are
  `generic-api-key`, passwords in URLs and DSNs, AWS's, GitHub's and
  private keys; the false positives are read from the Go sources at
  the same tag. Generating secrets from each regex in Perl, with
  String::Random's `randregex`, covers only some of their syntax, and
  running gitleaks' generator needs Go; tests by hand don't break when
  gitleaks moves its Go code about. Without `m`, RE2's `$` matches
  only at the end of the text, as `\z` does, where Perl's `$` matches
  before a final newline too. Under `m` it would mean the end of a
  line, and `\z` would change the rule, so the script refuses it
  rather than guess. A
  `$` escaped or in a character class is a dollar, so the script finds
  the anchors by scanning, not by a search and replace. Compiling
  isn't agreeing, so the tests are what show the two agree.

  `\z`, not `\Z`, as Iain asked on 2026-11-15: `\Z` matches before a
  final newline too, as Perl's `$` does, so it would be the same as
  leaving `$` alone, and RE2 has no `\Z`. It differs in one rule only.
  151 of the regexes with an anchor have it in the shared end, beside
  `\s`, which matches a final newline anyway; two more, an Azure AD
  client secret and Perplexity's key, have `\s` beside it too. Only
  `sidekiq-sensitive-url`, ending `(?:[\/|\#|\?|:]|$)`, would miss with
  `\z` a secret straight before a final newline, which `\Z` would
  catch, and which gitleaks misses too. Catching more is tempting in a
  redactor, but keeping each rule's meaning is what makes "the rules
  are gitleaks'" true, and a rule that should catch more is better
  fixed in gitleaks, for everyone. Nor can it arise in `dump_to`, as
  Data::Dumper ends each string with a quote.
- [x] **D4.** gitleaks' keywords, checked first? **Yes, as gitleaks
  does, on the text lowercased: one regex of every keyword finds which
  rules could match, and only theirs run,** Iain decided on 2026-11-15,
  as recommended. It's how gitleaks runs its rules, not only a way to
  speed them: a rule with keywords never matches text without one, so
  checking them keeps each rule's meaning, as D3 does, as well as
  sparing some 220 regexes on every dump. The recommendation was to
  measure it on a typical dump before settling; settled first, the
  measurement is taken as it's built, and goes in What happened.
- [x] **D5.** The entropy check written here, or
  Shannon::Entropy::XS? **Here, in plain Perl,** Iain decided on
  2026-11-15, as recommended. It's about ten lines, run only on what a
  regex has matched, so seldom; the XS module (1.18, 2026-10-22) would
  add a compiled dependency to save almost nothing. Written here, it
  can be made to reckon as gitleaks does, base 2, on the secret D8
  picks out, and tested against gitleaks' thresholds.
- [x] **D6.** Crediting gitleaks, which is MIT-licensed? **Its licence
  and copyright notice shipped as a file, and gitleaks, the tag and the
  commit the rules came from named in the POD,** Iain decided on
  2026-11-15, as recommended. MIT asks that the notice go with every
  copy, or substantial portion, and the generated module of rules is
  one, so its header says where its rules came from and points to the
  file too. The script fetches the licence from the same tag as the
  rules, so the notice is the one they came under: at the commit in
  Background, "Copyright (c) 2019 Zachary Rice". The module's own code
  is under Perl's terms, as Iain's distributions are; MIT's allow
  that.
- [x] **D7.** Which allowlists to carry? **What applies to strings, and
  not what applies to files: the regexes and stopwords of the global
  allowlist and of each rule's, honouring each one's `regexTarget` and
  `condition`; not paths or commits,** Iain decided on 2026-11-15. The
  recommendation named only each rule's own; looking closer, the
  global allowlist isn't mostly paths, as Background first had it, but
  has regexes and stopwords too, 19 lines, for every rule, and they're
  what a dump most needs: they pass over placeholders such as `$VAR`,
  `${VAR}`, `{{ ... }}`, `%VAR%`, `true`, `false` and `null`, and runs
  of one letter. Settled on the recommendation's principle, the module
  seeing strings, not files, they're carried. Without them,
  `generic-api-key` redacts placeholders.

  At the commit in Background, rules have 13 allowlists of their own:
  11 with regexes, one with stopwords, three with paths. Each regex is
  matched against what its `regexTarget` says: the secret, by default;
  the whole match; or the line it's on. An allowlist with `condition =
  "AND"` passes over a finding only if all its parts match, so one
  with paths can never pass over anything here, and is dropped whole,
  not just its paths, which would make it pass over more than
  gitleaks does; one rule's is so. Allowlist regexes are translated as
  D3 says, as the rules' are.
- [x] **D8.** What's redacted? **The secret as gitleaks picks it out:
  the `secretGroup`, if the rule names one; or else the first capture
  group that isn't empty; or else, with no groups or none matched, the
  whole match,** Iain decided on 2026-11-15, as recommended. So
  `'password' => 'hunter2...'` keeps its key, and only the value
  becomes `*REDACTED*`, and a dump still shows what was there. It's
  gitleaks' own order, in `detect/detect.go` at the commit in
  Background, and the same secret is what D5's entropy is reckoned on
  and what an allowlist's default `regexTarget` matches, so all three
  agree.
- [x] **D9.** How the rules are kept current? **The script fetches them
  from a gitleaks release tag, not `master`, and writes the tag and
  commit into the module, so a release can be made again exactly;
  updating is running it again, by hand, for a new release,** Iain
  decided on 2026-11-15, as recommended, with the update below. A tag is
  what gitleaks released and tested; `master` can change between two
  runs of the script. Which way a new tag is noticed, by watching
  gitleaks' releases or by the CI job in step 1, is settled when the
  repository is set up, as the job is a change to GitHub. gitleaks'
  latest tag on 2026-11-15 was v8.30.1, so the first release's rules
  come from it, or a later one; Background's counts are from `master`,
  and may differ a little from that tag's.

  An update, in Text-Redact-Secrets' repository:

  1. **gitleaks tags a release,** v8.31.0, say. It's noticed by
     watching gitleaks' releases on GitHub, or by a weekly CI job that
     compares the tag in the module with gitleaks' latest and fails
     when they differ, which is a change to GitHub, so Iain's to make.
  2. **`scripts/update-rules v8.31.0`** fetches that tag's
     `config/gitleaks.toml`, and the Go sources the false positives are
     read from; translates each regex as D3 says, stopping on one it
     can't; and writes the generated module of rules and its test of
     false positives, with the tag and commit in the module. If the
     rules are the same as before, it says so, and there's nothing
     more to do: most of gitleaks' releases change its Go, not its
     rules.
  3. **`git diff`** shows the rules added, changed and removed, and the
     tests, by hand and of false positives, run as for any change. A
     rule removed that a test by hand names fails it, and is looked
     into.
  4. **A release:** the module's own version, a minor one for new
     rules, as its code has a version of its own and two schemes in one
     number would mislead; `Changes` names the gitleaks tag; it goes to
     CPAN as D2 says.
  5. **Users get it with `cpanm -U Text::Redact::Secrets`,** and
     `dump_to` uses whatever version is installed, so neither Ekorn nor
     DBIx-Squirrel releases for it, as D1 has it.
- [x] **D10.** The interface? **`redact($string)`, returning a copy with
  each secret replaced by `*REDACTED*`, and `find($string)`, returning
  each secret found with its rule's id; both `@EXPORT_OK`,** Iain
  decided on 2026-11-15, as recommended. `redact` is what 2026-0038's
  `dump_to` calls, and its self-test too. `find` is for the tests,
  which check which rule found what, not only that something was
  hidden, and for anyone who'd report what was found rather than hide
  it. Both share one scan, so they can't disagree about what's a
  secret. Exports are `@EXPORT_OK`, as a module of two functions with
  common names shouldn't put them in its caller's namespace unasked.
- [x] **D11.** The module's name, and so its distribution's and
  repository's? **`Text::Redact::Secrets`,** in the distribution
  `Text-Redact-Secrets`, Iain decided on 2026-11-15: it says what it
  does, and doesn't suggest it's gitleaks' own. On MetaCPAN that day,
  neither it, nor `Text::Redact`, nor the distribution was taken.
  Split from D1 the same day, when D1 was settled.
