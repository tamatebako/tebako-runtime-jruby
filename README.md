# tebako-packages/jruby — the JRuby runtime feedstock

Repack feedstock (no compilation): the JRuby dist is a **universal** tarball
(bytecode + ruby home; `lib/jni/` ships every platform's jffi stub — see
`recipe.yml`'s probe record), so ONE env image serves all triplets; the
triplet binding comes from the composed **java owner** pair
(tebako-packages/openjdk — `DEPENDS java >= 21`, spec 33's `on_runtime` form).

- TODO thread: `TODO.jruby/02` at the ecosystem root; probe facts:
  `TODO.jruby/02-probe-2026-09-07.md`.
- Spec: docs/spec/33 (runtime-on-runtime) in tamatebako/tebako; the jvm-mode
  machinery mirrors tebako-packages/truffleruby's `flavors.jvm` (its /03 PR).
- Owner line floor: **2.5.0** (tebako#552 — a pre-2.5.0 owner misroutes the
  composed entry).
