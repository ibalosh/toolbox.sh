# Git Tools

Collection of Git-related utility scripts.

## Scripts

### git-clean-old.sh
Cleans up old local Git branches to keep your repository tidy.

**Features:**
- Removes local branches older than a specified number of days (default: 14 days)
- Protects main branches (main, master, develop) from deletion
- Supports dry-run mode to preview changes before deletion
- Cross-platform support (macOS and Linux)

**Usage:**
```bash
# Clean branches older than 14 days (default)
./git-clean-old.sh

# Clean branches older than 30 days
./git-clean-old.sh --days 30

# Preview what would be deleted (dry run)
./git-clean-old.sh --dry-run
```

**Options:**
- `--days N` - Set the age threshold in days (default: 14)
- `--dry-run` - Show what would be deleted without actually deleting

**Requirements:**
- Git
- Bash