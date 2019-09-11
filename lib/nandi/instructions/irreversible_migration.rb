# frozen_string_literal: true

module Nandi
  module Instructions
    class IrreversibleMigration
      def lock
        Nandi::Migration::LockWeights::SHARE
      end

      def procedure
        :irreversible_migration
      end
    end
  end
end
