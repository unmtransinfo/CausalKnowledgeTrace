g <- dagitty('dag {
 APP_gene
 APP_protein_human
 Aluminum
 Alzheimers_Disease [outcome]
 Amyloid
 Amyloid_beta_Peptides
 Amyloid_beta_Protein_Precursor
 Apolipoprotein_E_APOE
 Cessation_of_life
 Dementia
 Disease
 Functional_disorder
 Genes
 Inflammation
 MAPT
 Mutation
 Nerve_Degeneration
 Oxidative_Stress
 Peptides
 Process
 Proteins
 SUCLA2_gene_SUCLA2
 Study_models
 aluminum_chloride
 streptozocin
 APP_gene -> Alzheimers_Disease
 APP_protein_human -> Alzheimers_Disease
 Aluminum -> Alzheimers_Disease
 Alzheimers_Disease -> Cessation_of_life
 Alzheimers_Disease -> Disease
 Alzheimers_Disease -> Functional_disorder
 Amyloid -> Alzheimers_Disease
 Amyloid_beta_Peptides -> Alzheimers_Disease
 Amyloid_beta_Protein_Precursor -> Alzheimers_Disease
 Apolipoprotein_E_APOE -> Alzheimers_Disease
 Dementia -> Alzheimers_Disease
 Disease -> Alzheimers_Disease
 Functional_disorder -> Alzheimers_Disease
 Genes -> Alzheimers_Disease
 Inflammation -> Alzheimers_Disease
 MAPT -> Alzheimers_Disease
 Mutation -> Alzheimers_Disease
 Nerve_Degeneration -> Alzheimers_Disease
 Oxidative_Stress -> Alzheimers_Disease
 Peptides -> Alzheimers_Disease
 Process -> Alzheimers_Disease
 Proteins -> Alzheimers_Disease
 SUCLA2_gene_SUCLA2 -> Alzheimers_Disease
 Study_models -> Alzheimers_Disease
 aluminum_chloride -> Alzheimers_Disease
 streptozocin -> Alzheimers_Disease
}')