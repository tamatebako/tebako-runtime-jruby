#!/usr/bin/env ruby
# frozen_string_literal: true

# pins.rb — read Tebakofile's `tools:` block (the repo's toolchain pin
# SSOT) and emit KEY=VALUE lines for $GITHUB_ENV. The workflow carries NO
# version or digest literals — every value flows from the recipe.
#
#   ruby tools/pins.rb <tool-platform> [flavor] [--env]
#   ruby tools/pins.rb --release-only [flavor]
#
# <tool-platform> is the tebako release asset platform (macos-arm64,
# linux-gnu-x86_64). [flavor] is the recipe's flavor key — jruby has ONE
# flavor (`jvm`, the only mode; the default), kept in the spec 28 §8
# shape so the machinery mirrors the sibling runtime feedstocks.
# --release-only emits just TEBAKO_RELEASE/PKG_NAME/PKG_VERSION. A tool
# listed in tools.sha256 without a pin for the requested platform is a
# named error, never a guess (spec 00 §9).
#
# Runtime-promotion additions (the kind: runtime pair): the wrapper exe
# pin flows from Tebakofile's runtime.wrapper_tebako (WRAPPER_RELEASE /
# WRAPPER_ASSET / RUNTIME_STEM_BASE) and the POSIX legs get PRELOAD_SHIM
# (the extracted link-unit tarball's libtfs_preload path). The sha256
# map is data-driven: every tool key under tools.sha256 emits
# <TOOL>_ASSET/<TOOL>_SHA256 (link-unit names a .tar.gz, the CLIs name
# bare binaries).
#
# tebako#716's language segment of the runtime pair's name is this
# runtime's distribution identity — the flavor's `implementation`
# ("jruby", an implementation of the ruby engine): new publishes spell
# tebako-runtime-<line>-jruby-<ver>-<platform>. No era gate: a re-run of
# an old tag checks out that tag's own pins.rb / tools/build and
# composes that ref's names, self-consistently — the already-published
# segment-less spellings never change (spec 05 §2's era law). The
# segment flows from the SELECTED flavor block, never a hardcoded value.
# The owner pair's stem (OWNER_STEM, a FOREIGN name this feedstock
# fetches) follows the PINNED owner release's own era: the recipe's
# owner_smoke block gains an `implementation` key when its pin moves to
# a post-#716 owner release (absent = the segment-less spelling).
#
# NEVER emit a bare TEBAKO_VERSION: in the sibling feedstocks tools/build
# uses that name for the RUNTIME release line with an env override, so a
# tools-version export silently clobbers the runtime pin (the 2026-08-27
# metanorma collision: the press resolved runtime release v0.3.1, exit
# 124). The tools version lives inside the computed ASSET names.

require "yaml"

def die(msg)
  warn "pins.rb: #{msg}"
  exit 64
end

root = File.expand_path("..", __dir__)
recipe = YAML.load_file(File.join(root, "Tebakofile"))
tools = recipe.fetch("tools")
release = tools.fetch("release")
version = release.sub(/\Av/, "")
die "Tebakofile tools.sha256 missing" unless tools["sha256"].is_a?(Hash)

# The flavor axis (spec 28 §8's shape): the flavor key names the recipe's
# flavors:<flavor> block (jruby has exactly one — `jvm`, the default; the
# shape stays so the tooling mirrors the sibling feedstocks). Positional
# after the tool-platform (`pins.rb macos-arm64 jvm --env`), or the sole
# positional in --release-only mode (`pins.rb --release-only`).
# PKG_VERSION, RUNTIME_STEM_BASE and IMPLEMENTATION follow the selected
# flavor.
positional = ARGV - ["--env", "--release-only"]
flavor = if ARGV.include?("--release-only")
           positional[0] || ENV["FLAVOR"] || "jvm"
         else
           positional[1] || ENV["FLAVOR"] || "jvm"
         end
