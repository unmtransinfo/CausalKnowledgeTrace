#!/usr/bin/env python3
"""
Configuration Models and Data Structures for Epidemiological Analysis

This module contains configuration classes, constants, YAML support,
and validation functions for the Markov blanket analysis script.

Author: Scott A. Malec PhD
Date: February 2025
"""

import time
import yaml
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, Set, Tuple, List, Union, Optional
from pathlib import Path

# -------------------------
# YAML CONFIGURATION SUPPORT
# -------------------------

# Common predication types found in SemMedDB
VALID_PREDICATION_TYPES = {
    'CAUSES', 'TREATS', 'PREVENTS', 'INTERACTS_WITH', 'AFFECTS', 'ASSOCIATED_WITH',
    'PREDISPOSES', 'COMPLICATES', 'AUGMENTS', 'DISRUPTS', 'INHIBITS', 'STIMULATES',
    'PRODUCES', 'MANIFESTATION_OF', 'RESULT_OF', 'PROCESS_OF', 'PART_OF', 'ISA',
    'LOCATION_OF', 'ADMINISTERED_TO', 'METHOD_OF', 'USES', 'DIAGNOSES'
}

def validate_predication_types(predication_types: List[str]) -> Tuple[bool, List[str]]:
    """
    Validate predication types against known valid types.

    Args:
        predication_types: List of predication type strings to validate

    Returns:
        Tuple of (is_valid, list_of_invalid_types)
    """
    if not predication_types:
        return False, ["Empty predication types list"]

    invalid_types = []
    for pred_type in predication_types:
        if not isinstance(pred_type, str):
            invalid_types.append(f"Non-string type: {type(pred_type)}")
        elif pred_type.strip() == "":
            invalid_types.append("Empty string")
        elif pred_type.strip().upper() not in VALID_PREDICATION_TYPES:
            invalid_types.append(pred_type.strip())

    return len(invalid_types) == 0, invalid_types

def load_yaml_config(yaml_file_path: str) -> Dict:
    """Load configuration from YAML file and extract threshold (min_pmids)."""
    try:
        with open(yaml_file_path, 'r') as file:
            yaml_config = yaml.safe_load(file)
        
        # Validate required fields
        if 'exposure_cuis' not in yaml_config or 'outcome_cuis' not in yaml_config:
            raise ValueError("YAML file must contain 'exposure_cuis' and 'outcome_cuis' fields")
        
        # Ensure CUIs are lists
        exposure_cuis = yaml_config['exposure_cuis']
        outcome_cuis = yaml_config['outcome_cuis']
        blacklist_cuis = yaml_config.get('blacklist_cuis', [])  # Optional field

        if not isinstance(exposure_cuis, list):
            exposure_cuis = [exposure_cuis]
        if not isinstance(outcome_cuis, list):
            outcome_cuis = [outcome_cuis]
        if not isinstance(blacklist_cuis, list):
            blacklist_cuis = [blacklist_cuis] if blacklist_cuis else []
        
        # Extract threshold from min_pmids, default to 50 if not present
        threshold = yaml_config.get('min_pmids', 50)

        # Extract degree with default and validation - now supports any positive integer
        degree = yaml_config.get('degree', yaml_config.get('k_hops', 3))  # Support both new and old names for backward compatibility
        if not isinstance(degree, int) or degree < 1:
            raise ValueError(f"degree must be a positive integer, got: {degree}")

        # Handle predication_type with backward compatibility and multiple types
        predication_type = yaml_config.get('predication_type') or yaml_config.get('PREDICATION_TYPE', 'CAUSES')

        # Parse predication types - handle both single and comma-separated values
        if isinstance(predication_type, str):
            predication_types = [p.strip() for p in predication_type.split(',')]
        elif isinstance(predication_type, list):
            predication_types = [str(p).strip() for p in predication_type]  # Ensure all elements are strings
        else:
            predication_types = ['CAUSES']  # fallback

        # Validate predication types
        is_valid, invalid_types = validate_predication_types(predication_types)
        if not is_valid:
            print(f"Warning: Invalid predication types found: {invalid_types}")
            print(f"Valid predication types include: {', '.join(sorted(VALID_PREDICATION_TYPES))}")
            # Filter out invalid types and keep only valid ones
            predication_types = [p.strip().upper() for p in predication_types
                               if p.strip().upper() in VALID_PREDICATION_TYPES]
            if not predication_types:
                predication_types = ['CAUSES']  # fallback if all were invalid

        return {
            'exposure_cuis': exposure_cuis,
            'outcome_cuis': outcome_cuis,
            'blacklist_cuis': blacklist_cuis,
            'threshold': threshold,
            'degree': degree,
            'predication_type': predication_type,
            'predication_types': predication_types,  # parsed list for SQL queries
            'full_config': yaml_config  # Store full config for future use
        }
        
    except FileNotFoundError:
        raise ValueError(f"YAML configuration file not found: {yaml_file_path}")
    except yaml.YAMLError as e:
        raise ValueError(f"Error parsing YAML file: {e}")
    except Exception as e:
        raise ValueError(f"Error loading YAML configuration: {e}")

