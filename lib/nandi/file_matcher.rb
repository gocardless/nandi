# frozen_string_literal: true

module Nandi
  class FileMatcher
    TIMESTAMP_REGEX = /\A(?<operator>>|>=)?(?<timestamp>\d+)\z/.freeze

    def self.call(*args)
      new(*args).call
    end

    def initialize(files:, spec:)
      @files = Set.new(files)
      @spec = spec
    end

    def call
      case spec
      when "all"
        files
      when "git-diff"
        files.intersection(files_from_git_status)
      when TIMESTAMP_REGEX
        match_timestamp
      end
    end

    private

    def match_timestamp
      match = TIMESTAMP_REGEX.match(spec)

      case match[:operator]
      when nil
        files.select do |file|
          file.start_with?(match[:timestamp])
        end
      when ">"
        migrations_after((Integer(match[:timestamp]) + 1).to_s)
      when ">="
        migrations_after(match[:timestamp])
      end.to_set
    end

    def migrations_after(minimum)
      files.select { |file| file >= minimum }
    end

    def files_from_git_status
      `
        git status --porcelain --short --untracked-files=all |
        cut -c4- |
        xargs -n1 basename
      `.lines.map(&:strip)
    end

    attr_reader :files, :spec
  end
end
