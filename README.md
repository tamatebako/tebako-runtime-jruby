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

The pair's artifact names carry the language segment
([tebako#716](https://github.com/tamatebako/tebako/issues/716)): new
publishes spell `tebako-runtime-<tebako-line>-jruby-<version>-<platform>`
(the exe per triplet) and `tebako-runtime-<tebako-line>-jruby-<version>-universal.tfs`
(the one env image), where `jruby` is this runtime's distribution
identity — an implementation of the ruby engine. Releases already
published keep the segment-less spelling forever: they are immutable and
sha256-pinned in this registry, and re-running an old tag composes that
ref's own names, self-consistently. The fetched **owner** pair's name
follows the pinned owner release's own era — `Tebakofile`'s
`owner_smoke` block gains an `implementation` key when its pin moves to
a release whose assets carry the segment.

## The macOS dyld plane (tebako#1117)

The hardened runtime strips `DYLD_INSERT_LIBRARIES` at exec on macOS 14
when the EXEC TARGET's own signature lacks
`com.apple.security.cs.allow-dyld-environment-variables` (the
tebako-runtime-r#5 class). This runtime-on-runtime shape (spec 33) has
no insertion-dependent core IO at any layer:

- The **wrapper** (tebako-signed): its boot-head self-insert fires on
  macOS, but the wrapper only mounts and composes — nothing in its
  process consumes the interpose dylib (the same product wrapper runs
  green on darwin-23 in the openjdk line with no entitlements at all).
- The **JVM** (the composed java owner — Temurin's bytes): jruby's
  home materializes whole (the `java_home: "/"` annotation — spec 33
  §2's bridge law: "a JVM needs no VFS once its home is
  materialized"), so core IO is host-real and shim-free. The owner
  pair's `preload_shim` grant arms the insertion for the jail's
  host-IO binding, whose survival is governed by TEMURIN's own
  signature — verified carrying
  `com.apple.security.cs.allow-dyld-environment-variables` (Eclipse
  Foundation JCDTMS22B4) on the materialized 21.0.12 home.
- This repo's own image declares NO `preload_shim` and NO interpreter
  (spec 33 §5) — it never execs a process of its own, so there is no
  tebako-signed insertion target to strip. Proven on darwin-23
  (macOS 14.1.1 arm64): the published v2.8.60 jruby image composed on
  the published temurin 2.8.50 owner boots the JVM and runs jruby
  from the materialized home.

The grant question reopens only if a shape change ever makes a
tebako-signed exe the insertion target — spec 33's composition never
does.
