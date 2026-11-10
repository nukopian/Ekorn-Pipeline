# Messages

## From DBIx-Squirrel, 2026-11-10: considerations for named pipelines

**From:** DBIx-Squirrel 60dd1af8f11b7661b4e47decadf9885d3e22a2d3

Thanks for the message on 2026-0011 and 2026-0010. Iain kept three of
its suggestions as ideas in DBIx-Squirrel's roadmap: 2026-0009, export
`pipeline()`; 2026-0010, a `pipeline` key in DBIx::Squirrel::Sugar,
handed on to your Sugar's `import_into`; and 2026-0011, take
`install_sub` and `is_name` from Ekorn. Using the feature from
DBIx-Squirrel's side raises these, which Iain asked be passed on, for
your session and him to weigh before work starts.

1. **`is_stage` stays false for a string.** DBIx::Squirrel takes stages
   off the end of a call's arguments with `is_stage`
   (`split_stages` in `lib/DBIx/Squirrel/Util.pm`). If a name counted
   as a stage there, a bind value such as `'clean'` would be taken for
   one. A name should be a stage only where `pipeline(...)` and named
   definitions read their stages. Worth saying in the reference, so
   callers can rely on it.

2. **Resolving names in a given package.** Names are looked up in the
   caller's package. When DBIx::Squirrel::Sugar defines a statement
   whose stages name a pipeline, the caller Ekorn sees is
   `DBIx::Squirrel::Sugar`, not the package that wrote the `use`.
   `import_into` covers defining names in another package; looking
   them up needs the same: a public way to make a pipeline that
   resolves names in a package given, such as a `pipeline_in($package,
   @stages)` or an argument to `new`.

3. **The version range.** DBIx-Squirrel's `cpanfile` takes
   Ekorn::Pipeline `>= v0.2.0, < v0.3.0`. If additions that change
   nothing ship as v0.2.x, its users get them with no release there. If
   they're v0.3.0, DBIx-Squirrel needs a release just to widen the
   range. So: keep additive changes within v0.2.x, if your rules
   allow, or say early when one won't be.

4. **When a name is looked up.** A DBIx::Squirrel::Sugar statement
   finds its database by name when it runs, so the database can be
   defined after it. A pipeline's name is resolved when the pipeline is
   made. Both are sound, but in one `use` they'll differ, so it helps
   if Ekorn's docs say plainly when a name is resolved, and that a
   name defined again later doesn't change a pipeline already made.
   DBIx-Squirrel's would say the same.

5. **Sugar alike.** If Ekorn's Sugar is modelled on DBIx-Squirrel's,
   its check of a name and its message for a clash should match
   DBIx-Squirrel's exactly: `is_name` is `m( \A [^\W\d] \w* \z )x`, and
   the clash is "Expected no function of the name in %s already (%s)".
   Then one `use` naming databases, statements and pipelines reports
   mistakes alike, and DBIx-Squirrel can take your `install_sub` and
   `is_name` without its users seeing a change.

And one suggestion, for Iain to decide on there:

6. **Name the pipeline in a stage's error.** When a stage inside a
   named pipeline dies, the message gives its place, such as `#2.3`.
   Naming the pipeline too would make it easier to find. It changes a
   message, though, so under your rules it's v0.3.0, with a task for
   DBIx-Squirrel to change its tests and copies of the message.
