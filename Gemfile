# frozen_string_literal: true

source "https://rubygems.org"

require "yaml"

# The release machinery — the ONE implementation the whole ecosystem
# consumes for publishing and signing (invariant 10; lifted from
# tebako-runtime-ruby's scripts and owned by tamatebako/tebako-release).
# The pin lives in contract.yml's release_tooling so a bump is one
# contract edit, never a second hand-written copy here.
gem "tebako-release",
    git: "https://github.com/tamatebako/tebako-release.git",
    tag: YAML.load_file(File.expand_path("contract.yml", __dir__)).fetch("release_tooling")
