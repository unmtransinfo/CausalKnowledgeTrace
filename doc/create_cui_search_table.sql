-- Create optimized CUI search table with full-text search capabilities
-- Run this script to set up the search infrastructure

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Create optimized search table in causalehr schema
CREATE TABLE IF NOT EXISTS causalehr.cui_search_index (
    cui VARCHAR(20) NOT NULL,
    name TEXT NOT NULL,
    semtype VARCHAR(50),
    semtype_definition TEXT
);

-- Create temporary table for semtype definitions
CREATE TEMP TABLE semtype_definitions (
    semtype_code VARCHAR(10),
    semtype_name VARCHAR(200)
);

-- Insert semtype definitions from clefSemTypes.txt
INSERT INTO semtype_definitions (semtype_code, semtype_name) VALUES
('aapp', 'Amino Acid, Peptide, or Protein'),
('acab', 'Acquired Abnormality'),
('acty', 'Activity'),
('aggp', 'Age Group'),
('amas', 'Amino Acid Sequence'),
('amph', 'Amphibian'),
('anab', 'Anatomical Abnormality'),
('anim', 'Animal'),
('anst', 'Anatomical Structure'),
('antb', 'Antibiotic'),
('arch', 'Archaeon'),
('bacs', 'Biologically Active Substance'),
('bact', 'Bacterium'),
('bdsu', 'Body Substance'),
('bdsy', 'Body System'),
('bhvr', 'Behavior'),
('biof', 'Biologic Function'),
('bird', 'Bird'),
('blor', 'Body Location or Region'),
('bmod', 'Biomedical Occupation or Discipline'),
('bodm', 'Biomedical or Dental Material'),
('bpoc', 'Body Part, Organ, or Organ Component'),
('bsoj', 'Body Space or Junction'),
('celc', 'Cell Component'),
('celf', 'Cell Function'),
('cell', 'Cell'),
('cgab', 'Congenital Abnormality'),
('chem', 'Chemical'),
('chvf', 'Chemical Viewed Functionally'),
('chvs', 'Chemical Viewed Structurally'),
('clas', 'Classification'),
('clna', 'Clinical Attribute'),
('clnd', 'Clinical Drug'),
('cnce', 'Conceptual Entity'),
('comd', 'Cell or Molecular Dysfunction'),
('crbs', 'Carbohydrate Sequence'),
('diap', 'Diagnostic Procedure'),
('dora', 'Daily or Recreational Activity'),
('drdd', 'Drug Delivery Device'),
('dsyn', 'Disease or Syndrome'),
('edac', 'Educational Activity'),
('eehu', 'Environmental Effect of Humans'),
('elii', 'Element, Ion, or Isotope'),
('emod', 'Experimental Model of Disease'),
('emst', 'Embryonic Structure'),
('enty', 'Entity'),
('enzy', 'Enzyme'),
('euka', 'Eukaryote'),
('evnt', 'Event'),
('famg', 'Family Group'),
('ffas', 'Fully Formed Anatomical Structure'),
('fish', 'Fish'),
('fndg', 'Finding'),
('fngs', 'Fungus'),
('food', 'Food'),
('ftcn', 'Functional Concept'),
('genf', 'Genetic Function'),
('geoa', 'Geographic Area'),
('gngm', 'Gene or Genome'),
('gora', 'Governmental or Regulatory Activity'),
('grpa', 'Group Attribute'),
('grup', 'Group'),
('hcpp', 'Human-caused Phenomenon or Process'),
('hcro', 'Health Care Related Organization'),
('hlca', 'Health Care Activity'),
('hops', 'Hazardous or Poisonous Substance'),
('horm', 'Hormone'),
('humn', 'Human'),
('idcn', 'Idea or Concept'),
('imft', 'Immunologic Factor'),
('inbe', 'Individual Behavior'),
('inch', 'Inorganic Chemical'),
('inpo', 'Injury or Poisoning'),
('inpr', 'Intellectual Product'),
('irda', 'Indicator, Reagent, or Diagnostic Aid'),
('lang', 'Language'),
('lbpr', 'Laboratory Procedure'),
('lbtr', 'Laboratory or Test Result'),
('mamm', 'Mammal'),
('mbrt', 'Molecular Biology Research Technique'),
('mcha', 'Machine Activity'),
('medd', 'Medical Device'),
('menp', 'Mental Process'),
('mnob', 'Manufactured Object'),
('mobd', 'Mental or Behavioral Dysfunction'),
('moft', 'Molecular Function'),
('mosq', 'Molecular Sequence'),
('neop', 'Neoplastic Process'),
('nnon', 'Nucleic Acid, Nucleoside, or Nucleotide'),
('npop', 'Natural Phenomenon or Process'),
('nusq', 'Nucleotide Sequence'),
('ocac', 'Occupational Activity'),
('ocdi', 'Occupation or Discipline'),
('orch', 'Organic Chemical'),
('orga', 'Organism Attribute'),
('orgf', 'Organism Function'),
('orgm', 'Organism'),
('orgt', 'Organization'),
('ortf', 'Organ or Tissue Function'),
('patf', 'Pathologic Function'),
('phob', 'Physical Object'),
('phpr', 'Phenomenon or Process'),
('phsf', 'Physiologic Function'),
('phsu', 'Pharmacologic Substance'),
('plnt', 'Plant'),
('podg', 'Patient or Disabled Group'),
('popg', 'Population Group'),
('prog', 'Professional or Occupational Group'),
('pros', 'Professional Society'),
('qlco', 'Qualitative Concept'),
('qnco', 'Quantitative Concept'),
('rcpt', 'Receptor'),
('rept', 'Reptile'),
('resa', 'Research Activity'),
('resd', 'Research Device'),
('rnlw', 'Regulation or Law'),
('sbst', 'Substance'),
('shro', 'Self-help or Relief Organization'),
('socb', 'Social Behavior'),
('sosy', 'Sign or Symptom'),
('spco', 'Spatial Concept'),
('tisu', 'Tissue'),
('tmco', 'Temporal Concept'),
('topp', 'Therapeutic or Preventive Procedure'),
('virs', 'Virus'),
('vita', 'Vitamin'),
('vtbt', 'Vertebrate');

