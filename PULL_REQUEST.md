# Multi-Database Support for Nandi

## Summary

This PR implements multi-database support for Nandi, allowing developers to organize migrations across multiple databases (e.g., primary, analytics, read replicas) while maintaining full backward compatibility.

**Key Features:**
- Database-specific migration directories and output paths
- Database declaration syntax in migration classes
- Enhanced generators with database targeting
- Database-aware lockfile management
- Zero breaking changes - existing single-database projects work unchanged

## Interface Changes

### Configuration API

```ruby
# New configuration option for multi-database setups
Nandi.configure do |config|
  config.databases = {
    primary: { 
      migration_directory: "db/safe_migrations/primary" 
    },
    analytics: { 
      migration_directory: "db/safe_migrations/analytics",
      output_directory: "db/migrate/analytics"
    },
    read_replica: {
      migration_directory: "db/safe_migrations/read_replica"
    }
  }
end
```

### Migration Declaration API

```ruby
# New database declaration method
class CreateUsersTable < Nandi::Migration
  database :primary  # ← New database targeting

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
```

### Generator Enhancements

```bash
# Generate migration for specific database
rails generate nandi:migration create_reports --database=analytics

# Generate migration without database (backward compatible)
rails generate nandi:migration create_logs
```

### New Configuration Methods

- `config.databases` - Hash of database configurations
- `config.migration_directory_for(db_name)` - Get migration directory for specific database
- `config.output_directory_for(db_name)` - Get output directory for specific database  
- `config.multi_database?` - Check if multi-database mode is enabled
- `config.database_names` - Get list of configured database names
- `config.validate_databases!` - Validate database configuration

### Enhanced .nandilock.yml Handling

The multi-database implementation enhances the existing `.nandilock.yml` lockfile to track database-specific migration metadata while maintaining full backward compatibility:

#### Database-Specific Entries
```yaml
# Multi-database .nandilock.yml structure
primary/20240101120000_create_users.rb:
  source_digest: "abc123..."
  compiled_digest: "def456..."
  database: "primary"

analytics/20240101120001_create_reports.rb:
  source_digest: "ghi789..."
  compiled_digest: "jkl012..."
  database: "analytics"

# Legacy entries (no database prefix)
20240101120002_create_logs.rb:
  source_digest: "mno345..."
  compiled_digest: "pqr678..."
```

#### Key Features
- **Database-prefixed keys** - `{database}/{migration_file}` format for database-specific migrations
- **Database metadata** - Includes `database: "name"` field for tracking migration context
- **Backward compatibility** - Non-prefixed entries for legacy migrations continue to work
- **Fallback lookups** - Database-specific lookups fall back to non-prefixed entries when needed
- **Conflict prevention** - SHA-256 hash-based sorting prevents merge conflicts (existing behavior maintained)

## Implementation Changes

### Core System Changes

1. **Enhanced Config System** (`lib/nandi/config.rb`)
   - Added `databases` attribute for multi-database configuration
   - Added database-specific directory resolution methods
   - Added validation for database configurations
   - Maintained backward compatibility with existing config options

2. **Migration Class Extensions** (`lib/nandi/migration.rb`)
   - Added `database` class method for targeting specific databases
   - Added `target_database` instance method to retrieve database target
   - Ensured backward compatibility - migrations without database declarations work unchanged

3. **Lockfile System Enhancements** (`lib/nandi/lockfile.rb`)
   - Extended `.nandilock.yml` to store database-specific migration entries
   - Uses database-prefixed keys (e.g., `"primary/20240101_migration.rb"`)
   - Falls back to non-prefixed entries for backward compatibility
   - Maintains existing lockfile format and merge conflict prevention for single-database projects
   - Added `database` parameter to `Lockfile.add()` and `Lockfile.get()` methods

4. **Compilation System Updates** (`lib/nandi/compiled_migration.rb`)
   - Enhanced to route migrations to database-specific output directories
   - Updated lockfile integration to include database context
   - Maintained compatibility with existing migration compilation

