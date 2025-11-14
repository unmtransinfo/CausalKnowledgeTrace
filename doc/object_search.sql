DROP TABLE IF EXISTS filtered.object_search;
CREATE TABLE filtered.object_search (
    "cui" TEXT PRIMARY KEY,
    "name" TEXT,
    "semtype" TEXT[]
);

INSERT INTO filtered.object_search (cui, name, semtype)
SELECT object_cui, MAX(object_name), ARRAY_AGG(DISTINCT object_semtype)
FROM filtered.predication 
WHERE object_cui IS NOT NULL
    AND object_cui LIKE 'C%' 
GROUP BY object_cui;


ALTER TABLE filtered.object_search DROP COLUMN IF EXISTS semtype_definition;

ALTER TABLE filtered.object_search ADD COLUMN semtype_definition TEXT[];

UPDATE filtered.object_search os
SET semtype_definition = (
    SELECT ARRAY_AGG(st.semtype_definition ORDER BY st.semtype)
    FROM semantic_types st
    WHERE st.semtype = ANY(os.semtype)
);