# -------------------------
# CENTRALIZED CONFIGURATION
# -------------------------
@dataclass
class ExposureOutcomePair:
    """Configuration class for exposure-outcome relationships with support for multiple CUIs"""
    name: str  # Name of this exposure-outcome configuration
    exposure_cui: Union[str, List[str]]  # CUI(s) for exposure - can be single string or list
    exposure_name: str  # Clean name for exposure
    outcome_cui: Union[str, List[str]]  # CUI(s) for outcome - can be single string or list
    outcome_name: str  # Clean name for outcome
    description: str  # Description of this relationship
    
    def __post_init__(self):
        """Convert single CUIs to lists for consistent handling"""
        if isinstance(self.exposure_cui, str):
            self.exposure_cui = [self.exposure_cui]
        if isinstance(self.outcome_cui, str):
            self.outcome_cui = [self.outcome_cui]
    
    @property
    def exposure_cui_list(self) -> List[str]:
        """Get exposure CUIs as a list"""
        return self.exposure_cui if isinstance(self.exposure_cui, list) else [self.exposure_cui]
    
    @property
    def outcome_cui_list(self) -> List[str]:
        """Get outcome CUIs as a list"""
        return self.outcome_cui if isinstance(self.outcome_cui, list) else [self.outcome_cui]
    
    @property
    def all_target_cuis(self) -> List[str]:
        """Get all target CUIs (exposure + outcome) as a single list"""
        return self.exposure_cui_list + self.outcome_cui_list

def create_dynamic_config_from_yaml(yaml_file_path: str):
    """Create a dynamic ExposureOutcomePair configuration from YAML file."""
    yaml_data = load_yaml_config(yaml_file_path)

    # Generate a unique config name based on CUIs
    config_name = f"yaml_config_{'_'.join(yaml_data['exposure_cuis'][:2])}_{'_'.join(yaml_data['outcome_cuis'][:2])}"

    # Use exposure_name and outcome_name from YAML if provided, otherwise generate from CUIs
    if 'exposure_name' in yaml_data['full_config'] and yaml_data['full_config']['exposure_name']:
        exposure_name = yaml_data['full_config']['exposure_name']
    else:
        exposure_name = f"Exposure_{'_'.join(yaml_data['exposure_cuis'])}"

    if 'outcome_name' in yaml_data['full_config'] and yaml_data['full_config']['outcome_name']:
        outcome_name = yaml_data['full_config']['outcome_name']
    else:
        outcome_name = f"Outcome_{'_'.join(yaml_data['outcome_cuis'])}"

    description = f"YAML-based configuration with {len(yaml_data['exposure_cuis'])} exposure CUI(s) and {len(yaml_data['outcome_cuis'])} outcome CUI(s), predication types: {', '.join(yaml_data['predication_types'])}"

    return ExposureOutcomePair(
        name=config_name,
        exposure_cui=yaml_data['exposure_cuis'],
        exposure_name=exposure_name,
        outcome_cui=yaml_data['outcome_cuis'],
        outcome_name=outcome_name,
        description=description
    ), yaml_data['threshold'], yaml_data  # Return complete parsed data instead of just full_config

