# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "nandi/version"

Gem::Specification.new do |spec|
  spec.name          = "nandi"
  spec.version       = Nandi::VERSION
  spec.authors       = ["GoCardless Engineering"]
  spec.email         = ["engineering@gocardless.com"]

  spec.summary       = "Fear-free migrations for PostgreSQL"
  spec.homepage      = "https://github.com/gocardless/nandi"
  spec.license       = "MIT"

  spec.files = Dir["{config,lib,exe}/**/*", "Rakefile", "README.md"]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "activesupport"
  spec.add_dependency "cells"
  spec.add_dependency "dry-monads"
  spec.add_dependency "tilt"

  spec.metadata["rubygems_mfa_required"] = "true"
end
