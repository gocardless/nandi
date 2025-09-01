# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"
require "digest"

module Nandi
  class Lockfile
    class << self
      def file_present?(db_name)
        File.exist?(path(db_name))
      end

      def create!(db_name: nil)
        db_name ||= Nandi.config.default.name
        return if file_present?(db_name)

        File.write(path(db_name), {}.to_yaml)
      end

      def add(file_name:, source_digest:, compiled_digest:, db_name: nil)
        db_name ||= Nandi.config.default.name
        load!(db_name)

        lockfiles[db_name][file_name] = {
          source_digest: source_digest,
          compiled_digest: compiled_digest,
        }
      end

      def get(file_name:, db_name: nil)
        db_name ||= Nandi.config.default.name
        load!(db_name)

        {
          source_digest: lockfiles[db_name].dig(file_name, :source_digest),
          compiled_digest: lockfiles[db_name].dig(file_name, :compiled_digest),
        }
      end

      def load!(db_name)
        return lockfiles[db_name] if lockfiles[db_name]

        lockfile_path = path(db_name)
        create!(db_name: db_name) unless File.exist?(lockfile_path)

        lockfiles[db_name] = YAML.safe_load_file(lockfile_path).with_indifferent_access
      end

      def persist!
        # This is a somewhat ridiculous trick to avoid merge conflicts in git.
        #
        # Normally, new migrations are added to the bottom of the Nandi lockfile.
        # This is relatively unfriendly to git's merge algorithm, and means that
        # if someone merges a pull request with a completely unrelated migration,
        # you'll have to rebase to get yours merged as the last line of the file
        # will be seen as a conflict (both branches added content there).
        #
        # This is in contrast to something like Gemfile.lock, where changes tend
        # to be distributed throughout the file. The idea behind sorting by
        # SHA-256 hash is to distribute new Nandi lockfile entries evenly, but
        # also stably through the file. It needs to be stable or we'd have even
        # worse merge conflict problems (e.g. if we randomised the order on
        # writing the file, the whole thing would conflict pretty much every time
        # it was regenerated).
        lockfiles.each do |db_name, lockfile|
          content = lockfile.to_h.deep_stringify_keys.sort_by do |k, _|
            Digest::SHA256.hexdigest(k)
          end.to_h.to_yaml

          File.write(path(db_name), content)
        end
      end

      def path(db_name)
        Nandi.config.lockfile_path(db_name)
      end

      def lockfiles
        @lockfiles ||= {}
      end

      attr_writer :lockfiles
    end
  end
end
