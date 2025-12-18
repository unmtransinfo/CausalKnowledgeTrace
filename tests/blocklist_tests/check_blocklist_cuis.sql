-- Query to check what the blocklisted CUIs represent
-- Run this to understand what concepts are being filtered out

SELECT DISTINCT subject_cui, subject_name
FROM filtered.predication
WHERE subject_cui IN ('C0450442', 'C0101842', 'C2348003')
LIMIT 10;

SELECT DISTINCT object_cui, object_name
FROM filtered.predication
WHERE object_cui IN ('C0450442', 'C0101842', 'C2348003')
LIMIT 10;

