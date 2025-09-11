# frozen_string_literal: true

module Nandi
  class MigrationViolations
    def initialize
      @ungenerated_files = []
      @handwritten_files = []
      @out_of_date_files = []
      @hand_edited_files = []
    end

    def add_ungenerated(missing_files, directory)
      return if missing_files.empty?

      full_paths = build_full_paths(missing_files, directory)
      @ungenerated_files.concat(full_paths)
    end

    def add_handwritten(handwritten_files, directory)
      return if handwritten_files.empty?

      full_paths = build_full_paths(handwritten_files, directory)
      @handwritten_files.concat(full_paths)
    end

    def add_out_of_date(changed_files, directory)
      return if changed_files.empty?

      full_paths = build_full_paths(changed_files, directory)
      @out_of_date_files.concat(full_paths)
    end

    def add_hand_edited(altered_files, directory)
      return if altered_files.empty?

      full_paths = build_full_paths(altered_files, directory)
      @hand_edited_files.concat(full_paths)
    end

    def any?
      [@ungenerated_files, @handwritten_files, @out_of_date_files, @hand_edited_files].any?(&:any?)
    end

    def to_error_message
      error_messages = []

      error_messages << ungenerated_error if @ungenerated_files.any?
      error_messages << handwritten_error if @handwritten_files.any?
      error_messages << out_of_date_error if @out_of_date_files.any?
      error_messages << hand_edited_error if @hand_edited_files.any?

      error_messages.join("\n\n")
    end

    private

    def build_full_paths(filenames, directory)
      filenames.map { |filename| File.join(directory, filename) }
    end

    def format_file_list(files)
      "  - #{files.sort.join("\n  - ")}"
    end

    def ungenerated_error
      <<~ERROR.strip
        The following migrations are pending generation:

        #{format_file_list(@ungenerated_files)}

        Please run `rails generate nandi:compile` to generate your migrations.
      ERROR
    end

    def handwritten_error
      <<~ERROR.strip
        The following migrations have been written by hand, not generated:

        #{format_file_list(@handwritten_files)}

        Please use Nandi to generate your migrations. In exeptional cases, hand-written
        ActiveRecord migrations can be added to the .nandiignore file. Doing so will
        require additional review that will slow your PR down.
      ERROR
    end

    def out_of_date_error
      <<~ERROR.strip
        The following migrations have changed but not been recompiled:

        #{format_file_list(@out_of_date_files)}

        Please recompile your migrations to make sure that the changes you expect are
        applied.
      ERROR
    end

    def hand_edited_error
      <<~ERROR.strip
        The following migrations have had their generated content altered:

        #{format_file_list(@hand_edited_files)}

        Please don't hand-edit generated migrations. If you want to write a regular
        ActiveRecord::Migration, please do so and add it to .nandiignore. Note that
        this will require additional review that will slow your PR down.
      ERROR
    end
  end
end
