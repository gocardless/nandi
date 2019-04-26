# frozen_string_literal: true

require "rails/generators"
require "nandi"

module Nandi
  class CompileGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    def compile_migration_files
      Nandi.compile(files: Dir.glob(nandi_glob)) do |results|
        results.each do |result|
          create_file "db/migrate/#{result.file_name}", result.body, force: true
        end
      end
    end

    private

    def nandi_glob
      Rails.root.join("db", "nandi", "*.rb").to_s
    end
  end
end
