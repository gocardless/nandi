# RFC: Multi-Database Support for Nandi

**Status:** Draft | **Issue:** [#137](https://github.com/gocardless/nandi/issues/137) | **Date:** 2025-08-07

## Summary

Adds multi-database support to Nandi with database declaration syntax. Zero breaking changes - existing single-database projects work unchanged.

## API Design

### Database Declaration in Migrations
```ruby
class CreateUsersTable < Nandi::Migration
  database :primary  # Target specific database
  
  def up
    create_table :users do |t|
      t.string :email
    end
  end
end
```

### Multi-Database Configuration
```ruby
Nandi.configure do |config|
  config.databases = {
    primary: { migration_directory: "db/safe_migrations/primary" },
    analytics: { 
      migration_directory: "db/safe_migrations/analytics",
      output_directory: "db/migrate/analytics" 
    }
  }
end
```

### Generator Support
```bash
# Generate database-specific migration
rails generate nandi:migration create_reports --database=analytics

# Compile all databases
rails generate nandi:compile
```

## Implementation

### Core Changes
- **Nandi::Migration**: Added `database(name)` class method and `target_database` accessor
- **Nandi::Config**: Added `databases` hash with helper methods (`migration_directory_for`, `output_directory_for`, `multi_database?`)
- **Nandi::CompiledMigration**: Routes migrations to database-specific output directories
- **Generators**: Enhanced with `--database` option for targeting specific databases

### Enhanced Lockfile (.nandilock.yml)
```yaml
# Database-specific entries (new)
primary/20240101120000_create_users.rb:
  source_digest: "abc123"
  compiled_digest: "def456"
  database: "primary"

# Legacy entries (unchanged - backward compatible)  
20240101120000_legacy_migration.rb:
  source_digest: "xyz789"
  compiled_digest: "uvw012"
```

Database-prefixed keys enable isolation while maintaining backward compatibility through fallback lookups.

## Backward Compatibility

- **100% Compatible**: Existing single-database projects require no changes
- **Graceful Fallbacks**: Multi-database methods return single-database defaults when `databases` config is empty
- **Legacy Migration Support**: Non-prefixed lockfile entries continue working

## Testing

Complete test coverage with 301 passing specs including:
- Multi-database configuration and routing
- Database declaration syntax validation  
- Lockfile backward compatibility
- Generator enhancements
- Edge case handling

---

**Ready for production use** - implements Option 2 (Database Declaration Method) from issue #137.