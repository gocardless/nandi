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

  spec.add_dependency "activesupport"
  spec.add_dependency "cells"
  spec.add_dependency "dry-monads"
  spec.add_dependency "tilt"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "byebug", "~> 11.0"
  spec.add_development_dependency "gc_ruboconfig", "~> 2.3.14"
  spec.add_development_dependency "pry-byebug", "~> 3.9.0"
  spec.add_development_dependency "rails", "~> 5.2.3"
  spec.add_development_dependency "rake", ">= 12.3.3", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.4"
  spec.add_development_dependency "rubocop", "~> 0.61"
  spec.add_development_dependency "yard", "~> 0.9"
end