5. **Generator Improvements**
   - **Migration Generator** (`lib/generators/nandi/migration/migration_generator.rb`)
     - Added `--database` option for targeting specific databases
     - Updated template to include database declarations when specified
     - Maintained backward compatibility for generators without database option
   
   - **Compile Generator** (`lib/generators/nandi/compile/compile_generator.rb`)
     - Enhanced to discover migrations across multiple database directories
     - Updated to pass database context to lockfile system
     - Maintained single-database compilation behavior

### File Structure Changes

**Templates:**
- Updated `lib/generators/nandi/migration/templates/migration.rb` to conditionally include database declarations

**Tests:**
- Added comprehensive test suite covering multi-database functionality
- Added integration tests for end-to-end multi-database workflows
- Added generator tests for database-specific migration generation

## Backward Compatibility Assessment

### ✅ Fully Compatible - No Changes Required

1. **Existing Migration Files** - All existing Nandi migrations continue to work without modification
2. **Configuration** - Single-database projects require no config changes
3. **Generators** - `rails generate nandi:migration` and `rails generate nandi:compile` work exactly as before
4. **Lockfile Format** - Existing `.nandilock.yml` files continue to work unchanged, with new database-prefixed entries added for multi-database migrations
5. **API Methods** - All existing public methods maintain their signatures and behavior

### ✅ Enhanced but Compatible

1. **Configuration Methods** - Existing methods work as before, with new methods available for multi-database scenarios
2. **Migration Class API** - New `database` method is optional, doesn't affect migrations that don't use it
3. **Lockfile Lookup** - Enhanced to support database-specific lookups while maintaining backward-compatible fallbacks

### ✅ Zero Breaking Changes

- No method signature changes
- No removed functionality  
- No behavioral changes for existing single-database usage
- No migration required for existing projects

## Testing Instructions

### Prerequisites

```bash
# Install dependencies
bundle install

# Set up test database configuration
export DATABASE_URL="postgres://localhost/nandi_test"
```

### Unit Tests

```bash
# Run all tests
bundle exec rspec

# Run multi-database specific tests
bundle exec rspec spec/nandi/multi_database_spec.rb

# Run integration tests
bundle exec rspec spec/integration/multi_database_integration_spec.rb

# Run generator tests  
bundle exec rspec spec/generators/migration_generator_spec.rb
```

### Manual Testing

#### 1. Single Database Compatibility Test

```bash
# Create a standard migration (should work exactly as before)
rails generate nandi:migration create_widgets

# Compile (should work exactly as before)
rails generate nandi:compile
```

#### 2. Multi-Database Feature Test

```bash
# Configure multi-database setup in config/initializers/nandi.rb
cat > config/initializers/nandi.rb << 'EOF'
Nandi.configure do |config|
  config.databases = {
    primary: { migration_directory: "db/safe_migrations/primary" },
    analytics: { 
      migration_directory: "db/safe_migrations/analytics",
      output_directory: "db/migrate/analytics"
    }
  }
end
EOF

# Create database-specific directories
mkdir -p db/safe_migrations/primary db/safe_migrations/analytics db/migrate/analytics

# Generate database-specific migrations
rails generate nandi:migration create_users --database=primary
rails generate nandi:migration create_reports --database=analytics

# Verify migrations contain database declarations
grep "database :primary" db/safe_migrations/primary/*_create_users.rb
grep "database :analytics" db/safe_migrations/analytics/*_create_reports.rb

# Compile all migrations
rails generate nandi:compile

# Verify output locations
ls db/migrate/              # Should contain create_users migration
ls db/migrate/analytics/    # Should contain create_reports migration

# Verify lockfile contains database-specific entries
grep "primary/" .nandilock.yml
grep "analytics/" .nandilock.yml

# Example .nandilock.yml structure:
cat .nandilock.yml
# Shows:
# primary/20240101120000_create_users.rb:
#   source_digest: abc123...
#   compiled_digest: def456...
#   database: primary
# analytics/20240101120001_create_reports.rb:  
#   source_digest: ghi789...
#   compiled_digest: jkl012...
#   database: analytics
```

