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

# Restore the database with verbose output to see errors
echo "Starting pg_restore..."
pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fd -j 4 --no-owner --no-privileges --verbose /causalehr_backup 2>&1 | tee /tmp/restore.log || {
    echo "ERROR: pg_restore failed. Check logs above."
    echo "Last 50 lines of restore log:"
    tail -50 /tmp/restore.log
    exit 1
}

# Fix ownership issues by reassigning to current user
echo "Fixing ownership..."
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
    ALTER SCHEMA filtered OWNER TO $POSTGRES_USER;
    ALTER SCHEMA public OWNER TO $POSTGRES_USER;
EOSQL

echo "Checking restored tables..."
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt filtered.*"

# Verify data was actually restored
echo "Verifying data counts..."
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 'predication' as table, COUNT(*) FROM filtered.predication UNION ALL SELECT 'subject_search', COUNT(*) FROM filtered.subject_search UNION ALL SELECT 'object_search', COUNT(*) FROM filtered.object_search UNION ALL SELECT 'sentence', COUNT(*) FROM public.sentence;"

echo "Database restore completed successfully!"
