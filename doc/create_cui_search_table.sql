-- Assuming causalentity table already exists with structure:
-- causalentity (cui, name, semtype) where semtype contains comma-separated values

-- Drop tables if they exist (for clean reinstall)
DROP TABLE IF EXISTS cui_search;
DROP TABLE IF EXISTS semantic_types;

-- Create the semantic types reference table
CREATE TABLE semantic_types (
    semtype_code VARCHAR(10) PRIMARY KEY,
    semtype_definition VARCHAR(200) NOT NULL
);

-- Create the new table with CUI as primary key
-- One row per CUI with semicolon-separated definitions
CREATE TABLE cui_search (
    cui VARCHAR(10) PRIMARY KEY,
    name VARCHAR(500) NOT NULL,
    semtype VARCHAR(500) NOT NULL,
    semtype_defination TEXT NOT NULL
);

-- Create index after table creation
CREATE INDEX idx_cui ON cui_search(cui);

-- Insert semantic type definitions
INSERT INTO semantic_types (semtype_code, semtype_definition) VALUES
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



WITH split_semtypes AS (
    SELECT 
        ce.cui,
        ce.name,
        ce.semtype,
        trim(unnest(string_to_array(ce.semtype, ','))) AS semtype_code
    FROM causalentity ce
)
INSERT INTO cui_search (cui, name, semtype, semtype_defination)
SELECT
    ss.cui,
    ss.name,
    ss.semtype,
    string_agg(DISTINCT COALESCE(st.semtype_definition, ss.semtype_code), ' ; ' ORDER BY COALESCE(st.semtype_definition, ss.semtype_code)) AS semtype_defination
FROM split_semtypes ss
LEFT JOIN semantic_types st ON ss.semtype_code = st.semtype_code
GROUP BY ss.cui, ss.name, ss.semtype
ON CONFLICT (cui) DO NOTHING;