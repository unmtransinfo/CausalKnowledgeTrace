# Blocklist Functionality Tests

This directory contains tests for the blocklist functionality in the CausalKnowledgeTrace project.

## Test Files

### 1. test_blocklist.py
Tests YAML configuration loading and validation.

**What it tests:**
- Blocklist CUIs are loaded correctly from `user_input.yaml`
- CUI format validation (C followed by 7 digits)
- No overlap between blocklist and exposure/outcome CUIs

**Run:**
```bash
cd /home/rajesh/CausalKnowledgeTrace
python tests/blocklist_tests/test_blocklist.py
```

### 2. test_blocklist_sql.py
Tests SQL query condition generation.

**What it tests:**
- SQL blocklist condition is generated correctly
- Parameters are in correct format (arrays)
- DatabaseOperations initialization with blocklist

**Run:**
```bash
cd /home/rajesh/CausalKnowledgeTrace
python tests/blocklist_tests/test_blocklist_sql.py
```

### 3. test_blocklist_fix.py
Tests the parameter ordering fix.

**What it tests:**
- Parameters are in correct order: predication → exposure → outcome → blocklist → threshold
- SQL placeholders match parameter positions
- Type checking (arrays vs integers)

**Run:**
```bash
cd /home/rajesh/CausalKnowledgeTrace
python tests/blocklist_tests/test_blocklist_fix.py
```

### 4. test_all_hops_parameter_order.py
Comprehensive test for all hop methods.

**What it tests:**
- `_fetch_first_hop` parameter order
- `_fetch_second_hop` parameter order
- `_fetch_higher_hop` parameter order
- Consistency across all methods

**Run:**
```bash
cd /home/rajesh/CausalKnowledgeTrace
python tests/blocklist_tests/test_all_hops_parameter_order.py
```

### 5. test_ui_loading.R
Tests that blocklist CUIs are correctly loaded and displayed in the Shiny app UI.

**What it tests:**
- YAML config loading
- CUI extraction logic (exposure, outcome, blocklist)
- Blocklist UI value is populated from config
- All CUI fields load correctly

**Run:**
```bash
cd /home/rajesh/CausalKnowledgeTrace
Rscript tests/blocklist_tests/test_ui_loading.R
```

### 6. check_blocklist_cuis.sql
SQL query to check what the blocklisted CUIs represent.

**Usage:**
```bash
psql -h db -p 5433 -U your_user -d causalehr -f tests/blocklist_tests/check_blocklist_cuis.sql
```

## Run All Tests

```bash
cd /home/rajesh/CausalKnowledgeTrace
for test in tests/blocklist_tests/test_*.py; do
    echo "Running $test..."
    python "$test" || exit 1
done
echo "All tests passed!"
```

## Bug That Was Fixed

**Error:**
```
psycopg2.errors.WrongObjectType: op ANY/ALL (array) requires array on right side
LINE 15:               AND cp.subject_cui != ALL(10)
```

**Cause:**
Parameter ordering bug in `_fetch_first_hop` method - threshold was placed before blocklist parameters.

**Fix:**
Changed line 437 in `graph_creation/database_operations.py`:
```python
# BEFORE: ... + [degree_threshold] + blocklist_params
# AFTER:  ... + blocklist_params + [degree_threshold]
```

## Expected Results

All tests should pass with output similar to:
```
✓ All blocklist tests PASSED!
✓ All SQL filtering tests PASSED!
✓ ALL TESTS PASSED - Blocklist parameter ordering is FIXED!
✓ ALL HOP METHODS HAVE CORRECT PARAMETER ORDER!
```

## Documentation

See the following files in the project root for more details:
- `BLOCKLIST_FIX_SUMMARY.md` - Summary of the bug fix
- `BLOCKLIST_VERIFICATION.md` - Complete verification details

