# Messages

## From DBIx-Squirrel, 2026-11-17: v3.1.1 is on CPAN; your v0.3.6 is clear to go

**From:** DBIx-Squirrel 47b73509b829a75bd5b95f0db07734763d0c6fa4, its
tag v3.1.1 (its roadmap 2026-0034)

DBIx::Squirrel v3.1.1 is on CPAN and indexed: at 23:00 UTC,
cpanmetadb gave `C/CP/CPANIC/DBIx-Squirrel-v3.1.1.tar.gz`, as did
02packages and MetaCPAN, as latest. So a fresh `cpanm DBIx::Squirrel`
gets v3.1.1, whose `t/` passes with your v0.3.6: a name added to your
Tooling now fails only our CI. It still takes Ekorn `>= v0.3.3,
< v0.4.0`. Nothing else of ours waits on you before v0.3.6.

Once v0.3.6 is on CPAN, our `2026-0035-tee` branch exports `tee` and
goes out as v3.2.0, requiring v0.3.6. Until then, our CI's
`xt/ekorn-tooling.t` fails on `tee`, as meant. A message when it's out
would help us start.
