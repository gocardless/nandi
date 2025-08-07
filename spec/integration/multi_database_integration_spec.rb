# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "Multi-database integration" do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @tmpdir = tmpdir
      # Setup directory structure
      FileUtils.mkdir_p("#{tmpdir}/db/safe_migrations/primary")
      FileUtils.mkdir_p("#{tmpdir}/db/safe_migrations/analytics") 
      FileUtils.mkdir_p("#{tmpdir}/db/migrate")
      FileUtils.mkdir_p("#{tmpdir}/db/migrate/analytics")
      
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end

  before do
    # Reset config
    Nandi.instance_variable_set(:@config, nil)
    
    # Configure multi-database setup
    Nandi.configure do |config|
      config.migration_directory = "#{@tmpdir}/db/safe_migrations"
      config.output_directory = "#{@tmpdir}/db/migrate"
      config.lockfile_directory = @tmpdir
      config.databases = {
        primary: { 
          migration_directory: "#{@tmpdir}/db/safe_migrations/primary" 
        },
        analytics: { 
          migration_directory: "#{@tmpdir}/db/safe_migrations/analytics",
          output_directory: "#{@tmpdir}/db/migrate/analytics"
        }
      }
    end
  end

  it "compiles database-specific migrations correctly" do
    # Create primary database migration
    primary_migration = <<~RUBY
      class CreateUsers < Nandi::Migration
        database :primary

        def up
          create_table :users do |t|
            t.text :name
            t.text :email
          end
        end

        def down
          drop_table :users
        end
      end
    RUBY

    # Create analytics database migration  
    analytics_migration = <<~RUBY
      class CreateReports < Nandi::Migration
        database :analytics

        def up
          create_table :reports do |t|
            t.text :title
            t.integer :user_id
          end
        end

        def down
          drop_table :reports
        end
      end
    RUBY

    # Create legacy migration (no database specified)
    legacy_migration = <<~RUBY
      class CreateLogs < Nandi::Migration
        def up
          create_table :logs do |t|
            t.text :message
          end
        end

        def down
          drop_table :logs
        end
      end
    RUBY

    # Write migration files
    File.write("#{@tmpdir}/db/safe_migrations/primary/20240101120000_create_users.rb", primary_migration)
    File.write("#{@tmpdir}/db/safe_migrations/analytics/20240101120001_create_reports.rb", analytics_migration)
    File.write("#{@tmpdir}/db/safe_migrations/20240101120002_create_logs.rb", legacy_migration)

    # Compile migrations
    all_files = [
      "#{@tmpdir}/db/safe_migrations/primary/20240101120000_create_users.rb",
      "#{@tmpdir}/db/safe_migrations/analytics/20240101120001_create_reports.rb", 
      "#{@tmpdir}/db/safe_migrations/20240101120002_create_logs.rb"
    ]

    compiled_migrations = []
    Nandi.compile(files: all_files) do |results|
      compiled_migrations = results
      results.each do |result|
        # Simulate what the compile generator does
        Nandi::Lockfile.add(
          file_name: result.file_name,
          source_digest: result.source_digest,
          compiled_digest: result.compiled_digest,
          database: result.target_database
        )

        # Write compiled files
        FileUtils.mkdir_p(File.dirname(result.output_path))
        File.write(result.output_path, result.body)
      end
    end

    # Verify migrations were compiled to correct locations
    expect(File.exist?("#{@tmpdir}/db/migrate/20240101120000_create_users.rb")).to be true
    expect(File.exist?("#{@tmpdir}/db/migrate/analytics/20240101120001_create_reports.rb")).to be true  
    expect(File.exist?("#{@tmpdir}/db/migrate/20240101120002_create_logs.rb")).to be true

    # Verify compiled migration contents reference correct databases through connection handling
    users_compiled = File.read("#{@tmpdir}/db/migrate/20240101120000_create_users.rb")
    reports_compiled = File.read("#{@tmpdir}/db/migrate/analytics/20240101120001_create_reports.rb")
    logs_compiled = File.read("#{@tmpdir}/db/migrate/20240101120002_create_logs.rb")

    # All compiled migrations should be valid ActiveRecord migrations
    expect(users_compiled).to include("class CreateUsers < ActiveRecord::Migration")
    expect(reports_compiled).to include("class CreateReports < ActiveRecord::Migration") 
    expect(logs_compiled).to include("class CreateLogs < ActiveRecord::Migration")

    # Verify lockfile contains database-specific entries
    lockfile = YAML.load_file("#{@tmpdir}/.nandilock.yml")
    
    expect(lockfile).to have_key("primary/20240101120000_create_users.rb")
    expect(lockfile["primary/20240101120000_create_users.rb"]).to include("database" => "primary")
    
    expect(lockfile).to have_key("analytics/20240101120001_create_reports.rb") 
    expect(lockfile["analytics/20240101120001_create_reports.rb"]).to include("database" => "analytics")
    
    # Legacy migration should not have database prefix
    expect(lockfile).to have_key("20240101120002_create_logs.rb")
    expect(lockfile["20240101120002_create_logs.rb"]).not_to have_key("database")
  end

  it "handles migration file discovery across multiple directories" do
    # Create migrations in different database directories
    File.write("#{@tmpdir}/db/safe_migrations/primary/20240101120000_primary_migration.rb", <<~RUBY)
      class PrimaryMigration < Nandi::Migration
        database :primary
        def up; end
        def down; end
      end
    RUBY

    File.write("#{@tmpdir}/db/safe_migrations/analytics/20240101120001_analytics_migration.rb", <<~RUBY)
      class AnalyticsMigration < Nandi::Migration  
        database :analytics
        def up; end
        def down; end
      end
    RUBY

    # Use the compile generator logic to discover files
    migration_dirs = Nandi.config.database_names.map do |db_name|
      Nandi.config.migration_directory_for(db_name)
    end.uniq

    discovered_files = migration_dirs.flat_map do |dir|
      next [] unless Dir.exist?(dir)
      
      Dir.chdir(dir) { Dir["*.rb"] }.map { |file| File.join(dir, file) }
    end.compact

    expect(discovered_files).to include("#{@tmpdir}/db/safe_migrations/primary/20240101120000_primary_migration.rb")
    expect(discovered_files).to include("#{@tmpdir}/db/safe_migrations/analytics/20240101120001_analytics_migration.rb")
    expect(discovered_files.length).to eq(2)
  end
end