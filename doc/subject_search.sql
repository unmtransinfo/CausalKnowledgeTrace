DROP TABLE IF EXISTS filtered.subject_search;
CREATE TABLE  filtered.subject_search (
    "cui" TEXT PRIMARY KEY,
    "name" TEXT,
    "semtype" TEXT[]
);

INSERT INTO filtered.subject_search (cui, "name", semtype)
SELECT subject_cui, MAX(subject_name), ARRAY_AGG(DISTINCT subject_semtype) 
FROM filtered.predication 
WHERE subject_cui IS NOT NULL 
  AND subject_cui LIKE 'C%'
GROUP BY subject_cui;

ALTER TABLE filtered.subject_search DROP COLUMN IF EXISTS semtype_definition;

ALTER TABLE filtered.subject_search ADD COLUMN semtype_definition TEXT[];

UPDATE filtered.subject_search os
SET semtype_definition = (
    SELECT ARRAY_AGG(st.semtype_definition ORDER BY st.semtype)
    FROM semantic_types st
    WHERE st.semtype = ANY(os.semtype)
);