#### 3. Mixed Migration Test

```bash
# Generate migration without database specification (backward compatibility)
rails generate nandi:migration create_logs

# This should work alongside database-specific migrations
rails generate nandi:compile

# Verify all migrations compile correctly
ls db/migrate/              # Should contain logs migration
ls db/migrate/analytics/    # Should still contain reports migration
```

### Performance Testing

```bash
# Test with large numbers of migrations across databases
for i in {1..50}; do
  rails generate nandi:migration "migration_primary_$i" --database=primary
  rails generate nandi:migration "migration_analytics_$i" --database=analytics  
done

time rails generate nandi:compile  # Should compile efficiently
```

### Error Handling Tests

```bash
# Test invalid database configuration
# (Add invalid config and verify helpful error messages)

# Test missing migration directories
# (Remove directory and verify graceful handling)

# Test lockfile corruption scenarios
# (Test recovery and error reporting)
```

## Configuration Migration Guide

### For New Multi-Database Projects

```ruby
# config/initializers/nandi.rb
Nandi.configure do |config|
  config.databases = {
    primary: { 
      migration_directory: "db/safe_migrations/primary" 
    },
    analytics: { 
      migration_directory: "db/safe_migrations/analytics",
      output_directory: "db/migrate/analytics"
    }
  }
end
```

### For Existing Single-Database Projects

No changes required! Existing projects will continue to work exactly as before. When ready to adopt multi-database features:

1. Add `config.databases` to your Nandi configuration
2. Move existing migrations to database-specific directories if desired
3. Start using `--database` option with generators for new migrations

## Changelog

### User-Facing Changes

#### Added
- **Multi-database configuration support** - Configure multiple databases with specific migration and output directories
- **Database declaration syntax** - `database :name` method in migration classes to target specific databases  
- **Database-aware generators** - `--database` option for `nandi:migration` generator
- **Enhanced compile generator** - Automatically discovers and compiles migrations from all configured database directories
- **New configuration methods**:
  - `config.databases` - Hash of database configurations
  - `config.migration_directory_for(db)` - Get migration directory for specific database
  - `config.output_directory_for(db)` - Get output directory for specific database
  - `config.multi_database?` - Check if multi-database mode enabled
  - `config.database_names` - List configured database names
  - `config.validate_databases!` - Validate database configuration

### Internal Implementation Changes

#### Modified
- **`Nandi::Config`** - Extended with multi-database configuration support and validation
- **`Nandi::Migration`** - Added database targeting capability while maintaining backward compatibility
- **`Nandi::Lockfile`** - Enhanced to handle database-specific migration entries with fallback support
- **`Nandi::CompiledMigration`** - Updated to route migrations to correct output directories based on database target
- **`Nandi::MigrationGenerator`** - Added database option and template support for database declarations
- **`Nandi::CompileGenerator`** - Enhanced to discover migrations across multiple database directories

#### Test Coverage
- **Added comprehensive test suite** covering multi-database functionality
- **Added integration tests** for end-to-end multi-database workflows  
- **Added generator tests** for database-specific migration creation
- **Added backward compatibility tests** ensuring existing functionality unchanged

### Migration Path

- **No breaking changes** - Existing single-database projects work without modification
- **Gradual adoption** - Multi-database features can be adopted incrementally
- **Automatic migration** - No manual migration of existing lockfiles or migrations required

## Performance Impact

- **Minimal overhead** - Multi-database features only activate when configured
- **Efficient file discovery** - Optimized directory scanning for multiple migration locations
- **Lockfile performance** - Database-prefixed keys provide O(1) lookup with fallback support
- **Memory usage** - No significant memory overhead for single-database projects

## Security Considerations

- **No new attack vectors** introduced
- **Configuration validation** prevents invalid database configurations
- **Path traversal protection** maintained for all directory operations
- **Backward compatibility** ensures existing security measures remain effective

---

## Breaking Change Assessment: NONE ✅

This implementation introduces zero breaking changes. All existing functionality is preserved and enhanced, making this a purely additive feature that enables multi-database support while maintaining complete backward compatibility.