# Define available exposure-outcome configurations
EXPOSURE_OUTCOME_CONFIGS = {
    "depression_alzheimers": ExposureOutcomePair(
        name="depression_alzheimers",
        exposure_cui="C0011570",
        exposure_name="Depression",
        outcome_cui="C0002395", 
        outcome_name="Alzheimers_Disease",
        description="Investigating the relationship between depression and Alzheimer's disease"
    ),
    "hypertension_alzheimers": ExposureOutcomePair(
        name="hypertension_alzheimers",
        exposure_cui="C0020538",
        exposure_name="Hypertension",
        outcome_cui="C0002395",
        outcome_name="Alzheimers_Disease",
        description="Investigating the relationship between hypertension and Alzheimer's disease"
    ),
    "diabetes_alzheimers": ExposureOutcomePair(
        name="diabetes_alzheimers",
        exposure_cui=["C0011849", "C0011860"],  # Multiple diabetes CUIs
        exposure_name="Diabetes_Mellitus",
        outcome_cui="C0002395",
        outcome_name="Alzheimers_Disease",
        description="Investigating the relationship between diabetes mellitus and Alzheimer's disease"
    ),
    "smoking_cancer": ExposureOutcomePair(
        name="smoking_cancer",
        exposure_cui="C0037369",
        exposure_name="Smoking",
        outcome_cui=["C0006826", "C0024121"],  # Multiple cancer CUIs
        outcome_name="Cancer",
        description="Investigating the relationship between smoking and cancer"
    ),
    "cardiovascular_dementia": ExposureOutcomePair(
        name="cardiovascular_dementia", 
        exposure_cui=["C0020538", "C0003507", "C0018801"],  # Hypertension, Arrhythmia, Heart Failure
        exposure_name="Cardiovascular_Disease",
        outcome_cui=["C0002395", "C0011265"],  # Alzheimer's, Dementia
        outcome_name="Dementia",
        description="Investigating the relationship between cardiovascular diseases and dementia"
    )
}

