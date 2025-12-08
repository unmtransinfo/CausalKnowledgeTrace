-- Create optimized indexes for CUI search tables
-- This significantly improves search performance by enabling index-based lookups

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- ============================================================================
-- SUBJECT_SEARCH TABLE INDEXES
-- ============================================================================

-- Primary B-tree index on name for exact and prefix matching
CREATE INDEX IF NOT EXISTS idx_subject_search_name_btree 
ON filtered.subject_search (name);

-- Trigram index for fuzzy/partial matching (LIKE queries)
CREATE INDEX IF NOT EXISTS idx_subject_search_name_trgm 
ON filtered.subject_search USING gin (name gin_trgm_ops);

-- Case-insensitive trigram index for better LIKE performance
CREATE INDEX IF NOT EXISTS idx_subject_search_name_lower_trgm 
ON filtered.subject_search USING gin (LOWER(name) gin_trgm_ops);

-- ============================================================================
-- OBJECT_SEARCH TABLE INDEXES
-- ============================================================================

-- Primary B-tree index on name for exact and prefix matching
CREATE INDEX IF NOT EXISTS idx_object_search_name_btree 
ON filtered.object_search (name);

-- Trigram index for fuzzy/partial matching (LIKE queries)
CREATE INDEX IF NOT EXISTS idx_object_search_name_trgm 
ON filtered.object_search USING gin (name gin_trgm_ops);

-- Case-insensitive trigram index for better LIKE performance
CREATE INDEX IF NOT EXISTS idx_object_search_name_lower_trgm 
ON filtered.object_search USING gin (LOWER(name) gin_trgm_ops);

-- ============================================================================
-- ANALYZE TABLES FOR QUERY PLANNER
-- ============================================================================

-- Update table statistics so PostgreSQL query planner uses indexes
ANALYZE filtered.subject_search;
ANALYZE filtered.object_search;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check if indexes were created successfully
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename IN ('subject_search', 'object_search')
ORDER BY tablename, indexname;

