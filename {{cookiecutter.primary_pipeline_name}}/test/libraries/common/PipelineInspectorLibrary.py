"""
PipelineInspectorLibrary - Static analysis of SnapLogic pipeline (.slp) files for Robot Framework.

This library parses .slp pipeline JSON files and validates them against
peer review standards including:
- Snap naming conventions (no default names, no duplicates)
- Pipeline naming conventions (project prefix, z_ for child pipelines)
- Parameter validation (capture enabled, naming prefix)
- Account reference validation (shared folder, expression-based, not hardcoded)
- Pipeline info validation (doc link, notes)

All checks are static (file-based) and require no API calls or running services.

Author: SnapLogic QA Team
"""

import json
import os
import re
from typing import List, Dict, Any, Optional, Tuple
from robot.api.deco import keyword
from robot.api import logger


class PipelineInspectorLibrary:
    """Robot Framework library for SnapLogic pipeline (.slp) static analysis."""

    ROBOT_LIBRARY_SCOPE = 'GLOBAL'
    ROBOT_LIBRARY_VERSION = '1.0.0'

    # ==================== KNOWN DEFAULT SNAP NAMES ====================

    # These are default names assigned by SnapLogic Designer when a snap is
    # first dragged onto the canvas. Developers should rename them to something
    # descriptive of their purpose in the pipeline.
    #
    # This list covers common snap types. For snap types NOT in this list,
    # the library also auto-derives default names from the snap's class_id
    # (see _generate_default_names_from_class_id). This means new/unknown
    # snap types are automatically covered without manual updates.
    KNOWN_DEFAULT_NAMES = {
        # --- Transform snaps ---
        "mapper", "structure", "type converter", "script", "js script",
        # --- Flow/Routing snaps ---
        "filter", "router", "join", "union", "data union", "sort", "merge",
        "split", "copy", "gate", "sequence", "cross", "zip", "unzip",
        "head", "tail", "sample", "group by n", "aggregate",
        "binary router", "data validator",
        # --- Pipeline execution ---
        "pipe execute", "pipeline execute",
        # --- File I/O ---
        "file reader", "file writer",
        # --- JSON ---
        "json parser", "json formatter", "json generator", "json splitter",
        # --- CSV ---
        "csv parser", "csv formatter", "csv generator",
        # --- XML ---
        "xml parser", "xml formatter", "xml generator",
        # --- Binary formats ---
        "avro parser", "avro formatter", "parquet parser", "parquet formatter",
        "fixed width parser", "fixed width formatter", "excel parser",
        "binary to document", "document to binary",
        # --- Database snaps (default names follow "DB - Operation" pattern) ---
        "oracle - select", "oracle - insert", "oracle - execute",
        "oracle - update", "oracle - delete",
        "postgresql - select", "postgresql - insert", "postgresql - execute",
        "postgresql - update", "postgresql - delete",
        "mysql - select", "mysql - insert", "mysql - execute",
        "mysql - update", "mysql - delete",
        "sql server - select", "sql server - insert", "sql server - execute",
        "sql server - update", "sql server - delete",
        "snowflake - select", "snowflake - insert", "snowflake - execute",
        "snowflake - update", "snowflake - delete",
        "snowflake - snowpipe streaming", "snowflake - bulk load",
        "db2 - select", "db2 - insert", "db2 - execute",
        "db2 - update", "db2 - delete",
        "redshift - select", "redshift - insert", "redshift - execute",
        "redshift - update", "redshift - delete",
        "teradata - select", "teradata - insert", "teradata - execute",
        "teradata - update", "teradata - delete",
        "generic jdbc - select", "generic jdbc - insert", "generic jdbc - execute",
        "generic jdbc - update", "generic jdbc - delete",
        # --- Cloud/SaaS snaps ---
        "s3 upload", "s3 download", "s3 delete", "s3 list",
        "salesforce create", "salesforce read", "salesforce update",
        "salesforce delete", "salesforce upsert", "salesforce query",
        "salesforce soql", "salesforce bulk read", "salesforce bulk upsert",
        # --- Messaging snaps ---
        "kafka producer", "kafka consumer",
        "jms consumer", "jms producer",
        "activemq consumer", "activemq producer",
        # --- Email ---
        "email sender",
        # --- REST/HTTP ---
        "rest get", "rest post", "rest put", "rest delete",
        "rest patch", "rest head",
    }

    # Patterns that match numbered defaults like "Mapper1", "Filter 2", "Copy 3",
    # "Oracle - Select 2", "JSON Parser1", etc.
    # This is dynamically built from KNOWN_DEFAULT_NAMES at class init time.
    NUMBERED_DEFAULT_PATTERN = None  # Built in __init__

    def __init__(self):
        """Initialize the library and build dynamic patterns."""
        # Build the numbered default pattern from KNOWN_DEFAULT_NAMES
        # Escape special regex chars in names and join with |
        escaped_names = [re.escape(name) for name in sorted(self.KNOWN_DEFAULT_NAMES, key=len, reverse=True)]
        pattern_str = r'^(' + '|'.join(escaped_names) + r')\s*\d+$'
        self.NUMBERED_DEFAULT_PATTERN = re.compile(pattern_str, re.IGNORECASE)

    # ==================== FILE LOADING ====================

    @keyword("Load Pipeline File")
    def load_pipeline_file(self, file_path: str) -> Dict[str, Any]:
        """Load and parse a SnapLogic pipeline (.slp) JSON file.

        *Arguments:*
        - ``file_path``: Absolute or relative path to the .slp file.

        *Returns:*
        - Parsed pipeline as a dictionary.

        *Raises:*
        - FileNotFoundError if file does not exist.
        - json.JSONDecodeError if file is not valid JSON.

        *Example:*
        | ${pipeline}= | Load Pipeline File | ${CURDIR}/my_pipeline.slp |
        """
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"Pipeline file not found: {file_path}")

        with open(file_path, 'r', encoding='utf-8') as f:
            pipeline = json.load(f)

        snap_count = len(pipeline.get('snap_map', {}))
        param_count = len(
            pipeline.get('property_map', {}).get('settings', {})
            .get('param_table', {}).get('value', [])
        )
        name = (
            pipeline.get('property_map', {}).get('info', {})
            .get('label', {}).get('value', 'UNKNOWN')
        )
        logger.info(f"Loaded pipeline '{name}' with {snap_count} snaps and {param_count} parameters")
        return pipeline

    @keyword("Load All Pipeline Files From Directory")
    def load_all_pipeline_files(self, directory: str) -> List[Dict[str, Any]]:
        """Load all .slp files from a directory.

        *Arguments:*
        - ``directory``: Path to directory containing .slp files.

        *Returns:*
        - List of dicts, each with 'file_path', 'file_name', and 'pipeline' keys.

        *Example:*
        | ${pipelines}= | Load All Pipeline Files From Directory | ${CURDIR}/src/pipelines |
        """
        if not os.path.isdir(directory):
            raise FileNotFoundError(f"Directory not found: {directory}")

        results = []
        for filename in sorted(os.listdir(directory)):
            if filename.endswith('.slp'):
                file_path = os.path.join(directory, filename)
                try:
                    pipeline = self.load_pipeline_file(file_path)
                    results.append({
                        'file_path': file_path,
                        'file_name': filename,
                        'pipeline': pipeline
                    })
                except (json.JSONDecodeError, Exception) as e:
                    logger.warn(f"Failed to load {filename}: {e}")
                    results.append({
                        'file_path': file_path,
                        'file_name': filename,
                        'pipeline': None,
                        'error': str(e)
                    })

        logger.info(f"Loaded {len(results)} pipeline files from {directory}")
        return results

    # ==================== PIPELINE NAME ====================

    @keyword("Get Pipeline Name")
    def get_pipeline_name(self, pipeline: Dict[str, Any]) -> str:
        """Extract the pipeline display name (label).

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary from Load Pipeline File.

        *Returns:*
        - Pipeline name string.

        *Example:*
        | ${name}= | Get Pipeline Name | ${pipeline} |
        """
        return (
            pipeline.get('property_map', {}).get('info', {})
            .get('label', {}).get('value', '')
        ) or ''

    @keyword("Validate Pipeline Naming Convention")
    def validate_pipeline_naming_convention(
        self,
        pipeline: Dict[str, Any],
        project_name: str = '',
        is_child_pipeline: bool = False
    ) -> Dict[str, Any]:
        """Validate pipeline name follows naming conventions.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.
        - ``project_name``: Required project prefix (e.g., 'z_greenlight').
        - ``is_child_pipeline``: If True, enforce 'z_' prefix requirement.

        *Returns:*
        - Dict with 'status' (PASS/FAIL), 'pipeline_name', 'violations'.

        *Example:*
        | ${result}= | Validate Pipeline Naming Convention | ${pipeline} | project_name=z_greenlight | is_child_pipeline=True |
        """
        name = self.get_pipeline_name(pipeline)
        violations = []

        if not name:
            violations.append("Pipeline name is empty")

        if project_name and project_name not in name:
            violations.append(
                f"Pipeline name '{name}' does not contain required project name '{project_name}'"
            )

        if is_child_pipeline and not name.startswith('z_'):
            violations.append(
                f"Child pipeline name '{name}' must start with 'z_'"
            )

        status = 'PASS' if not violations else 'FAIL'
        result = {
            'status': status,
            'pipeline_name': name,
            'violations': violations,
            'total_violations': len(violations)
        }

        self._log_validation_result("Pipeline Naming Convention", result)
        return result

    # ==================== PIPELINE TYPE DETECTION ====================

    @keyword("Detect Pipeline Type")
    def detect_pipeline_type(self, pipeline: Dict[str, Any]) -> Dict[str, Any]:
        """Detect whether a pipeline is a parent, child, or standalone based on its .slp content.

        Detection logic:
        - **Has Pipeline Execute snaps** → calls other pipelines (parent or middle child)
        - **Has pipeline-level input views** → receives data from a parent (child)

        | Has Pipeline Execute | Has Input Views | Type           |
        |----------------------|-----------------|----------------|
        | No                   | No              | standalone     |
        | Yes                  | No              | parent         |
        | No                   | Yes             | child          |
        | Yes                  | Yes             | middle_child   |

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.

        *Returns:*
        - Dict with 'pipeline_type' (parent/child/middle_child/standalone),
          'has_pipeline_execute', 'has_input_views', 'is_parent', 'is_child',
          'pipeline_execute_targets'.

        *Example:*
        | ${type_info}= | Detect Pipeline Type | ${pipeline} |
        | Log | Pipeline is: ${type_info}[pipeline_type] |
        """
        snap_map = pipeline.get('snap_map', {})

        # Check for Pipeline Execute snaps
        has_pipeline_execute = False
        pipeline_execute_targets = []
        for snap_id, snap_data in snap_map.items():
            class_id = snap_data.get('class_id', '')
            if 'pipeexec' in class_id.lower():
                has_pipeline_execute = True
                target = (
                    snap_data.get('property_map', {}).get('settings', {})
                    .get('pipeline', {}).get('value', '')
                )
                if target:
                    pipeline_execute_targets.append(target)

        # Check for pipeline-level input views
        input_views = pipeline.get('property_map', {}).get('input', {})
        has_input_views = bool(input_views)

        # Determine type
        if has_pipeline_execute and not has_input_views:
            pipeline_type = 'parent'
        elif not has_pipeline_execute and has_input_views:
            pipeline_type = 'child'
        elif has_pipeline_execute and has_input_views:
            pipeline_type = 'middle_child'
        else:
            pipeline_type = 'standalone'

        is_parent = pipeline_type in ('parent', 'standalone')
        is_child = pipeline_type in ('child', 'middle_child')

        result = {
            'pipeline_type': pipeline_type,
            'has_pipeline_execute': has_pipeline_execute,
            'has_input_views': has_input_views,
            'is_parent': is_parent,
            'is_child': is_child,
            'pipeline_execute_targets': pipeline_execute_targets
        }

        logger.info(
            f"Pipeline type detected: {pipeline_type} "
            f"(Pipeline Execute: {has_pipeline_execute}, Input Views: {has_input_views})"
        )
        return result

    @keyword("Validate Pipeline Naming With Auto Detection")
    def validate_pipeline_naming_with_auto_detection(
        self,
        pipeline: Dict[str, Any],
        project_name: str = ''
    ) -> Dict[str, Any]:
        """Validate pipeline naming convention with automatic parent/child detection.

        Auto-detects whether the pipeline is a parent or child from the .slp content,
        then applies the appropriate naming checks:
        - **All pipelines**: Check name is not empty, check name contains project name.
        - **Child pipelines (additional)**: Check name starts with 'z_'.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.
        - ``project_name``: Required project name that must appear in the pipeline name (optional).

        *Returns:*
        - Dict with 'status' (PASS/FAIL), 'pipeline_name', 'pipeline_type',
          'detected_type_info', 'violations', 'total_violations'.

        *Example:*
        | ${result}= | Validate Pipeline Naming With Auto Detection | ${pipeline} | project_name=z_greenlight |
        | Should Be Equal | ${result}[status] | PASS |
        """
        name = self.get_pipeline_name(pipeline)
        type_info = self.detect_pipeline_type(pipeline)
        violations = []

        # Check 1: Pipeline name is not empty (all pipelines)
        if not name:
            violations.append("Pipeline name is empty")

        # Check 2: Pipeline name contains project name (all pipelines, if configured)
        if project_name and project_name not in name:
            violations.append(
                f"Pipeline name '{name}' does not contain required project name '{project_name}'"
            )

        # Check 3: Child pipeline must start with z_ (child and middle_child only)
        if type_info['is_child'] and not name.startswith('z_'):
            violations.append(
                f"Child pipeline name '{name}' must start with 'z_' "
                f"(auto-detected as '{type_info['pipeline_type']}' — "
                f"has pipeline-level input views)"
            )

        status = 'PASS' if not violations else 'FAIL'
        result = {
            'status': status,
            'pipeline_name': name,
            'pipeline_type': type_info['pipeline_type'],
            'detected_type_info': type_info,
            'violations': violations,
            'total_violations': len(violations)
        }

        self._log_validation_result("Pipeline Naming (Auto-Detect)", result)
        return result

    # ==================== SNAP NAMES ====================

    @keyword("Get All Snap Names")
    def get_all_snap_names(self, pipeline: Dict[str, Any]) -> List[Dict[str, str]]:
        """Extract all snap names, IDs, and types from a pipeline.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.

        *Returns:*
        - List of dicts with 'id', 'name', 'class_id', 'simple_type' keys.

        *Example:*
        | ${snaps}= | Get All Snap Names | ${pipeline} |
        | Log Many  | @{snaps} |
        """
        snap_map = pipeline.get('snap_map', {})
        snaps = []

        for snap_id, snap_data in snap_map.items():
            class_id = snap_data.get('class_id', '')
            simple_type = self._extract_simple_type(class_id)
            name = (
                snap_data.get('property_map', {}).get('info', {})
                .get('label', {}).get('value', '')
            ) or ''

            snaps.append({
                'id': snap_id,
                'name': name,
                'class_id': class_id,
                'simple_type': simple_type
            })

        return snaps

    @keyword("Validate Snap Naming Standards")
    def validate_snap_naming_standards(
        self,
        pipeline: Dict[str, Any],
        additional_defaults: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """Validate that no snap uses a default or generic name.

        Checks:
        - Snap name is not empty
        - Snap name is not a known default (e.g., "Mapper", "Filter", "Router")
        - Snap name is not a numbered default (e.g., "Mapper1", "Filter 2")
        - Snap name does not exactly match the snap type

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.
        - ``additional_defaults``: Optional list of extra names to flag as defaults.

        *Returns:*
        - Dict with 'status' (PASS/FAIL), 'violations', 'total_snaps', 'total_violations'.

        *Example:*
        | ${result}= | Validate Snap Naming Standards | ${pipeline} |
        | Should Be Equal | ${result}[status] | PASS |
        """
        snaps = self.get_all_snap_names(pipeline)
        violations = []

        extra_defaults = set()
        if additional_defaults:
            extra_defaults = {d.strip().lower() for d in additional_defaults}

        all_defaults = self.KNOWN_DEFAULT_NAMES | extra_defaults

        for snap in snaps:
            name = snap['name']
            name_lower = name.strip().lower()
            simple_type = snap['simple_type']

            if not name.strip():
                violations.append({
                    'snap_id': snap['id'],
                    'snap_name': name,
                    'snap_type': simple_type,
                    'reason': 'Snap name is empty'
                })
                continue

            if name_lower in all_defaults:
                violations.append({
                    'snap_id': snap['id'],
                    'snap_name': name,
                    'snap_type': simple_type,
                    'reason': f"Snap name '{name}' is a known default name"
                })
                continue

            if self.NUMBERED_DEFAULT_PATTERN.match(name_lower):
                violations.append({
                    'snap_id': snap['id'],
                    'snap_name': name,
                    'snap_type': simple_type,
                    'reason': f"Snap name '{name}' appears to be a numbered default"
                })
                continue

            # Check if name matches auto-derived defaults from class_id
            # This catches snap types NOT in the hardcoded KNOWN_DEFAULT_NAMES list
            auto_defaults = self._generate_default_names_from_class_id(snap['class_id'])
            if name_lower in auto_defaults:
                violations.append({
                    'snap_id': snap['id'],
                    'snap_name': name,
                    'snap_type': simple_type,
                    'reason': f"Snap name '{name}' is a default name (auto-detected from snap type)"
                })
                continue

            if name_lower == simple_type.lower():
                violations.append({
                    'snap_id': snap['id'],
                    'snap_name': name,
                    'snap_type': simple_type,
                    'reason': f"Snap name '{name}' matches its type exactly"
                })

        status = 'PASS' if not violations else 'FAIL'
        result = {
            'status': status,
            'violations': violations,
            'total_snaps': len(snaps),
            'total_violations': len(violations)
        }

        self._log_validation_result("Snap Naming Standards", result)
        return result

    @keyword("Validate No Duplicate Snap Names")
    def validate_no_duplicate_snap_names(self, pipeline: Dict[str, Any]) -> Dict[str, Any]:
        """Validate that all snap names in the pipeline are unique.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.

        *Returns:*
        - Dict with 'status' (PASS/FAIL), 'duplicates', 'total_violations'.

        *Example:*
        | ${result}= | Validate No Duplicate Snap Names | ${pipeline} |
        | Should Be Equal | ${result}[status] | PASS |
        """
        snaps = self.get_all_snap_names(pipeline)
        name_counts: Dict[str, List[str]] = {}

        for snap in snaps:
            name = snap['name'].strip()
            if name:
                name_counts.setdefault(name, []).append(snap['id'])

        duplicates = []
        for name, ids in name_counts.items():
            if len(ids) > 1:
                duplicates.append({
                    'snap_name': name,
                    'count': len(ids),
                    'snap_ids': ids
                })

        status = 'PASS' if not duplicates else 'FAIL'
        result = {
            'status': status,
            'duplicates': duplicates,
            'total_violations': len(duplicates)
        }

        self._log_validation_result("Duplicate Snap Names", result)
        return result

    # ==================== PARAMETERS ====================

    @keyword("Get Pipeline Parameters")
    def get_pipeline_parameters(self, pipeline: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Extract all pipeline parameters with their settings.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.

        *Returns:*
        - List of dicts with 'name', 'value', 'capture', 'required', 'data_type', 'description'.

        *Example:*
        | ${params}= | Get Pipeline Parameters | ${pipeline} |
        | Log Many   | @{params} |
        """
        param_table = (
            pipeline.get('property_map', {}).get('settings', {})
            .get('param_table', {}).get('value', [])
        )

        params = []
        for param in param_table:
            params.append({
                'name': param.get('key', {}).get('value', ''),
                'value': param.get('value', {}).get('value', ''),
                'capture': param.get('capture', {}).get('value', False),
                'required': param.get('required', {}).get('value', False),
                'data_type': param.get('data_type', {}).get('value', ''),
                'description': param.get('description', {}).get('value', '')
            })

        return params

    @keyword("Validate Parameters Have Capture Enabled")
    def validate_parameters_have_capture_enabled(
        self, pipeline: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Validate that all pipeline parameters have the Capture checkbox enabled.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.

        *Returns:*
        - Dict with 'status' (PASS/FAIL), 'violations', 'total_params', 'total_violations'.

        *Example:*
        | ${result}= | Validate Parameters Have Capture Enabled | ${pipeline} |
        | Should Be Equal | ${result}[status] | PASS |
        """
        params = self.get_pipeline_parameters(pipeline)
        violations = []

        for param in params:
            if not param['capture']:
                violations.append({
                    'parameter_name': param['name'],
                    'capture_value': param['capture'],
                    'reason': f"Parameter '{param['name']}' does not have Capture enabled"
                })

        status = 'PASS' if not violations else 'FAIL'
        result = {
            'status': status,
            'violations': violations,
            'total_params': len(params),
            'total_violations': len(violations)
        }

        self._log_validation_result("Parameter Capture", result)
        return result

    @keyword("Validate Parameters Have Prefix")
    def validate_parameters_have_prefix(
        self,
        pipeline: Dict[str, Any],
        prefix: str = 'xx',
        is_parent_pipeline: bool = False
    ) -> Dict[str, Any]:
        """Validate that all pipeline parameters start with the required prefix.

        Parent pipelines are exempt from this requirement per peer review standards.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.
        - ``prefix``: Required parameter prefix (default: 'xx').
        - ``is_parent_pipeline``: If True, skip this check (top-layer pipelines are exempt).

        *Returns:*
        - Dict with 'status' (PASS/FAIL/SKIP), 'violations', 'total_params', 'total_violations'.

        *Example:*
        | ${result}= | Validate Parameters Have Prefix | ${pipeline} | prefix=xx | is_parent_pipeline=False |
        """
        if is_parent_pipeline:
            result = {
                'status': 'SKIP',
                'violations': [],
                'total_params': 0,
                'total_violations': 0,
                'message': 'Parent pipelines are exempt from parameter prefix requirement'
            }
            logger.info("SKIP: Parent pipelines are exempt from parameter prefix check")
            return result

        params = self.get_pipeline_parameters(pipeline)
        violations = []

        for param in params:
            name = param['name']
            if name and not name.startswith(prefix):
                violations.append({
                    'parameter_name': name,
                    'expected_prefix': prefix,
                    'reason': f"Parameter '{name}' does not start with '{prefix}'"
                })

        status = 'PASS' if not violations else 'FAIL'
        result = {
            'status': status,
            'violations': violations,
            'total_params': len(params),
            'total_violations': len(violations)
        }

        self._log_validation_result("Parameter Prefix", result)
        return result

    # ==================== ACCOUNT REFERENCES ====================

    @keyword("Get Account References")
    def get_account_references(self, pipeline: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Extract all account references from snaps in the pipeline.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.

        *Returns:*
        - List of dicts with 'snap_id', 'snap_name', 'account_ref', 'is_expression'.

        *Example:*
        | ${accounts}= | Get Account References | ${pipeline} |
        """
        snap_map = pipeline.get('snap_map', {})
        accounts = []

        for snap_id, snap_data in snap_map.items():
            prop_map = snap_data.get('property_map', {})
            account = prop_map.get('account', {})
            account_ref = account.get('account_ref', {})

            ref_value = account_ref.get('value', None)
            is_expression = account_ref.get('expression', False)

            # Skip snaps with no account configuration or empty account ref
            if ref_value is None or ref_value == {} or ref_value == '':
                continue

            snap_name = (
                prop_map.get('info', {}).get('label', {}).get('value', '')
            ) or snap_id

            accounts.append({
                'snap_id': snap_id,
                'snap_name': snap_name,
                'account_ref': ref_value,
                'is_expression': is_expression
            })

        return accounts

    @keyword("Validate Accounts Not Hardcoded")
    def validate_accounts_not_hardcoded(self, pipeline: Dict[str, Any]) -> Dict[str, Any]:
        """Validate that account references use expressions (not hardcoded paths).

        Account references should use pipeline parameters (expression=true) rather
        than hardcoded paths. A hardcoded reference is one where expression=false
        and the value is a string path.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.

        *Returns:*
        - Dict with 'status' (PASS/FAIL), 'violations', 'total_accounts', 'total_violations'.

        *Example:*
        | ${result}= | Validate Accounts Not Hardcoded | ${pipeline} |
        | Should Be Equal | ${result}[status] | PASS |
        """
        accounts = self.get_account_references(pipeline)
        violations = []

        for acct in accounts:
            ref = acct['account_ref']
            is_expr = acct['is_expression']

            # If it's a string value and not an expression, it's hardcoded
            if isinstance(ref, str) and ref and not is_expr:
                violations.append({
                    'snap_name': acct['snap_name'],
                    'snap_id': acct['snap_id'],
                    'account_ref': ref,
                    'is_expression': is_expr,
                    'reason': f"Account ref '{ref}' in snap '{acct['snap_name']}' is hardcoded (not an expression)"
                })

        status = 'PASS' if not violations else 'FAIL'
        result = {
            'status': status,
            'violations': violations,
            'total_accounts': len(accounts),
            'total_violations': len(violations)
        }

        self._log_validation_result("Accounts Not Hardcoded", result)
        return result

    @keyword("Validate Account References Format")
    def validate_account_references_format(
        self,
        pipeline: Dict[str, Any],
        expected_pattern: str = r'\.\./shared/.+'
    ) -> Dict[str, Any]:
        """Validate that account references match the expected path format.

        For expression-based references, checks that the resolved pattern
        would match ../shared/<account_name>.
        For direct string references, checks the value directly.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.
        - ``expected_pattern``: Regex pattern for valid account paths (default: '../shared/*').

        *Returns:*
        - Dict with 'status' (PASS/FAIL), 'violations', 'total_accounts', 'total_violations'.

        *Example:*
        | ${result}= | Validate Account References Format | ${pipeline} |
        """
        accounts = self.get_account_references(pipeline)
        violations = []
        pattern = re.compile(expected_pattern)

        for acct in accounts:
            ref = acct['account_ref']

            if isinstance(ref, str) and ref:
                # For expressions like "_oracle_acct", we check if the parameter
                # default value follows the pattern. For direct strings, check directly.
                if not acct['is_expression']:
                    # Direct reference - must match pattern
                    if not pattern.match(ref):
                        violations.append({
                            'snap_name': acct['snap_name'],
                            'snap_id': acct['snap_id'],
                            'account_ref': ref,
                            'expected_pattern': expected_pattern,
                            'reason': f"Account ref '{ref}' does not match pattern '{expected_pattern}'"
                        })
                # For expression-based references, we check the pipeline parameters
                # to see if the default value follows the pattern
                else:
                    self._check_expression_account_ref(
                        pipeline, acct, ref, pattern, violations
                    )

        status = 'PASS' if not violations else 'FAIL'
        result = {
            'status': status,
            'violations': violations,
            'total_accounts': len(accounts),
            'total_violations': len(violations)
        }

        self._log_validation_result("Account Reference Format", result)
        return result

    # ==================== PIPELINE INFO ====================

    @keyword("Validate Pipeline Info Has Doc Link")
    def validate_pipeline_info_has_doc_link(self, pipeline: Dict[str, Any]) -> Dict[str, Any]:
        """Validate that the pipeline Info section has a Doc Link populated.

        Per peer review standards, new pipelines must have the Original User Story URL
        linked in Pipeline Properties > Info > Doc Link.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.

        *Returns:*
        - Dict with 'status' (PASS/FAIL), 'doc_link', 'message'.

        *Example:*
        | ${result}= | Validate Pipeline Info Has Doc Link | ${pipeline} |
        """
        info = pipeline.get('property_map', {}).get('info', {})
        doc_link = info.get('pipeline_doc_uri', {}).get('value', None)

        if doc_link and str(doc_link).strip():
            status = 'PASS'
            message = f"Doc link is present: {doc_link}"
        else:
            status = 'FAIL'
            message = "Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked."

        result = {
            'status': status,
            'doc_link': doc_link,
            'message': message
        }

        self._log_validation_result("Pipeline Doc Link", result)
        return result

    @keyword("Validate Pipeline Info Has Notes")
    def validate_pipeline_info_has_notes(self, pipeline: Dict[str, Any]) -> Dict[str, Any]:
        """Validate that the pipeline Info section has Notes populated.

        Per peer review standards, if a pipeline was modified for a ticket and the Doc Link
        is already present, the ticket number should be in the Notes section.

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.

        *Returns:*
        - Dict with 'status' (PASS/FAIL), 'notes', 'message'.

        *Example:*
        | ${result}= | Validate Pipeline Info Has Notes | ${pipeline} |
        """
        info = pipeline.get('property_map', {}).get('info', {})
        notes = info.get('notes', {}).get('value', None)

        if notes and str(notes).strip():
            status = 'PASS'
            message = f"Notes field is populated"
        else:
            status = 'FAIL'
            message = "Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes."

        result = {
            'status': status,
            'notes': notes,
            'message': message
        }

        self._log_validation_result("Pipeline Notes", result)
        return result

    # ==================== FULL INSPECTION REPORT ====================

    @keyword("Get Pipeline Inspection Report")
    def get_pipeline_inspection_report(
        self,
        pipeline: Dict[str, Any],
        file_name: str = '',
        project_name: str = '',
        param_prefix: str = 'xx'
    ) -> Dict[str, Any]:
        """Run ALL peer review checks and return a comprehensive report.

        Parent/child detection is automatic based on the pipeline name:
        - Pipeline name starts with 'z_' → child pipeline → enforce z_ prefix + xx parameter prefix
        - Pipeline name does NOT start with 'z_' → parent pipeline → skip z_ check + skip xx prefix

        *Arguments:*
        - ``pipeline``: Parsed pipeline dictionary.
        - ``file_name``: Name of the .slp file (for reporting).
        - ``project_name``: Required project name that must appear in the pipeline name.
        - ``param_prefix``: Required parameter prefix (default: 'xx').

        *Returns:*
        - Dict with overall 'status', individual check results, and summary.

        *Example:*
        | ${report}= | Get Pipeline Inspection Report | ${pipeline} | file_name=oracle2.slp |
        """
        pipeline_name = self.get_pipeline_name(pipeline)

        # Determine parent/child from pipeline name
        is_child_pipeline = pipeline_name.lower().startswith('z_')
        is_parent_pipeline = not is_child_pipeline

        logger.info(
            f"Pipeline '{pipeline_name}' detected as "
            f"{'child' if is_child_pipeline else 'parent/standalone'} "
            f"(name {'starts' if is_child_pipeline else 'does not start'} with 'z_')"
        )

        # Run all checks
        naming_check = self.validate_snap_naming_standards(pipeline)
        duplicate_check = self.validate_no_duplicate_snap_names(pipeline)
        pipeline_naming = self.validate_pipeline_naming_convention(
            pipeline, project_name, is_child_pipeline=False
        )
        capture_check = self.validate_parameters_have_capture_enabled(pipeline)
        prefix_check = self.validate_parameters_have_prefix(
            pipeline, param_prefix, is_parent_pipeline
        )
        hardcoded_check = self.validate_accounts_not_hardcoded(pipeline)
        format_check = self.validate_account_references_format(pipeline)
        doc_link_check = self.validate_pipeline_info_has_doc_link(pipeline)
        notes_check = self.validate_pipeline_info_has_notes(pipeline)

        # Child pipeline naming check — determined by pipeline name
        if is_child_pipeline:
            child_naming_check = {
                'status': 'PASS' if pipeline_name.startswith('z_') else 'FAIL',
                'pipeline_name': pipeline_name,
                'message': f"Child pipeline '{pipeline_name}' must start with 'z_'"
                           if not pipeline_name.startswith('z_') else 'OK'
            }
        else:
            child_naming_check = {
                'status': 'SKIP',
                'pipeline_name': pipeline_name,
                'message': 'Not a child pipeline — z_ prefix check skipped'
            }

        # Aggregate results
        all_checks = {
            'snap_naming': naming_check,
            'duplicate_snap_names': duplicate_check,
            'pipeline_naming': pipeline_naming,
            'child_pipeline_naming': child_naming_check,
            'parameter_capture': capture_check,
            'parameter_prefix': prefix_check,
            'accounts_not_hardcoded': hardcoded_check,
            'account_reference_format': format_check,
            'doc_link': doc_link_check,
            'notes': notes_check
        }

        # Calculate overall status
        failed_checks = [
            name for name, check in all_checks.items()
            if check.get('status') == 'FAIL'
        ]
        passed_checks = [
            name for name, check in all_checks.items()
            if check.get('status') == 'PASS'
        ]
        skipped_checks = [
            name for name, check in all_checks.items()
            if check.get('status') == 'SKIP'
        ]

        overall_status = 'PASS' if not failed_checks else 'FAIL'

        report = {
            'status': overall_status,
            'pipeline_name': pipeline_name,
            'file_name': file_name,
            'checks': all_checks,
            'summary': {
                'total_checks': len(all_checks),
                'passed': len(passed_checks),
                'failed': len(failed_checks),
                'skipped': len(skipped_checks),
                'passed_checks': passed_checks,
                'failed_checks': failed_checks,
                'skipped_checks': skipped_checks
            }
        }

        # Log comprehensive report
        self._log_full_report(report)
        return report

    # ==================== INTERNAL HELPERS ====================

    @staticmethod
    def _extract_simple_type(class_id: str) -> str:
        """Extract human-readable snap type from class_id.

        Examples:
            'com-snaplogic-snaps-transform-datatransform' -> 'datatransform'
            'com-snaplogic-snaps-oracle-insert' -> 'oracle-insert'
            'com-snaplogic-snaps-flow-filter' -> 'filter'
        """
        if not class_id:
            return 'unknown'

        parts = class_id.split('-')
        # Remove common prefixes: com, snaplogic, snaps
        # Keep everything after the category (transform, flow, binary, etc.)
        if len(parts) >= 5:
            # e.g., com-snaplogic-snaps-transform-datatransform -> datatransform
            return '-'.join(parts[4:])
        elif len(parts) >= 4:
            return '-'.join(parts[3:])
        return class_id

    @staticmethod
    def _generate_default_names_from_class_id(class_id: str) -> set:
        """Auto-derive possible default names from a snap's class_id.

        This allows detection of default names for ANY snap type, even ones
        not in the KNOWN_DEFAULT_NAMES list. SnapLogic follows predictable
        naming patterns when assigning default names:

        - 'com-snaplogic-snaps-oracle-insert' -> {"Oracle - Insert", "oracle-insert", "insert"}
        - 'com-snaplogic-snaps-transform-datatransform' -> {"datatransform", "DataTransform"}
        - 'com-snaplogic-snaps-s3-s3upload' -> {"S3 Upload", "s3upload", "S3Upload"}

        Returns a set of possible default name variations (all lowercased).
        """
        if not class_id:
            return set()

        names = set()
        parts = class_id.split('-')

        # Remove 'com-snaplogic-snaps-' prefix
        if len(parts) >= 4 and parts[:3] == ['com', 'snaplogic', 'snaps']:
            category = parts[3]       # e.g., 'oracle', 'transform', 'flow', 's3'
            operation_parts = parts[4:]  # e.g., ['insert'], ['datatransform'], ['s3upload']
            operation = '-'.join(operation_parts) if operation_parts else ''

            # The raw type name: "insert", "datatransform", "s3upload"
            if operation:
                names.add(operation.lower())

            # DB snaps: "Oracle - Insert" pattern
            db_categories = {
                'oracle', 'postgres', 'mysql', 'sqlserver', 'snowflake',
                'db2', 'redshift', 'teradata', 'jdbc', 'bigquery',
                'sybase', 'informix', 'saphana', 'aurora',
            }
            if category.lower() in db_categories and operation:
                # "Oracle - Insert" style
                db_display = {
                    'postgres': 'PostgreSQL', 'sqlserver': 'SQL Server',
                    'jdbc': 'Generic JDBC', 'bigquery': 'BigQuery',
                    'saphana': 'SAP HANA', 'db2': 'DB2',
                }.get(category.lower(), category.capitalize())
                op_display = operation.replace('-', ' ').title()
                names.add(f"{db_display} - {op_display}".lower())

            # SaaS snaps: "Salesforce Create" pattern
            saas_categories = {'salesforce', 'servicenow', 'workday', 'netsuite', 'dynamics'}
            if category.lower() in saas_categories and operation:
                op_display = operation.replace('-', ' ').title()
                names.add(f"{category.capitalize()} {op_display}".lower())

            # Cloud snaps: "S3 Upload" pattern
            cloud_categories = {'s3', 'azure', 'gcs'}
            if category.lower() in cloud_categories and operation:
                # Strip repeated prefix: 's3upload' -> 'upload', 's3download' -> 'download'
                clean_op = operation.lower()
                if clean_op.startswith(category.lower()):
                    clean_op = clean_op[len(category):]
                if clean_op:
                    names.add(f"{category.upper()} {clean_op.title()}".lower())

        return names

    def _check_expression_account_ref(
        self,
        pipeline: Dict[str, Any],
        acct: Dict[str, Any],
        ref_expression: str,
        pattern: re.Pattern,
        violations: List[Dict[str, Any]]
    ):
        """Check if an expression-based account reference resolves to a valid path.

        Looks up the referenced pipeline parameter's default value.
        """
        # Expression refs typically look like "_oracle_acct" which maps
        # to a pipeline parameter. Check the param_table for the default value.
        params = self.get_pipeline_parameters(pipeline)

        # The expression usually references a parameter by name
        # Strip leading underscore used in expressions
        param_name = ref_expression.lstrip('_')

        for param in params:
            if param['name'] == param_name or param['name'] == ref_expression:
                default_value = param.get('value', '')
                if isinstance(default_value, str) and default_value:
                    # Remove surrounding quotes if present
                    clean_value = default_value.strip('"').strip("'")
                    if not pattern.match(clean_value):
                        violations.append({
                            'snap_name': acct['snap_name'],
                            'snap_id': acct['snap_id'],
                            'account_ref': ref_expression,
                            'resolved_default': clean_value,
                            'reason': (
                                f"Account parameter '{param_name}' default value "
                                f"'{clean_value}' does not match expected pattern"
                            )
                        })
                return

        # Parameter not found - log warning but don't fail
        # (parameter might be passed at runtime)
        logger.info(
            f"Account ref expression '{ref_expression}' in snap '{acct['snap_name']}' "
            f"could not be resolved to a pipeline parameter. "
            f"Verify at runtime that it resolves to ../shared/<account>."
        )

    def _log_validation_result(self, check_name: str, result: Dict[str, Any]):
        """Log a validation result with consistent formatting."""
        status = result.get('status', 'UNKNOWN')
        violations = result.get('violations', [])
        message = result.get('message', '')

        if status == 'PASS':
            logger.info(f"  PASS: {check_name}")
        elif status == 'SKIP':
            logger.info(f"  SKIP: {check_name} - {message}")
        else:
            if violations:
                logger.info(f"  FAIL: {check_name} ({len(violations)} violation(s))")
                for v in violations:
                    reason = v.get('reason', str(v)) if isinstance(v, dict) else str(v)
                    logger.info(f"    - {reason}")
            elif message:
                logger.info(f"  FAIL: {check_name} - {message}")
            else:
                logger.info(f"  FAIL: {check_name}")

    def _log_full_report(self, report: Dict[str, Any]):
        """Log a comprehensive peer review report."""
        logger.console("")
        logger.console("=" * 70)
        logger.console(f"  PEER REVIEW REPORT: {report['pipeline_name']}")
        if report['file_name']:
            logger.console(f"  File: {report['file_name']}")
        logger.console("=" * 70)
        logger.console("")

        summary = report['summary']
        logger.console(
            f"  Overall: {report['status']}  |  "
            f"Passed: {summary['passed']}  |  "
            f"Failed: {summary['failed']}  |  "
            f"Skipped: {summary['skipped']}"
        )
        logger.console("-" * 70)

        for check_name, check_result in report['checks'].items():
            status = check_result.get('status', 'UNKNOWN')
            display_name = check_name.replace('_', ' ').title()

            if status == 'PASS':
                logger.console(f"  [PASS] {display_name}")
            elif status == 'SKIP':
                msg = check_result.get('message', '')
                logger.console(f"  [SKIP] {display_name} - {msg}")
            else:
                violations = check_result.get('violations', [])
                count = check_result.get('total_violations', len(violations))
                msg = check_result.get('message', '')
                if violations:
                    logger.console(f"  [FAIL] {display_name} ({count} violation(s))")
                    for v in violations[:5]:  # Show max 5 per check in console
                        reason = v.get('reason', str(v)) if isinstance(v, dict) else str(v)
                        logger.console(f"         - {reason}")
                    if count > 5:
                        logger.console(f"         ... and {count - 5} more")
                elif msg:
                    logger.console(f"  [FAIL] {display_name} - {msg}")
                else:
                    logger.console(f"  [FAIL] {display_name}")

        logger.console("=" * 70)
        logger.console("")
