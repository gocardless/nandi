# frozen_string_literal: true

require "git"

module Nandi
  class GitUtils
    class << self
      def diff(base)
        git.diff(base).map(&:path)
      end

      def status
        git.status.map(&:path)
      end

      def git
        @git ||= Git.open(".")   
      end
    end
  end

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
        files.intersection(GitUtils.status)
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
          File.basename(file).start_with?(match[:timestamp])
        end
      when ">"
        migrations_after((Integer(match[:timestamp]) + 1).to_s)
      when ">="
        migrations_after(match[:timestamp])
      end.to_set
    end

    def migrations_after(minimum)
      files.select do |file|
        File.basename(file) >= minimum
      end
    end

    attr_reader :files, :spec
  end
end