-- Populate the table from causalentity with semtype definitions
INSERT INTO causalehr.cui_search_index (cui, name, semtype, semtype_definition)
SELECT DISTINCT
    ce.cui,
    -- Normalize name: lowercase, remove special chars, standardize spaces
    REGEXP_REPLACE(
        REGEXP_REPLACE(
            LOWER(TRIM(ce.name)), 
            '[^a-z0-9\s]', ' ', 'g'
        ), 
        '\s+', ' ', 'g'
    ) as name,
    ce.semtype,
    COALESCE(sd.semtype_name, 'Unknown Semantic Type') as semtype_definition
FROM causalehr.causalentity ce
LEFT JOIN semtype_definitions sd ON ce.semtype = sd.semtype_code
WHERE ce.name IS NOT NULL 
    AND TRIM(ce.name) != ''
    AND ce.cui IS NOT NULL
ON CONFLICT DO NOTHING;

-- Create indexes for maximum search performance
CREATE INDEX IF NOT EXISTS cui_search_cui_idx ON causalehr.cui_search_index (cui);
CREATE INDEX IF NOT EXISTS cui_search_name_idx ON causalehr.cui_search_index (name);
CREATE INDEX IF NOT EXISTS cui_search_semtype_idx ON causalehr.cui_search_index (semtype);
CREATE INDEX IF NOT EXISTS cui_search_semtype_def_idx ON causalehr.cui_search_index (semtype_definition);

-- Trigram indexes for fuzzy matching
CREATE INDEX IF NOT EXISTS cui_search_name_trgm_idx ON causalehr.cui_search_index USING GIN (name gin_trgm_ops);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS cui_search_name_semtype_idx ON causalehr.cui_search_index (name, semtype);

-- Update statistics for query planner
ANALYZE causalehr.cui_search_index;

-- Show population results
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT cui) as unique_cuis,
    COUNT(DISTINCT semtype) as unique_semtypes,
    COUNT(DISTINCT semtype_definition) as unique_definitions
FROM causalehr.cui_search_index;

-- Example queries for testing performance
-- Exact match:
-- SELECT cui, name, semtype, semtype_definition FROM causalehr.cui_search_index WHERE name = 'diabetes';

-- Search by semantic type definition:
-- SELECT cui, name, semtype, semtype_definition FROM causalehr.cui_search_index WHERE semtype_definition LIKE '%Disease%';

-- Fuzzy search:
-- SELECT cui, name, semtype, semtype_definition, similarity(name, 'diabets') as sim 
-- FROM causalehr.cui_search_index 
-- WHERE similarity(name, 'diabets') > 0.3 
-- ORDER BY sim DESC LIMIT 10;