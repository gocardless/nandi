# frozen_string_literal: true

module Nandi
  class FileDiff
    attr_reader :file_path, :known_digest

    def initialize(file_path:, known_digest:)
      @file_path = file_path
      @known_digest = known_digest
    end

    def file_name
      File.basename(file_path)
    end

    def body
      File.read(file_path)
    end

    def digest
      Digest::SHA256.hexdigest(body)
    end

    def unchanged?
      !changed?
    end

    def changed?
      known_digest != digest
    end
  end
end
