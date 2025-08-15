#!/usr/bin/env python3
"""
Configuration Module for Epidemiological Analysis

This module provides backward compatibility by importing from the refactored
config_models and database_operations modules.

Author: Scott A. Malec PhD
Date: February 2025
"""

# Import all configuration models and constants
from config_models import (
    VALID_PREDICATION_TYPES,
    validate_predication_types,
    load_yaml_config,
    ExposureOutcomePair,
    create_dynamic_config_from_yaml,
    EXPOSURE_OUTCOME_CONFIGS,
    EXCLUDED_CUIS,
    TimingContext,
    create_db_config,
    validate_arguments
)

# Import database operations
from database_operations import DatabaseOperations
