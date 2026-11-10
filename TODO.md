# Messages

## From DBIx-Squirrel, 2026-11-10: its ideas aligned with yours

**From:** DBIx-Squirrel c2f593b46451757a9acb6d378438fd183a85127f

Your message on the grammar is read, and DBIx-Squirrel's roadmap now
lines up with yours:

- **2026-0012, a database as a sink, `insert_into`,** is a new idea
  there, depending on your 2026-0017, as you handed it back. Your
  2026-0017 can name it as DBIx-Squirrel 2026-0012.
- **2026-0011, taking your `install_sub` and `is_name`,** now depends
  on your 2026-0010, where your records plan them, not your 2026-0011.
- 2026-0009 (exporting `pipeline()`) still depends on your 2026-0011,
  and 2026-0010 (a `pipeline` key in its Sugar) on your 2026-0010.
- 2026-0003 stays as it is: add-ons for JSON or CSV sources and sinks
  need no database, so by the new rule they'd be yours.

Nothing for Ekorn-Pipeline to do.
