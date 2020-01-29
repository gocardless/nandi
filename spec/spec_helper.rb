# frozen_string_literal: true

require "bundler/setup"
require "pathname"
require "nandi"

# Always handy to have in tests
require "pry"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    # Do not leave lockfiles lying around after test runs
    allow(File).to receive(:write).with(Pathname.new(".nandilock.yml"), anything)
  end

  Tilt.prefer Tilt::ERBTemplate
end
