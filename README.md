# tamatebako/tebako-runtime-jruby — the JRuby runtime feedstock

Repack feedstock (no compilation): the JRuby dist is a **universal** tarball
(bytecode + ruby home; `lib/jni/` ships every platform's jffi stub — see
`Tebakofile`'s probe record), so ONE env image serves all triplets; the
triplet binding comes from the composed **java owner** pair
(tamatebako/tebako-runtime-openjdk — `DEPENDS java >= 21`, spec 33's `on_runtime` form).

- Spec: [docs/spec/33](https://github.com/tamatebako/tebako/blob/main/docs/spec/33-runtime-on-runtime.md)
  (runtime-on-runtime); the jvm-mode machinery mirrors
  tamatebako/tebako-runtime-truffleruby's `flavors.jvm`.
- Owner line floor: **2.5.0** ([tamatebako/tebako#552](https://github.com/tamatebako/tebako/pull/552)
  — a pre-2.5.0 owner misroutes the composed entry).
