"""
config.py
Central configuration for the Post-CKT Analysis Pipeline (Python version).
Mirrors furtherAnalysis/post_ckt/scripts/config.R
"""

# ============================================
# GRAPH GENERATION PARAMETERS
# ============================================
GRAPH_CONFIG = {
    "default_degree": 2,
    "default_min_pmids": 50,
    "predication_types": ["CAUSES", "STIMULATES", "PREVENTS", "INHIBITS"],
}

# ============================================
# CYCLE ANALYSIS PARAMETERS
# ============================================
CYCLE_CONFIG = {
    "max_cycles_to_save": 50,
    "max_path_length": 10,
    "sample_cycles_to_find": 5,
    "max_cycles_to_enumerate": 1_000_000,
}

# ============================================
# SEMANTIC TYPE ANALYSIS PARAMETERS
# ============================================
SEMANTIC_CONFIG = {
    "cycle_participation_threshold": 25,  # % threshold for problematic semantic types
    "min_nodes_for_problematic": 3,
    "top_n_display": 20,
}

# ============================================
# NODE REMOVAL PARAMETERS
# ============================================
GENERIC_NODES = [
    "Disease",
    "Functional_disorder",
    "Complication",
    "Syndrome",
    "Symptoms",
    "Diagnosis",
    "Obstruction",
    "Physical_findings",
    "Adverse_effects",
]

NODE_REMOVAL_CONFIG = {
    "top_n_nodes_report": 20,
    "graph_viz_threshold": 1000,
    "cycle_subgraph_viz_threshold": 150,
}

# ============================================
# VISUALIZATION PARAMETERS
# ============================================
VIZ_CONFIG = {
    "dpi": 150,
    "default_width": 10,
    "default_height": 8,
    "max_fig_width": 16,
    "max_fig_height": 14,
}

# ============================================
# FILE NAMING CONVENTIONS
# ============================================
FILE_CONFIG = {
    "graph_json_pattern": "{exposure}_to_{outcome}_degree{degree}.json",
    "legacy_dagitty_pattern": "{exposure}_{outcome}_degree_{degree}.R",
}

# ============================================
# STAGE DIRECTORY NAMES
# ============================================
STAGES = {
    "S1_GRAPH": "s1_graph",
    "S2_SEMANTIC": "s2_semantic",
    "S3_CYCLES": "s3_cycles",
    "S4_NODE_REMOVAL": "s4_node_removal",
    "S5_POST_REMOVAL": "s5_post_removal",
    "S7_BIAS": "s7_bias",
    "S8_OTHER_BIAS": "s8_other_bias",
}

