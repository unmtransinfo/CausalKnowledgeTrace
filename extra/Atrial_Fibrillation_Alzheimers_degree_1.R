# Exported DAG from degree_1.R
# Generated on 2026-01-12 02:51:39.674172

library(dagitty)

g <- dagitty('dag {
APP_gene
APP_protein_human
Ablation
Acetylcholine
Acetylcholinesterase
Aconitine
Adenosine
Adverse_effects
Agent
Aging
Alzheimers [outcome]
Amyloid
Amyloid_Fibrils
Amyloid_beta
Amyloid_beta_Peptides
Amyloid_beta_Protein_Precursor
Amyloid_deposition
Amyloidosis
Antioxidants
Apolipoprotein_E4
Apolipoprotein_E_APOE
Atrial_Fibrillation [exposure]
Atrial_Premature_Complexes
Atrial_Remodeling
Atrial_effective_refractory_period
Atrophic
Brain_Injuries
Cardiac_ablation
Cardioembolic_stroke
Cardiomyopathies
Cardiovascular_morbidity
Cerebral_Amyloid_Angiopathy
Cerebral_Embolism
Cerebral_Infarction
Cerebral_atrophy
Cerebrospinal_Fluid
Cerebrovascular_accident
Cessation_of_life
Cholesterol
Chronic_inflammation
Complication
Congestive_heart_failure
Copper
DNA_Mitochondrial
Degenerative_abnormality
Dementia
Dementia_Vascular
Deterioration
Diabetes
Diabetes_Mellitus_Non_Insulin_Dependent
Diagnosis
Diet
Disability_NOS
Disease
Down_Syndrome
Electric_Countershock
Embolic_stroke
Endopeptidases
Enzymes
Evaluation
Evaluation_procedure
FRAGMENTS
Fibrosis
Free_Radicals
Functional_disorder
Functional_mitral_regurgitation
Gene_Mutation
Genes
Glycogen_Synthase_Kinase_3
Glycosylation_End_Products_Advanced
Heart_Diseases
Heart_failure
Herpesvirus_1_Human
Hospitalization
Hypertensive_disease
Hyperthyroidism
Hypoxia
IMPACT_gene
Impaired_cognition
Induction
Inflammasomes
Inflammation
Inflammatory_Response
Injection
Injection_procedure
Injury
Insulin_Resistance
Intestinal_Microbiome
Ions
Iron
Ischemia
Ischemic_stroke
Isolation_procedure
Isoproterenol
Lewy_Body_Disease
Lipids
Lipopolysaccharides
MAPT
MAPT_protein_human_MAPT
Memory_Loss
Memory_impairment
Mental_deterioration
Metals
MicroRNAs
Molecule
Mutation
Need_for_isolation
Nerve_Degeneration
Neurodegenerative_Disorders
Neurofibrillary_Tangles
Neurotoxins
Nicotinic_Receptors
Nitric_Oxide
Obesity
Okadaic_Acid
Oxidation
Oxidative_Stress
PS2_protein_alzheimer_associated_PSEN2
PSEN1
Parkinson_Disease
Pathogenesis
Pathologic_Processes
Peptides
Pharmaceutical_Preparations
Players
Polymorphism_Genetic
Premature_Cardiac_Complex
Prions
Process
Proteins
Reactive_Oxygen_Species
SUCLA2_gene_SUCLA2
Senile_Plaques
Senile_dementia
Single_Nucleotide_Polymorphism
Sinus_rhythm
Sleep_Apnea_Obstructive
Study_models
Symptoms
Syndrome
Therapeutic_procedure
Thromboembolism
Thrombus
Thyrotoxicosis
Toxic_effect
Transesophageal_cardiac_pacing_procedure
Transient_Ischemic_Attack
Traumatic_Brain_Injury
Vascular_Diseases
Ventricular_Fibrillation
Virus
Zinc
aluminum
aluminum_chloride
angiotensin_II
apolipoprotein_E_4_APOE
beta_site_APP_cleaving_enzyme_1_BACE1
cytokine
galactose
gamma_secretase
gene_therapy
homocysteine
imbalance
neuron_loss
neuronal
presenilin
presenilin_1
presenilin_1_PSEN1
receptor
scopolamine
streptozocin
tau_Proteins
tau_Proteins_MAPT
vascular_factor
APP_gene -> Alzheimers
APP_protein_human -> Alzheimers
Ablation -> Atrial_Fibrillation
Acetylcholine -> Atrial_Fibrillation
Acetylcholinesterase -> Alzheimers
Aconitine -> Atrial_Fibrillation
Adenosine -> Atrial_Fibrillation
Adverse_effects -> Alzheimers
Agent -> Alzheimers
Alzheimers -> Aging
Alzheimers -> Amyloid_deposition
Alzheimers -> Atrophic
Alzheimers -> Cerebral_atrophy
Alzheimers -> Cessation_of_life
Alzheimers -> Degenerative_abnormality
Alzheimers -> Dementia_Vascular
Alzheimers -> Diagnosis
Alzheimers -> Disability_NOS
Alzheimers -> Disease
Alzheimers -> Evaluation
Alzheimers -> Evaluation_procedure
Alzheimers -> Functional_disorder
Alzheimers -> Inflammation
Alzheimers -> Lewy_Body_Disease
Alzheimers -> Memory_Loss
Alzheimers -> Neurodegenerative_Disorders
Alzheimers -> Neurofibrillary_Tangles
Alzheimers -> Parkinson_Disease
Alzheimers -> Senile_Plaques
Alzheimers -> Senile_dementia
Alzheimers -> Symptoms
Alzheimers -> Syndrome
Amyloid -> Alzheimers
Amyloid_Fibrils -> Alzheimers
Amyloid_beta -> Alzheimers
Amyloid_beta_Peptides -> Alzheimers
Amyloid_beta_Protein_Precursor -> Alzheimers
Amyloid_deposition -> Alzheimers
Amyloidosis -> Alzheimers
Antioxidants -> Alzheimers
Apolipoprotein_E4 -> Alzheimers
Apolipoprotein_E_APOE -> Alzheimers
Atrial_Fibrillation -> Atrial_Remodeling
Atrial_Fibrillation -> Cardioembolic_stroke
Atrial_Fibrillation -> Cardiomyopathies
Atrial_Fibrillation -> Cardiovascular_morbidity
Atrial_Fibrillation -> Cerebral_Embolism
Atrial_Fibrillation -> Cerebral_Infarction
Atrial_Fibrillation -> Cerebrovascular_accident
Atrial_Fibrillation -> Cessation_of_life
Atrial_Fibrillation -> Complication
Atrial_Fibrillation -> Congestive_heart_failure
Atrial_Fibrillation -> Disease
Atrial_Fibrillation -> Embolic_stroke
Atrial_Fibrillation -> Fibrosis
Atrial_Fibrillation -> Functional_mitral_regurgitation
Atrial_Fibrillation -> Heart_failure
Atrial_Fibrillation -> Hospitalization
Atrial_Fibrillation -> Ischemic_stroke
Atrial_Fibrillation -> Thromboembolism
Atrial_Fibrillation -> Thrombus
Atrial_Fibrillation -> Transient_Ischemic_Attack
Atrial_Fibrillation -> Ventricular_Fibrillation
Atrial_Premature_Complexes -> Atrial_Fibrillation
Atrial_Remodeling -> Atrial_Fibrillation
Atrial_effective_refractory_period -> Atrial_Fibrillation
Atrophic -> Alzheimers
Brain_Injuries -> Alzheimers
Cardiac_ablation -> Atrial_Fibrillation
Cerebral_Amyloid_Angiopathy -> Alzheimers
Cerebral_atrophy -> Alzheimers
Cerebrospinal_Fluid -> Alzheimers
Cerebrovascular_accident -> Atrial_Fibrillation
Cholesterol -> Alzheimers
Chronic_inflammation -> Alzheimers
Congestive_heart_failure -> Atrial_Fibrillation
Copper -> Alzheimers
DNA_Mitochondrial -> Alzheimers
Degenerative_abnormality -> Alzheimers
Dementia -> Alzheimers
Deterioration -> Alzheimers
Diabetes -> Alzheimers
Diabetes_Mellitus_Non_Insulin_Dependent -> Alzheimers
Diet -> Alzheimers
Disease -> Alzheimers
Disease -> Atrial_Fibrillation
Down_Syndrome -> Alzheimers
Electric_Countershock -> Atrial_Fibrillation
Endopeptidases -> Alzheimers
Enzymes -> Alzheimers
FRAGMENTS -> Alzheimers
Free_Radicals -> Alzheimers
Functional_disorder -> Alzheimers
Gene_Mutation -> Alzheimers
Genes -> Alzheimers
Glycogen_Synthase_Kinase_3 -> Alzheimers
Glycosylation_End_Products_Advanced -> Alzheimers
Heart_Diseases -> Atrial_Fibrillation
Heart_failure -> Atrial_Fibrillation
Herpesvirus_1_Human -> Alzheimers
Hypertensive_disease -> Alzheimers
Hypertensive_disease -> Atrial_Fibrillation
Hyperthyroidism -> Atrial_Fibrillation
Hypoxia -> Alzheimers
IMPACT_gene -> Alzheimers
Impaired_cognition -> Alzheimers
Induction -> Atrial_Fibrillation
Inflammasomes -> Alzheimers
Inflammation -> Alzheimers
Inflammation -> Atrial_Fibrillation
Inflammatory_Response -> Alzheimers
Injection -> Alzheimers
Injection_procedure -> Alzheimers
Injury -> Alzheimers
Insulin_Resistance -> Alzheimers
Intestinal_Microbiome -> Alzheimers
Ions -> Alzheimers
Iron -> Alzheimers
Ischemia -> Alzheimers
Ischemia -> Atrial_Fibrillation
Isolation_procedure -> Atrial_Fibrillation
Isoproterenol -> Atrial_Fibrillation
Lipids -> Alzheimers
Lipopolysaccharides -> Alzheimers
MAPT -> Alzheimers
MAPT_protein_human_MAPT -> Alzheimers
Memory_impairment -> Alzheimers
Mental_deterioration -> Alzheimers
Metals -> Alzheimers
MicroRNAs -> Alzheimers
Molecule -> Alzheimers
Mutation -> Alzheimers
Need_for_isolation -> Atrial_Fibrillation
Nerve_Degeneration -> Alzheimers
Neurodegenerative_Disorders -> Alzheimers
Neurofibrillary_Tangles -> Alzheimers
Neurotoxins -> Alzheimers
Nicotinic_Receptors -> Alzheimers
Nitric_Oxide -> Alzheimers
Obesity -> Alzheimers
Obesity -> Atrial_Fibrillation
Okadaic_Acid -> Alzheimers
Oxidation -> Alzheimers
Oxidative_Stress -> Alzheimers
PS2_protein_alzheimer_associated_PSEN2 -> Alzheimers
PSEN1 -> Alzheimers
Parkinson_Disease -> Alzheimers
Pathogenesis -> Alzheimers
Pathologic_Processes -> Alzheimers
Peptides -> Alzheimers
Pharmaceutical_Preparations -> Alzheimers
Pharmaceutical_Preparations -> Atrial_Fibrillation
Players -> Alzheimers
Polymorphism_Genetic -> Alzheimers
Premature_Cardiac_Complex -> Atrial_Fibrillation
Prions -> Alzheimers
Process -> Alzheimers
Proteins -> Alzheimers
Reactive_Oxygen_Species -> Alzheimers
SUCLA2_gene_SUCLA2 -> Alzheimers
Single_Nucleotide_Polymorphism -> Alzheimers
Sinus_rhythm -> Atrial_Fibrillation
Sleep_Apnea_Obstructive -> Atrial_Fibrillation
Study_models -> Alzheimers
Study_models -> Atrial_Fibrillation
Symptoms -> Alzheimers
Therapeutic_procedure -> Alzheimers
Therapeutic_procedure -> Atrial_Fibrillation
Thyrotoxicosis -> Atrial_Fibrillation
Toxic_effect -> Alzheimers
Transesophageal_cardiac_pacing_procedure -> Atrial_Fibrillation
Traumatic_Brain_Injury -> Alzheimers
Vascular_Diseases -> Alzheimers
Virus -> Alzheimers
Zinc -> Alzheimers
aluminum -> Alzheimers
aluminum_chloride -> Alzheimers
angiotensin_II -> Atrial_Fibrillation
apolipoprotein_E_4_APOE -> Alzheimers
beta_site_APP_cleaving_enzyme_1_BACE1 -> Alzheimers
cytokine -> Alzheimers
galactose -> Alzheimers
gamma_secretase -> Alzheimers
gene_therapy -> Alzheimers
homocysteine -> Alzheimers
imbalance -> Alzheimers
neuron_loss -> Alzheimers
neuronal -> Alzheimers
presenilin -> Alzheimers
presenilin_1 -> Alzheimers
presenilin_1_PSEN1 -> Alzheimers
receptor -> Alzheimers
scopolamine -> Alzheimers
streptozocin -> Alzheimers
tau_Proteins -> Alzheimers
tau_Proteins_MAPT -> Alzheimers
vascular_factor -> Alzheimers
}
')