flavors = recipe.fetch("flavors") do
  die "Tebakofile flavors block missing"
end
flavor_block = flavors[flavor] or
  die "Tebakofile: unknown flavor '#{flavor}' (have: #{flavors.keys.join(', ')})"

runtime = recipe.fetch("runtime")
# The wrapper pin is per-FLAVOR overridable (the jvm flavor requires the
# spec-33-aware launcher line; the shared runtime block stays the native
# flavor's): flavors.<flavor>.wrapper_tebako / .wrapper_sha256 win when
# present. A missing pin is a named error either way (spec 00 §9).
wrapper_tebako = flavor_block["wrapper_tebako"] || runtime.fetch("wrapper_tebako")
wrapper_shas = flavor_block["wrapper_sha256"] || runtime.fetch("wrapper_sha256")
implementation = flavor_block.fetch("implementation")
pkg_version = flavor_block.dig("upstream", "version") ||
              die("Tebakofile flavors.#{flavor}.upstream.version missing")

pairs = {
  "TEBAKO_RELEASE" => release,
  "PKG_NAME" => recipe.fetch("name"),
  "PKG_VERSION" => pkg_version,
  "FLAVOR" => flavor,
  "IMPLEMENTATION" => implementation,
}

unless ARGV.include?("--release-only")
  platform = ARGV[0] or die "usage: pins.rb <tool-platform> [--env] | pins.rb --release-only"
  exe = platform.start_with?("windows") ? ".exe" : ""
  # Tools the recipe pins for POSIX legs only: a missing platform pin
  # warns + skips; for every other tool a missing pin is a named error,
  # never a guess. (A tool's POSIX-only scope is the recipe's data, not
  # this script's assumption — the guard predates the windows legs and
  # stays.)
  # The composed smoke's dispatcher (tebako-shim) may ride the recipe's
  # shim_dispatch_alias: tebako ships NO windows-ucrt-arm64 shim (the
  # win-arm64 surface is runtime-own), so that leg's smoke dispatches
  # through the aliased x64 shim under the runner's emulation. The alias
  # is recipe data; a tool that ships a NATIVE pin for an aliased platform
  # is a contradiction — refuse it, never pick silently (spec 00 §9).
  posix_only = %w[link-unit]
  shim_alias = tools["shim_dispatch_alias"] || {}
  tools.fetch("sha256").each do |tool, shas|
    pin_platform = platform
    if tool == "tebako-shim" && shim_alias.key?(platform)
      die "Tebakofile: shim_dispatch_alias names #{platform} but tools.sha256.tebako-shim pins it natively — one of them is stale" if shas.key?(platform)
      pin_platform = shim_alias.fetch(platform)
      warn "pins.rb: tebako-shim for #{platform} resolves via shim_dispatch_alias → #{pin_platform} (the pinned line ships no native #{platform} shim)"
    end
    sha = shas[pin_platform]
    if sha.nil?
      die "Tebakofile: no tools.sha256.#{tool}.#{pin_platform} pin" unless posix_only.include?(tool)
      warn "pins.rb: #{tool} has no #{pin_platform} pin (POSIX-only tool — skipped)"
      next
    end
    pin_exe = pin_platform.start_with?("windows") ? ".exe" : ""
    key = tool.upcase.tr("-", "_")
    asset = if tool == "link-unit"
              "#{tool}-#{version}-#{pin_platform}.tar.gz"
            else
              "#{tool}-#{version}-#{pin_platform}#{pin_exe}"
            end
    pairs["#{key}_ASSET"] = asset
    pairs["#{key}_SHA256"] = sha
  end
  # The wrapper exe (spec 29): the recipe's runtime.wrapper_tebako names
  # the line (ships since tebako v2.1.0); runtime.wrapper_sha256 is its
  # per-platform trust anchor — a missing pin is a named error, never a
  # guess (the launcher ships as the runtime pair's entry point).
  pairs["WRAPPER_RELEASE"] = "v#{wrapper_tebako}"
  pairs["WRAPPER_ASSET"] = "tebako-runtime-launcher-#{wrapper_tebako}-#{platform}#{exe}"
  pairs["WRAPPER_SHA256"] = wrapper_shas[platform] ||
                            die("Tebakofile: no wrapper_sha256.#{platform} pin for flavor '#{flavor}'")
  # The pair's name carries tebako#716's language segment — the flavor's
  # implementation ("jruby"): tebako-runtime-<line>-jruby-<ver>-<platform>.
  # tools/build composes the same grammar from the same recipe values.
  pairs["RUNTIME_STEM_BASE"] = "tebako-runtime-#{wrapper_tebako}-#{implementation}-#{pkg_version}"
  pairs["RUNTIME_STEM"] = "#{pairs['RUNTIME_STEM_BASE']}-#{platform}"
  # The env image is UNIVERSAL (the dist ships every platform's jffi
  # stub): ONE asset serves all triplets; each per-triplet shard's
  # image.filename names THIS stem (entry_asset_names flows it verbatim —
  # no product change).
  pairs["RUNTIME_IMAGE_STEM"] = "#{pairs['RUNTIME_STEM_BASE']}-universal"
  # The extracted preload shim (POSIX legs only). The tarball's internal
  # top dir is VERSION-LESS (link-unit-<platform>/; the version lives in
  # the asset name) — link-unit-stage.sh has tarred it that way since the
  # script exists.
  unless platform.start_with?("windows")
    dl_ext = platform.include?("macos") ? "dylib" : "so"
    pairs["PRELOAD_SHIM"] = ".packager/link-unit-#{platform}/libtfs_preload.#{dl_ext}"
  end
  # The composed smoke's owner pair (flavors with an on_runtime edge —
  # spec 33): the workflow downloads the PUBLISHED owner runtime into a
  # throwaway store. The recipe's flavors.<flavor>.owner_smoke block is
  # the pin SSOT (repo/release/version/tebako line + exe/image sha256
  # per platform, cross-checked against that release's own SHA256SUMS at
  # fetch). The store dir ids ride the release-asset platform spelling
  # (java-<ver>-<line>-<platform>), matching the store grammar.
  if (owner = flavor_block["owner_smoke"])
    owner_version = owner.fetch("version")
    owner_line = owner.fetch("tebako")
    # tebako#716, on a FOREIGN name: the pinned owner release's own era
    # rules the fetch spelling. The pin block declares `implementation`
    # (e.g. temurin) once it names a post-#716 owner release; absent, the
    # pair's segment-less spelling is composed (the v2.8.21 pin).
    owner_infix = owner["implementation"] ? "#{owner.fetch('implementation')}-" : ""
    pairs["OWNER_REPO"] = owner.fetch("repo")
    pairs["OWNER_RELEASE"] = owner.fetch("release")
    pairs["OWNER_STEM"] = "tebako-runtime-#{owner_line}-#{owner_infix}#{owner_version}-#{platform}"
    pairs["OWNER_STORE_ID"] = "java-#{owner_version}-#{owner_line}-#{platform}"
    pairs["OWNER_EXE_SHA256"] = owner.fetch("exe_sha256")[platform] ||
                                die("Tebakofile: no owner_smoke.exe_sha256.#{platform} pin")
    pairs["OWNER_IMAGE_SHA256"] = owner.fetch("image_sha256")[platform] ||
                                  die("Tebakofile: no owner_smoke.image_sha256.#{platform} pin")
    pairs["DEP_STORE_ID"] = "ruby-#{pkg_version}-#{wrapper_tebako}-#{platform}"
  end
end

if ARGV.include?("--env") || ARGV.include?("--release-only")
  pairs.each { |k, v| puts "#{k}=#{v}" }
else
  pairs.each { |k, v| puts "export #{k}=#{v}" }
end