# Define excluded CUIs
EXCLUDED_CUIS = (
    'C0001687', 'C0002526', 'C0003043', 'C0003062', 'C0005515', 'C0009566', 'C0012634',
    'C0013227', 'C0021521', 'C0021948', 'C0027361', 'C0027362', 'C0027363', 'C0028622',
    'C0029224', 'C0029235', 'C0030705', 'C0039082', 'C0039796', 'C0087111', 'C0159028',
    'C0178310', 'C0178341', 'C0178353', 'C0178355', 'C0178359', 'C0243192', 'C0422820',
    'C0424450', 'C0436606', 'C0442826', 'C0476466', 'C0478681', 'C0478682', 'C0480773',
    'C0481349', 'C0481370', 'C0557587', 'C0565657', 'C0580210', 'C0580211', 'C0589603',
    'C0596048', 'C0596090', 'C0597010', 'C0597237', 'C0597240', 'C0677042', 'C0687732',
    'C1257890', 'C1258127', 'C1318101', 'C1457887', 'C1609432', 'C0007634', 'C0020114',
    'C0237401', 'C0011900', 'C1273869', 'C0449851', 'C0277785', 'C0184661', 'C1273870',
    'C0185125', 'C0879626', 'C0004927', 'C0936012', 'C0311392', 'C0597198', 'C0018684',
    'C0042567', 'C0029921', 'C0683971', 'C0016163', 'C0024660', 'C0687133', 'C0037080',
    'C0680022', 'C1185740', 'C0871261', 'C0544461', 'C1260954', 'C0877248', 'C0242485',
    'C0205147', 'C0486805', 'C0005839', 'C0021562', 'C0205148', 'C0031843', 'C0040223',
    'C0205145', 'C0205400', 'C0086388', 'C0014406', 'C0520510', 'C0035168', 'C0029237',
    'C0277784', 'C0001779', 'C0542559', 'C0035647', 'C0025664', 'C0700287', 'C0678587',
    'C0205099', 'C0205146', 'C0237753', 'C0441800', 'C0449719', 'C0348026', 'C0008902',
    'C0586173', 'C0332479', 'C0807955', 'C0559546', 'C0031845', 'C0678594', 'C0439792',
    'C0557854', 'C1522240', 'C1527144', 'C0449234', 'C0542341', 'C0079809', 'C0205094',
    'C0037455', 'C0025118', 'C0441471', 'C0441987', 'C0439534', 'C0392360', 'C0456603',
    'C0699733', 'C0036397', 'C0725066', 'C0496675', 'C0282354', 'C0015127', 'C1273937',
    'C1368999', 'C0442804', 'C0449286', 'C0205082', 'C0814472', 'C1551338', 'C0599883',
    'C0450429', 'C1299582', 'C0336791', 'C0443177', 'C0025080', 'C1372798', 'C0028811',
    'C0205246', 'C0449445', 'C0332185', 'C0332307', 'C0443228', 'C1516635', 'C0376636',
    'C0221423', 'C0037778', 'C0199168', 'C0008949', 'C0014442', 'C0456387', 'C1265611',
    'C0243113', 'C0549177', 'C0229962', 'C0600686', 'C1254351', 'C0243095', 'C1444647',
    'C0033684', 'C0338067', 'C0441712', 'C0679607', 'C0808233', 'C1373236', 'C0243082',
    'C1306673', 'C1524062', 'C0002085', 'C0243071', 'C0238767', 'C0005508', 'C0392747',
    'C0008633', 'C0205195', 'C0205198', 'C0456205', 'C0521116', 'C0011155', 'C1527240',
    'C1527148', 'C0743223', 'C0178602', 'C1446466', 'C0013879', 'C0015295', 'C1521761',
    'C1522492', 'C0017337', 'C0017428', 'C0017431', 'C0079411', 'C0018591', 'C0019932',
    'C0021149', 'C0233077', 'C0021920', 'C0022173', 'C1517945', 'C0680220', 'C0870883',
    'C0567416', 'C0596988', 'C0243132', 'C0029016', 'C1550456', 'C0243123', 'C0030956',
    'C0851347', 'C0031328', 'C0031327', 'C0031437', 'C1514468', 'C0033268', 'C0449258',
    'C0871161', 'C1521828', 'C0443286', 'C1547039', 'C1514873', 'C0035668', 'C0439793',
    'C0205171', 'C0449438', 'C1547045', 'C0449913', 'C0042153', 'C0205419', 'C1441526',
    'C1140999', 'C0679670', 'C0431085', 'C1185625', 'C1552130', 'C1553702', 'C1547020',
    'C0242114', 'C0439165', 'C0679646', 'C0599755', 'C0681850'
)

class TimingContext:
    """Context manager for timing code execution"""
    def __init__(self, step_name: str, timing_dict: Dict):
        self.step_name = step_name
        self.timing_dict = timing_dict

    def __enter__(self):
        self.start_time = time.time()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        duration = time.time() - self.start_time
        self.timing_dict[self.step_name] = {
            "duration": duration,
            "timestamp": datetime.now().isoformat()
        }

def create_db_config(host: str, port: int, dbname: str, user: str, password: str, schema: str = None) -> Dict[str, str]:
    """Create database configuration dictionary."""
    config = {
        "host": host,
        "port": str(port),
        "dbname": dbname,
        "user": user,
        "password": password
    }
    if schema:
        config["options"] = f"-c search_path={schema}"
    return config

def validate_arguments(args):
    """Validate command line arguments."""
    # Validate threshold (only if not using YAML config)
    if not hasattr(args, 'yaml_config') or args.yaml_config is None:
        if args.threshold < 1:
            raise ValueError("Threshold must be >= 1")

    # Validate output directory
    try:
        output_path = Path(args.output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        raise ValueError(f"Cannot create output directory '{args.output_dir}': {e}")

    # Validate YAML file if provided
    if hasattr(args, 'yaml_config') and args.yaml_config is not None:
        if not Path(args.yaml_config).exists():
            raise ValueError(f"YAML configuration file not found: {args.yaml_config}")
        try:
            load_yaml_config(args.yaml_config)
        except Exception as e:
            raise ValueError(f"Invalid YAML configuration: {e}")
