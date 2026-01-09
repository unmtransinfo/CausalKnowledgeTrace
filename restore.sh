#!/bin/bash
set -e

echo "Starting database restore process..."
echo "POSTGRES_USER: $POSTGRES_USER"
echo "POSTGRES_DB: $POSTGRES_DB"

# Check if backup directory exists and list contents
echo "Checking backup directory..."
if [ -d "/causalehr_backup" ]; then
    echo "Backup directory contents:"
    ls -la /causalehr_backup/
else
    echo "ERROR: Backup directory /causalehr_backup does not exist!"
    exit 1
fi

# Restore the database, ignoring ownership errors
echo "Starting pg_restore..."
pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fd -j 4 --no-owner --no-privileges /causalehr_backup || true

# Fix ownership issues by reassigning to current user
echo "Fixing ownership..."
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL || true
    ALTER SCHEMA filtered OWNER TO $POSTGRES_USER;
    ALTER SCHEMA public OWNER TO $POSTGRES_USER;
EOSQL

echo "Checking restored tables..."
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt filtered.*"

echo "Database restore completed successfully!"
