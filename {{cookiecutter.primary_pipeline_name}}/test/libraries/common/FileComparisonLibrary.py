"""
FileComparisonLibrary - CSV and JSON file comparison for Robot Framework.

This library provides comparison methods that don't exist in standard libraries:
- CSV comparison with JSON field exclusions
- Key-based row matching
- Detailed difference reporting

Standard operations (file reading, JSON parsing) should use:
- JSONLibrary for JSON operations
- CSVLibrary for CSV operations
- OperatingSystem for file operations

Author: SnapLogic QA Team
"""

import csv
import json
import os
from typing import List, Dict, Any, Optional, Set
from robot.api.deco import keyword
from robot.api import logger


class FileComparisonLibrary:
    """Robot Framework library for file comparison operations."""

    ROBOT_LIBRARY_SCOPE = 'GLOBAL'
    ROBOT_LIBRARY_VERSION = '2.2.0'

    # ==================== NUMERIC NORMALIZATION ====================

    @staticmethod
    def _normalize_numeric_value(value):
        """Normalize a numeric value to its canonical form.

        Converts floats that are whole numbers to ints (e.g., 1250.0 -> 1250)
        so that mathematically equal values compare as identical.

        Args:
            value: Any value (int, float, str, etc.)

        Returns:
            Normalized value: int if the value is a whole number float, otherwise unchanged.
        """
        if isinstance(value, float) and value.is_integer():
            return int(value)
        return value

    @staticmethod
    def _normalize_numeric_string(s: str) -> str:
        """Normalize a string that represents a number.

        If the string is a numeric value like '1250.0', normalize it to '1250'.
        Non-numeric strings are returned unchanged.
        """
        try:
            num = float(s)
            if num.is_integer():
                return str(int(num))
        except (ValueError, TypeError):
            pass
        return s

    def _normalize_json_numerics(self, data):
        """Recursively normalize numeric values in a JSON-like structure.

        Converts float values that are whole numbers to int (e.g., 1250.0 -> 1250).
        This ensures that {\"amount\": 1250.0} and {\"amount\": 1250} compare as equal.
        """
        if isinstance(data, dict):
            return {k: self._normalize_json_numerics(v) for k, v in data.items()}
        elif isinstance(data, list):
            return [self._normalize_json_numerics(item) for item in data]
        elif isinstance(data, float) and data.is_integer():
            return int(data)
        return data

    def _normalize_csv_row(self, row: List[str], normalize_numerics: bool = False) -> List[str]:
        """Normalize all fields in a CSV row for numeric-aware comparison.

        For each field: if it's a plain numeric string, normalize it.
        If it's JSON, parse it, normalize numerics recursively, and re-serialize.

        Only applies normalization when normalize_numerics=True.
        """
        if not normalize_numerics:
            return row
        return [self._normalize_csv_field_for_comparison(field) for field in row]

    def _normalize_csv_field_for_comparison(self, field: str) -> str:
        """Normalize a single CSV field for numeric-aware comparison.

        - Plain numeric strings: '1250.0' -> '1250'
        - JSON fields: recursively normalize all numeric values inside
        - Other strings: returned unchanged
        """
        field = field.strip()

        # Try JSON first
        clean = field
        if clean.startswith('"') and clean.endswith('"'):
            clean = clean[1:-1]

        if (clean.startswith('{') and clean.endswith('}')) or \
           (clean.startswith('[') and clean.endswith(']')):
            try:
                json_str = clean.replace('""', '"')
                data = json.loads(json_str)
                normalized = self._normalize_json_numerics(data)
                return json.dumps(normalized, sort_keys=True)
            except json.JSONDecodeError:
                try:
                    data = json.loads(clean)
                    normalized = self._normalize_json_numerics(data)
                    return json.dumps(normalized, sort_keys=True)
                except json.JSONDecodeError:
                    pass

        # Plain value - try numeric normalization
        return self._normalize_numeric_string(field)

    # ==================== CSV COMPARISON ====================

    @keyword("Compare CSV Files")
    def compare_csv_files(
        self,
        file1_path: str,
        file2_path: str,
        ignore_order: bool = True,
        show_details: bool = True,
        normalize_numerics: bool = False
    ) -> Dict[str, Any]:
        """
        Compare two CSV files and return detailed comparison results.

        Args:
            file1_path: Path to the first CSV file (actual)
            file2_path: Path to the second CSV file (expected)
            ignore_order: Whether to ignore row order (default: True)
            show_details: Whether to log detailed differences (default: True)
            normalize_numerics: Whether to normalize numeric types before comparison
                               (e.g., 1250.0 treated as equal to 1250). Default: False.

        Returns:
            Dictionary with comparison results including status, differences, etc.

        Example:
            | ${result}= | Compare CSV Files | ${actual} | ${expected} |
            | Should Be Equal | ${result}[status] | IDENTICAL |
            |
            | # With numeric normalization (e.g., Snowflake int vs JSON float):
            | ${result}= | Compare CSV Files | ${actual} | ${expected} | normalize_numerics=${TRUE} |
        """
        csv1 = self._read_csv_file(file1_path)
        csv2 = self._read_csv_file(file2_path)

        result = {
            'status': 'UNKNOWN',
            'file1_path': file1_path,
            'file2_path': file2_path,
            'file1_rows': len(csv1),
            'file2_rows': len(csv2),
            'headers_match': False,
            'row_count_match': len(csv1) == len(csv2),
            'differences': [],
            'total_differences': 0
        }

        # Compare headers
        if csv1 and csv2:
            result['headers_match'] = csv1[0] == csv2[0]
            if not result['headers_match']:
                result['differences'].append({
                    'type': 'HEADER_MISMATCH',
                    'file1_header': csv1[0],
                    'file2_header': csv2[0]
                })

        # Compare data
        if ignore_order:
            differences = self._compare_csv_unordered(csv1, csv2, normalize_numerics)
        else:
            differences = self._compare_csv_ordered(csv1, csv2, normalize_numerics=normalize_numerics)

        result['differences'].extend(differences)
        result['total_differences'] = len(result['differences'])
        result['status'] = 'IDENTICAL' if result['total_differences'] == 0 else 'DIFFERENT'

        if show_details:
            self._log_comparison_result(result)

        return result

    @keyword("Compare CSV Files With Exclusions")
    def compare_csv_with_exclusions(
        self,
        file1_path: str,
        file2_path: str,
        exclude_keys: List[str],
        match_key: Optional[str] = None,
        ignore_order: bool = True,
        show_details: bool = True,
        normalize_numerics: bool = False
    ) -> Dict[str, Any]:
        """
        Compare two CSV files while excluding specified JSON keys from comparison.

        Useful when CSV files contain JSON data with dynamic fields like timestamps
        (e.g., SnowflakeConnectorPushTime, created_at, updated_at).

        Args:
            file1_path: Path to the first CSV file (actual output)
            file2_path: Path to the second CSV file (expected output)
            exclude_keys: List of JSON keys to exclude from comparison
            match_key: Optional JSON path to match rows (e.g., 'headers.profile_id')
            ignore_order: Whether to ignore row order (default: True)
            show_details: Whether to show detailed comparison results (default: True)
            normalize_numerics: Whether to normalize numeric types before comparison
                               (e.g., 1250.0 treated as equal to 1250). Default: False.

        Returns:
            Dictionary with comparison results including status (IDENTICAL/DIFFERENT)

        Example:
            | @{exclude}= | Create List | SnowflakeConnectorPushTime | timestamp |
            | ${result}= | Compare CSV Files With Exclusions | ${actual} | ${expected} | ${exclude} |
            | Should Be Equal | ${result}[status] | IDENTICAL |
            |
            | # With numeric normalization:
            | ${result}= | Compare CSV Files With Exclusions | ${actual} | ${expected} | ${exclude} | normalize_numerics=${TRUE} |
        """
        # Read and normalize CSV content
        csv1 = self._read_csv_file(file1_path)
        csv2 = self._read_csv_file(file2_path)

        normalized_csv1 = self._normalize_csv_content(csv1, exclude_keys, normalize_numerics)
        normalized_csv2 = self._normalize_csv_content(csv2, exclude_keys, normalize_numerics)

        result = {
            'status': 'UNKNOWN',
            'file1_path': file1_path,
            'file2_path': file2_path,
            'file1_rows': len(csv1),
            'file2_rows': len(csv2),
            'excluded_keys': exclude_keys,
            'match_key': match_key,
            'headers_match': False,
            'row_count_match': len(csv1) == len(csv2),
            'differences': [],
            'total_differences': 0
        }

        # Compare headers
        if normalized_csv1 and normalized_csv2:
            result['headers_match'] = normalized_csv1[0] == normalized_csv2[0]
            if not result['headers_match']:
                result['differences'].append({
                    'type': 'HEADER_MISMATCH',
                    'file1_header': normalized_csv1[0],
                    'file2_header': normalized_csv2[0]
                })

        # Validate match_key early if provided
        if match_key:
            headers1 = normalized_csv1[0] if normalized_csv1 else []
            headers2 = normalized_csv2[0] if normalized_csv2 else []
            data1 = normalized_csv1[1:] if normalized_csv1 else []
            data2 = normalized_csv2[1:] if normalized_csv2 else []
            lookup1 = self._build_row_lookup(data1, match_key, headers1)
            lookup2 = self._build_row_lookup(data2, match_key, headers2)

            if len(data1) > 0 and len(lookup1) == 0:
                logger.console("")  # Add blank line before error
                raise ValueError(
                    f"match_key '{match_key}' not found in any row. Please check:\n"
                    f"  1. For simple CSV: Use a column name exactly as in header (e.g., 'Name', 'CustomerID')\n"
                    f"  2. For JSON in CSV: Use dot notation (e.g., 'headers.profile_id')\n"
                    f"  3. The key name is spelled correctly (case-sensitive)"
                )
            if len(data2) > 0 and len(lookup2) == 0:
                logger.console("")  # Add blank line before error
                raise ValueError(
                    f"match_key '{match_key}' not found in any row of expected file. Please check:\n"
                    f"  1. For simple CSV: Use a column name exactly as in header (e.g., 'Name', 'CustomerID')\n"
                    f"  2. For JSON in CSV: Use dot notation (e.g., 'headers.profile_id')\n"
                    f"  3. The key name is spelled correctly (case-sensitive)"
                )

        # Compare data using appropriate method
        # Logic matches original Robot Framework implementation:
        # - If match_key is provided: use key-based matching
        # - If match_key is NOT provided and ignore_order=True: use set-based comparison
        # - Otherwise: use positional comparison

        if match_key:
            # Key-based matching - primary comparison method when match_key is provided
            logger.console(f"Using key-based matching with key: {match_key}")
            if not ignore_order:
                logger.console(f"Row order will also be verified (ignore_order=False)")

            differences = self._compare_csv_by_key(
                normalized_csv1, normalized_csv2, match_key, ignore_order, normalize_numerics
            )
            result['differences'].extend(differences)

        else:
            # No match_key - use positional or set-based comparison
            # First do positional comparison to find all differences
            # Pass exclude_keys so row matching can ignore dynamic fields
            differences = self._compare_csv_ordered(
                normalized_csv1, normalized_csv2, exclude_keys, normalize_numerics
            )
            result['differences'].extend(differences)

            # If ignore_order is True, check unordered comparison
            if ignore_order:
                unordered_match = self._compare_csv_sets(
                    normalized_csv1, normalized_csv2, normalize_numerics
                )
                result['unordered_match'] = unordered_match

                # If unordered match is True, clear row content differences since order doesn't matter
                if unordered_match:
                    # Keep only structural differences (row count, header mismatches)
                    structural_differences = [
                        diff for diff in result['differences']
                        if diff['type'] in ('ROW_COUNT_MISMATCH', 'HEADER_MISMATCH')
                    ]
                    result['differences'] = structural_differences
                    logger.console("Rows match when ignoring order - cleared positional differences")

        result['total_differences'] = len(result['differences'])
        result['status'] = 'IDENTICAL' if result['total_differences'] == 0 else 'DIFFERENT'

        if show_details:
            self._log_comparison_result(result)

        return result

    # ==================== JSON COMPARISON ====================

    @keyword("Compare JSON Files")
    def compare_json_files(
        self,
        file1_path: str,
        file2_path: str,
        ignore_order: bool = True,
        show_details: bool = True,
        normalize_numerics: bool = False
    ) -> Dict[str, Any]:
        """
        Compare two JSON files and return detailed comparison results.

        Args:
            file1_path: Path to the first JSON file
            file2_path: Path to the second JSON file
            ignore_order: Whether to ignore array order (default: True)
            show_details: Whether to log detailed differences (default: True)
            normalize_numerics: Whether to normalize numeric types before comparison
                               (e.g., 1250.0 treated as equal to 1250). Default: False.

        Returns:
            Dictionary with comparison results

        Example:
            | ${result}= | Compare JSON Files | ${actual} | ${expected} |
            | Should Be Equal | ${result}[status] | IDENTICAL |
        """
        result = {
            'status': 'UNKNOWN',
            'file1_path': file1_path,
            'file2_path': file2_path,
            'files_match': False,
            'differences': [],
            'total_differences': 0
        }

        try:
            json1 = self._read_json_file(file1_path)
            json2 = self._read_json_file(file2_path)

            if ignore_order:
                files_equal = self._compare_json_ignore_order(json1, json2, normalize_numerics)
            else:
                if normalize_numerics:
                    files_equal = self._normalize_json_numerics(json1) == self._normalize_json_numerics(json2)
                else:
                    files_equal = json1 == json2

            if files_equal:
                result['status'] = 'IDENTICAL'
                result['files_match'] = True
            else:
                result['status'] = 'DIFFERENT'
                result['files_match'] = False
                differences = self._find_json_differences(json1, json2, '', normalize_numerics)
                result['differences'] = differences
                result['total_differences'] = len(differences)

        except json.JSONDecodeError as e:
            result['status'] = 'ERROR'
            result['differences'].append({
                'type': 'PARSE_ERROR',
                'error': str(e)
            })

        if show_details:
            self._log_comparison_result(result)

        return result

    @keyword("Compare JSON Files With Exclusions")
    def compare_json_with_exclusions(
        self,
        file1_path: str,
        file2_path: str,
        exclude_keys: List[str],
        ignore_order: bool = True,
        show_details: bool = True,
        normalize_numerics: bool = False
    ) -> Dict[str, Any]:
        """
        Compare two JSON files while excluding specified keys from comparison.

        Args:
            file1_path: Path to the first JSON file
            file2_path: Path to the second JSON file
            exclude_keys: List of keys to exclude from comparison
            ignore_order: Whether to ignore array order (default: True)
            show_details: Whether to log detailed differences (default: True)
            normalize_numerics: Whether to normalize numeric types before comparison
                               (e.g., 1250.0 treated as equal to 1250). Default: False.

        Returns:
            Dictionary with comparison results
        """
        json1 = self._read_json_file(file1_path)
        json2 = self._read_json_file(file2_path)

        # Remove excluded keys from both JSON structures
        normalized_json1 = self._remove_keys_recursive(json1, exclude_keys)
        normalized_json2 = self._remove_keys_recursive(json2, exclude_keys)

        result = {
            'status': 'UNKNOWN',
            'file1_path': file1_path,
            'file2_path': file2_path,
            'excluded_keys': exclude_keys,
            'files_match': False,
            'differences': [],
            'total_differences': 0
        }

        if ignore_order:
            files_equal = self._compare_json_ignore_order(
                normalized_json1, normalized_json2, normalize_numerics
            )
        else:
            if normalize_numerics:
                files_equal = (self._normalize_json_numerics(normalized_json1) ==
                              self._normalize_json_numerics(normalized_json2))
            else:
                files_equal = normalized_json1 == normalized_json2

        if files_equal:
            result['status'] = 'IDENTICAL'
            result['files_match'] = True
        else:
            result['status'] = 'DIFFERENT'
            result['files_match'] = False
            differences = self._find_json_differences(
                normalized_json1, normalized_json2, '', normalize_numerics
            )
            result['differences'] = differences
            result['total_differences'] = len(differences)

        if show_details:
            self._log_comparison_result(result)

        return result

    # ==================== PRIVATE HELPER METHODS ====================

    def _read_csv_file(self, file_path: str) -> List[List[str]]:
        """Read CSV file and return as list of lists."""
        with open(file_path, 'r', newline='', encoding='utf-8') as f:
            reader = csv.reader(f)
            return [row for row in reader]

    def _read_json_file(self, file_path: str) -> Any:
        """Read JSON file and return parsed data."""
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)

    def _normalize_csv_content(
        self,
        csv_content: List[List[str]],
        exclude_keys: List[str],
        normalize_numerics: bool = False
    ) -> List[List[str]]:
        """Normalize CSV content by removing excluded keys from JSON fields."""
        exclude_keys_lower = {k.lower() for k in exclude_keys}
        return [
            [self._normalize_field(field, exclude_keys_lower, normalize_numerics) for field in row]
            for row in csv_content
        ]

    def _normalize_field(self, field: str, exclude_keys_lower: Set[str],
                         normalize_numerics: bool = False) -> str:
        """Normalize a single field by removing excluded keys if it's JSON.

        When normalize_numerics=True, also normalizes numeric values so that
        1250.0 and 1250 are treated as equal.
        """
        field = field.strip()

        # Remove CSV outer quotes if present
        if field.startswith('"') and field.endswith('"'):
            field = field[1:-1]

        # Check if field looks like JSON
        if not ((field.startswith('{') and field.endswith('}')) or
                (field.startswith('[') and field.endswith(']'))):
            # Not JSON - apply plain numeric normalization only if flag is set
            if normalize_numerics:
                return self._normalize_numeric_string(field)
            return field

        try:
            # Handle CSV-style escaped quotes ("" -> ")
            json_str = field.replace('""', '"')
            data = json.loads(json_str)
            cleaned = self._remove_keys_recursive(data, exclude_keys_lower)
            # Normalize numeric values only if flag is set
            if normalize_numerics:
                cleaned = self._normalize_json_numerics(cleaned)
            # Use consistent JSON serialization with sorted keys
            return json.dumps(cleaned, sort_keys=True)
        except json.JSONDecodeError:
            # Try without the quote replacement
            try:
                data = json.loads(field)
                cleaned = self._remove_keys_recursive(data, exclude_keys_lower)
                if normalize_numerics:
                    cleaned = self._normalize_json_numerics(cleaned)
                return json.dumps(cleaned, sort_keys=True)
            except json.JSONDecodeError:
                return field

    def _remove_keys_recursive(self, data: Any, exclude_keys: Set[str], current_path: str = "") -> Any:
        """Recursively remove keys from nested structures.

        Supports both direct key matching and path-based matching.
        Path format: /key1/key2/key3 or key1.key2.key3
        """
        if isinstance(exclude_keys, list):
            exclude_keys = {k.lower() for k in exclude_keys}

        if isinstance(data, dict):
            result = {}
            for k, v in data.items():
                key_lower = k.lower()
                # Build current path for this key
                new_path = f"{current_path}/{k}" if current_path else f"/{k}"
                new_path_lower = new_path.lower()

                # Check if this key should be excluded:
                # 1. Direct key name match (case-insensitive)
                # 2. Full path match (case-insensitive)
                # 3. Path ending match (for keys like /MARKETING-NOTIFICATIONS/CONTENT)
                should_exclude = (
                    key_lower in exclude_keys or
                    new_path_lower in exclude_keys or
                    any(new_path_lower.endswith(exc_key) for exc_key in exclude_keys if exc_key.startswith('/'))
                )

                if not should_exclude:
                    result[k] = self._remove_keys_recursive(v, exclude_keys, new_path)
            return result
        elif isinstance(data, list):
            return [self._remove_keys_recursive(item, exclude_keys, current_path) for item in data]
        return data

    def _compare_csv_sets(
        self,
        csv1: List[List[str]],
        csv2: List[List[str]],
        normalize_numerics: bool = False
    ) -> bool:
        """Compare CSV content using set-based comparison (ignoring row order).

        This method converts rows to tuples and compares as sets.
        When normalize_numerics=True, uses numeric-aware normalization so
        1250.0 and 1250 are treated as equal.
        Returns True if the sets are equal, False otherwise.
        """
        # Get data rows (skip headers)
        data1 = csv1[1:] if csv1 else []
        data2 = csv2[1:] if csv2 else []

        # Convert rows to tuples for set comparison
        # Normalize each field for numeric-aware comparison when flag is set
        set1 = {tuple(self._normalize_csv_row(row, normalize_numerics)) for row in data1}
        set2 = {tuple(self._normalize_csv_row(row, normalize_numerics)) for row in data2}

        # Debug logging
        logger.info(f"Set comparison - File1 rows: {len(set1)}, File2 rows: {len(set2)}")

        if set1 != set2:
            # Find what's different
            only_in_set1 = set1 - set2
            only_in_set2 = set2 - set1

            if only_in_set1:
                logger.info(f"Rows only in file1: {len(only_in_set1)}")
                for i, row in enumerate(list(only_in_set1)[:2]):  # Log first 2
                    logger.info(f"  File1 row {i}: {str(row)[:500]}")

            if only_in_set2:
                logger.info(f"Rows only in file2: {len(only_in_set2)}")
                for i, row in enumerate(list(only_in_set2)[:2]):  # Log first 2
                    logger.info(f"  File2 row {i}: {str(row)[:500]}")

            # Try to find near-matches for debugging
            if only_in_set1 and only_in_set2:
                sample1 = list(only_in_set1)[0]
                sample2 = list(only_in_set2)[0]
                # Compare field by field
                for idx, (f1, f2) in enumerate(zip(sample1, sample2)):
                    if f1 != f2:
                        logger.info(f"  First difference at field {idx}:")
                        logger.info(f"    File1 field: {f1[:300] if len(f1) > 300 else f1}")
                        logger.info(f"    File2 field: {f2[:300] if len(f2) > 300 else f2}")
                        break

        return set1 == set2

    def _compare_csv_unordered(
        self,
        csv1: List[List[str]],
        csv2: List[List[str]],
        normalize_numerics: bool = False
    ) -> List[Dict[str, Any]]:
        """Compare CSV content ignoring row order.

        When normalize_numerics=True, uses numeric-aware normalization so
        1250.0 and 1250 are treated as equal.
        """
        differences = []

        # Get data rows (skip headers)
        data1 = csv1[1:] if csv1 else []
        data2 = csv2[1:] if csv2 else []

        # Convert to sets of tuples for comparison with optional numeric normalization
        set1 = {tuple(self._normalize_csv_row(row, normalize_numerics)) for row in data1}
        set2 = {tuple(self._normalize_csv_row(row, normalize_numerics)) for row in data2}

        # Find rows only in file1
        for row in set1 - set2:
            differences.append({
                'type': 'ROW_ONLY_IN_FILE1',
                'row_content': list(row)
            })

        # Find rows only in file2
        for row in set2 - set1:
            differences.append({
                'type': 'ROW_ONLY_IN_FILE2',
                'row_content': list(row)
            })

        return differences

    def _compare_csv_ordered(
        self,
        csv1: List[List[str]],
        csv2: List[List[str]],
        exclude_keys: List[str] = None,
        normalize_numerics: bool = False
    ) -> List[Dict[str, Any]]:
        """Compare CSV content in order with detailed field-level differences.

        Also finds matching rows between files to show where each row can be found.
        """
        differences = []
        max_rows = max(len(csv1), len(csv2))

        # Build a lookup of file2 rows for finding matches
        # Key is a normalized string representation of the row (excluding dynamic fields)
        file2_row_lookup = {}
        for idx in range(1, len(csv2)):
            row_key = self._get_row_key_for_matching(csv2[idx], exclude_keys, normalize_numerics)
            if row_key not in file2_row_lookup:
                file2_row_lookup[row_key] = []
            file2_row_lookup[row_key].append(idx)

        for row_index in range(1, max_rows):  # Skip header
            has_row1 = row_index < len(csv1)
            has_row2 = row_index < len(csv2)

            if has_row1 and has_row2:
                # Use numeric-aware comparison when flag is set
                norm_row1 = self._normalize_csv_row(csv1[row_index], normalize_numerics)
                norm_row2 = self._normalize_csv_row(csv2[row_index], normalize_numerics)
                if norm_row1 != norm_row2:
                    diff = {
                        'type': 'ROW_CONTENT_MISMATCH',
                        'row_index': row_index,
                        'file1_row': csv1[row_index],
                        'file2_row': csv2[row_index]
                    }
                    # Get detailed field-level differences for clear output
                    field_diffs = self._compare_row_fields_with_details(
                        csv1[row_index], csv2[row_index], row_index, normalize_numerics
                    )
                    if field_diffs:
                        diff['field_differences'] = field_diffs

                    # Find where this row from file1 exists in file2 (if anywhere)
                    # Row indices start at 1 (header is 0), so use directly as data row number
                    row1_key = self._get_row_key_for_matching(
                        csv1[row_index], exclude_keys, normalize_numerics
                    )
                    if row1_key in file2_row_lookup:
                        matching_rows_in_file2 = file2_row_lookup[row1_key]
                        diff['file1_row_matches_file2_rows'] = matching_rows_in_file2  # Already 1-based data row numbers

                    # Find where this row from file2 exists in file1 (if anywhere)
                    row2_key = self._get_row_key_for_matching(
                        csv2[row_index], exclude_keys, normalize_numerics
                    )
                    file1_matches = []
                    for idx in range(1, len(csv1)):
                        if self._get_row_key_for_matching(
                            csv1[idx], exclude_keys, normalize_numerics
                        ) == row2_key:
                            file1_matches.append(idx)  # idx is already 1-based data row number
                    if file1_matches:
                        diff['file2_row_matches_file1_rows'] = file1_matches

                    differences.append(diff)
            elif has_row1:
                differences.append({
                    'type': 'EXTRA_ROW_IN_FILE1',
                    'row_index': row_index,
                    'row_content': csv1[row_index]
                })
            elif has_row2:
                differences.append({
                    'type': 'EXTRA_ROW_IN_FILE2',
                    'row_index': row_index,
                    'row_content': csv2[row_index]
                })

        return differences

    def _get_row_key_for_matching(self, row: List[str], exclude_keys: List[str] = None,
                                  normalize_numerics: bool = False) -> str:
        """Generate a key for row matching by normalizing JSON content and excluding dynamic fields.

        When normalize_numerics=True, uses numeric-aware normalization so rows with
        1250.0 and 1250 produce the same key.
        """
        if not exclude_keys:
            exclude_keys = []

        normalized_parts = []
        for cell in row:
            try:
                # Try to parse as JSON and remove excluded keys
                data = json.loads(cell)
                if isinstance(data, dict):
                    filtered = {k: v for k, v in data.items() if k not in exclude_keys}
                    if normalize_numerics:
                        filtered = self._normalize_json_numerics(filtered)
                    normalized_parts.append(json.dumps(filtered, sort_keys=True))
                else:
                    if normalize_numerics:
                        data = self._normalize_json_numerics(data)
                    normalized_parts.append(json.dumps(data, sort_keys=True))
            except (json.JSONDecodeError, TypeError):
                if normalize_numerics:
                    normalized_parts.append(self._normalize_numeric_string(cell))
                else:
                    normalized_parts.append(cell)

        return '|||'.join(normalized_parts)

    def _compare_csv_by_key(
        self,
        csv1: List[List[str]],
        csv2: List[List[str]],
        match_key: str,
        ignore_order: bool,
        normalize_numerics: bool = False
    ) -> List[Dict[str, Any]]:
        """Compare CSV rows by matching them using a specific key field."""
        differences = []

        # Get headers and data rows
        headers1 = csv1[0] if csv1 else []
        headers2 = csv2[0] if csv2 else []
        data1 = csv1[1:] if csv1 else []
        data2 = csv2[1:] if csv2 else []

        # Build lookup dictionaries (pass headers for column-based matching)
        lookup1 = self._build_row_lookup(data1, match_key, headers1)
        lookup2 = self._build_row_lookup(data2, match_key, headers2)

        all_keys = set(lookup1.keys()) | set(lookup2.keys())

        for key_value in all_keys:
            in_file1 = key_value in lookup1
            in_file2 = key_value in lookup2

            if in_file1 and in_file2:
                row_info1 = lookup1[key_value]
                row_info2 = lookup2[key_value]

                # Check row order if not ignoring
                if not ignore_order and row_info1['index'] != row_info2['index']:
                    differences.append({
                        'type': 'ROW_ORDER_MISMATCH',
                        'match_key': match_key,
                        'key_value': key_value,
                        'file1_position': row_info1['index'],
                        'file2_position': row_info2['index']
                    })

                # Compare row content with optional numeric-aware comparison
                norm_row1 = self._normalize_csv_row(row_info1['row'], normalize_numerics)
                norm_row2 = self._normalize_csv_row(row_info2['row'], normalize_numerics)
                if norm_row1 != norm_row2:
                    diff = {
                        'type': 'ROW_CONTENT_MISMATCH',
                        'match_key': match_key,
                        'key_value': key_value,
                        'file1_row': row_info1['row'],
                        'file2_row': row_info2['row']
                    }
                    # Get field-level differences
                    field_diffs = self._compare_row_fields_with_details(
                        row_info1['row'], row_info2['row'], row_info1['index'],
                        normalize_numerics
                    )
                    if field_diffs:
                        diff['field_differences'] = field_diffs
                    differences.append(diff)

            elif in_file1:
                differences.append({
                    'type': 'UNMATCHED_ROW_IN_FILE1',
                    'match_key': match_key,
                    'key_value': key_value,
                    'row_content': lookup1[key_value]['row']
                })
            else:
                differences.append({
                    'type': 'UNMATCHED_ROW_IN_FILE2',
                    'match_key': match_key,
                    'key_value': key_value,
                    'row_content': lookup2[key_value]['row']
                })

        return differences

    def _compare_row_fields_with_details(
        self,
        row1: List[str],
        row2: List[str],
        row_index: int,
        normalize_numerics: bool = False
    ) -> List[Dict[str, Any]]:
        """Compare individual fields between two rows and return detailed differences."""
        field_differences = []
        max_fields = max(len(row1), len(row2))

        for field_index in range(max_fields):
            has_field1 = field_index < len(row1)
            has_field2 = field_index < len(row2)

            if has_field1 and has_field2:
                field1 = row1[field_index]
                field2 = row2[field_index]

                # Use numeric-aware comparison when flag is set
                if normalize_numerics:
                    norm_field1 = self._normalize_csv_field_for_comparison(field1)
                    norm_field2 = self._normalize_csv_field_for_comparison(field2)
                else:
                    norm_field1 = field1
                    norm_field2 = field2

                if norm_field1 != norm_field2:
                    diff = {
                        'type': 'FIELD_VALUE_MISMATCH',
                        'row_index': row_index,
                        'field_index': field_index,
                        'file1_value': field1,
                        'file2_value': field2
                    }
                    # Get specific JSON key differences
                    json_diff = self._get_json_field_differences(
                        field1, field2, normalize_numerics
                    )
                    if json_diff:
                        diff['json_key_differences'] = json_diff
                    field_differences.append(diff)
            elif has_field1:
                field_differences.append({
                    'type': 'EXTRA_FIELD_IN_FILE1',
                    'row_index': row_index,
                    'field_index': field_index,
                    'field_value': row1[field_index]
                })
            elif has_field2:
                field_differences.append({
                    'type': 'EXTRA_FIELD_IN_FILE2',
                    'row_index': row_index,
                    'field_index': field_index,
                    'field_value': row2[field_index]
                })

        return field_differences

    def _get_json_field_differences(
        self,
        field1: str,
        field2: str,
        normalize_numerics: bool = False
    ) -> List[Dict[str, Any]]:
        """Compare two JSON fields and return specific key differences."""
        differences = []

        # Clean and check if both are JSON
        clean1 = field1.strip()
        clean2 = field2.strip()

        # Remove CSV outer quotes
        if clean1.startswith('"') and clean1.endswith('"'):
            clean1 = clean1[1:-1]
        if clean2.startswith('"') and clean2.endswith('"'):
            clean2 = clean2[1:-1]

        is_json1 = (clean1.startswith('{') and clean1.endswith('}')) or \
                   (clean1.startswith('[') and clean1.endswith(']'))
        is_json2 = (clean2.startswith('{') and clean2.endswith('}')) or \
                   (clean2.startswith('[') and clean2.endswith(']'))

        if not (is_json1 and is_json2):
            return differences

        try:
            # Parse JSON
            json_str1 = clean1.replace('""', '"')
            json_str2 = clean2.replace('""', '"')
            dict1 = json.loads(json_str1)
            dict2 = json.loads(json_str2)

            # Normalize numeric values before comparison only if flag is set
            if normalize_numerics:
                dict1 = self._normalize_json_numerics(dict1)
                dict2 = self._normalize_json_numerics(dict2)

            # Find nested differences
            differences = self._find_nested_differences(dict1, dict2, '', normalize_numerics)
        except json.JSONDecodeError:
            pass

        return differences

    def _find_nested_differences(
        self,
        obj1: Any,
        obj2: Any,
        path: str,
        normalize_numerics: bool = False
    ) -> List[Dict[str, Any]]:
        """Recursively find differences between two nested structures.

        When normalize_numerics=True, 1250.0 and 1250 are treated as equal.
        """
        differences = []

        # Normalize numeric values before type comparison only if flag is set
        if normalize_numerics:
            norm1 = self._normalize_numeric_value(obj1)
            norm2 = self._normalize_numeric_value(obj2)
        else:
            norm1 = obj1
            norm2 = obj2

        if type(norm1) != type(norm2):
            differences.append({
                'path': path or 'root',
                'type': 'TYPE_MISMATCH',
                'file1_type': type(obj1).__name__,
                'file2_type': type(obj2).__name__,
                'file1_value': obj1,
                'file2_value': obj2
            })
            return differences

        if isinstance(norm1, dict):
            all_keys = set(norm1.keys()) | set(norm2.keys())
            for key in all_keys:
                new_path = f"{path}.{key}" if path else key
                if key in norm1 and key in norm2:
                    differences.extend(
                        self._find_nested_differences(
                            norm1[key], norm2[key], new_path, normalize_numerics
                        )
                    )
                elif key in norm1:
                    differences.append({
                        'path': new_path,
                        'type': 'KEY_ONLY_IN_FILE1',
                        'value': norm1[key]
                    })
                else:
                    differences.append({
                        'path': new_path,
                        'type': 'KEY_ONLY_IN_FILE2',
                        'value': norm2[key]
                    })
        elif isinstance(norm1, list):
            if len(norm1) != len(norm2):
                differences.append({
                    'path': path or 'root',
                    'type': 'ARRAY_LENGTH_MISMATCH',
                    'file1_length': len(norm1),
                    'file2_length': len(norm2)
                })
            for i in range(min(len(norm1), len(norm2))):
                new_path = f"{path}[{i}]" if path else f"[{i}]"
                differences.extend(
                    self._find_nested_differences(
                        norm1[i], norm2[i], new_path, normalize_numerics
                    )
                )
        elif norm1 != norm2:
            differences.append({
                'path': path or 'root',
                'type': 'VALUE_MISMATCH',
                'file1_value': obj1,
                'file2_value': obj2
            })

        return differences

    def _build_row_lookup(
        self,
        rows: List[List[str]],
        match_key: str,
        headers: List[str] = None
    ) -> Dict[str, Dict[str, Any]]:
        """Build a dictionary mapping match_key values to rows and positions.

        Supports both:
        - Simple CSV column names (e.g., 'Name', 'CustomerID')
        - JSON path keys (e.g., 'headers.profile_id')
        """
        lookup = {}
        key_parts = match_key.split('.')

        # Check if match_key is a simple column name (exists in headers)
        column_index = None
        if headers and match_key in headers:
            column_index = headers.index(match_key)
            logger.info(f"Using column-based matching: '{match_key}' at index {column_index}")

        for index, row in enumerate(rows):
            key_value = self._extract_key_from_row(row, key_parts, column_index)
            if key_value is not None:
                lookup[str(key_value)] = {'row': row, 'index': index}

        return lookup

    def _extract_key_from_row(
        self,
        row: List[str],
        key_parts: List[str],
        column_index: int = None
    ) -> Optional[str]:
        """Extract the value of a key from a CSV row.

        If column_index is provided, use direct column access.
        Otherwise, search for JSON field with the key path.
        """
        # If we have a direct column index, use it
        if column_index is not None and column_index < len(row):
            return row[column_index].strip()

        # Otherwise, search for JSON field with the key path
        for field in row:
            value = self._extract_value_from_field(field, key_parts)
            if value is not None:
                return value
        return None

    def _extract_value_from_field(
        self,
        field: str,
        key_parts: List[str]
    ) -> Optional[str]:
        """Extract a value from a JSON field using the key path."""
        field = field.strip()

        # Remove outer quotes
        if field.startswith('"') and field.endswith('"'):
            field = field[1:-1]

        # Only process JSON fields
        if not (field.startswith('{') and field.endswith('}')):
            return None

        try:
            json_str = field.replace('""', '\\"')
            data = json.loads(json_str)

            current = data
            for key in key_parts:
                if not isinstance(current, dict) or key not in current:
                    return None
                current = current[key]

            return str(current)
        except (json.JSONDecodeError, KeyError, TypeError):
            return None

    def _compare_json_ignore_order(self, json1: Any, json2: Any,
                                   normalize_numerics: bool = False) -> bool:
        """Compare two JSON structures ignoring array order.

        When normalize_numerics=True, 1250.0 and 1250 are treated as equal.
        """
        # Normalize numeric values before comparison only if flag is set
        if normalize_numerics:
            norm1 = self._normalize_numeric_value(json1)
            norm2 = self._normalize_numeric_value(json2)
        else:
            norm1 = json1
            norm2 = json2

        if type(norm1) != type(norm2):
            return False

        if isinstance(norm1, dict):
            if set(norm1.keys()) != set(norm2.keys()):
                return False
            return all(
                self._compare_json_ignore_order(norm1[k], norm2[k], normalize_numerics)
                for k in norm1.keys()
            )
        elif isinstance(norm1, list):
            if len(norm1) != len(norm2):
                return False
            try:
                if normalize_numerics:
                    norm1_sorted = sorted(norm1, key=lambda x: json.dumps(
                        self._normalize_json_numerics(x), sort_keys=True))
                    norm2_sorted = sorted(norm2, key=lambda x: json.dumps(
                        self._normalize_json_numerics(x), sort_keys=True))
                else:
                    norm1_sorted = sorted(norm1, key=lambda x: json.dumps(x, sort_keys=True))
                    norm2_sorted = sorted(norm2, key=lambda x: json.dumps(x, sort_keys=True))
                return all(
                    self._compare_json_ignore_order(a, b, normalize_numerics)
                    for a, b in zip(norm1_sorted, norm2_sorted)
                )
            except TypeError:
                return norm1 == norm2
        else:
            return norm1 == norm2

    def _find_json_differences(
        self,
        json1: Any,
        json2: Any,
        path: str,
        normalize_numerics: bool = False
    ) -> List[Dict[str, Any]]:
        """Find all differences between two JSON structures.

        When normalize_numerics=True, 1250.0 and 1250 are treated as equal.
        """
        differences = []

        # Normalize numeric values before comparison only if flag is set
        if normalize_numerics:
            norm1 = self._normalize_numeric_value(json1)
            norm2 = self._normalize_numeric_value(json2)
        else:
            norm1 = json1
            norm2 = json2

        if type(norm1) != type(norm2):
            differences.append({
                'type': 'TYPE_MISMATCH',
                'path': path or 'root',
                'file1_type': type(json1).__name__,
                'file2_type': type(json2).__name__
            })
            return differences

        if isinstance(norm1, dict):
            all_keys = set(norm1.keys()) | set(norm2.keys())
            for key in all_keys:
                new_path = f"{path}.{key}" if path else key
                if key in norm1 and key in norm2:
                    differences.extend(
                        self._find_json_differences(
                            norm1[key], norm2[key], new_path, normalize_numerics
                        )
                    )
                elif key in norm1:
                    differences.append({
                        'type': 'KEY_ONLY_IN_FILE1',
                        'path': new_path,
                        'value': norm1[key]
                    })
                else:
                    differences.append({
                        'type': 'KEY_ONLY_IN_FILE2',
                        'path': new_path,
                        'value': norm2[key]
                    })

        elif isinstance(norm1, list):
            if len(norm1) != len(norm2):
                differences.append({
                    'type': 'ARRAY_LENGTH_MISMATCH',
                    'path': path or 'root',
                    'file1_length': len(norm1),
                    'file2_length': len(norm2)
                })
            for i in range(min(len(norm1), len(norm2))):
                new_path = f"{path}[{i}]" if path else f"[{i}]"
                differences.extend(
                    self._find_json_differences(
                        norm1[i], norm2[i], new_path, normalize_numerics
                    )
                )

        elif norm1 != norm2:
            differences.append({
                'type': 'VALUE_MISMATCH',
                'path': path or 'root',
                'file1_value': json1,
                'file2_value': json2
            })

        return differences

    def _log_comparison_result(self, result: Dict[str, Any]) -> None:
        """Log comparison results to Robot Framework log.

        Matches the original Robot Framework logging format:
        - Shows summary header with match_key, excluded keys, unique differences count
        - Shows FIELD DIFFERENCES section with detailed field-level comparison
        """
        logger.console("")
        logger.console("=" * 50)
        logger.console("CSV COMPARISON SUMMARY")
        logger.console("=" * 50)

        # Display file paths with blank lines for readability
        logger.console("")
        logger.console(f"File 1 (Actual): {result.get('file1_path', 'N/A')}")
        logger.console(f"File 2 (Expected): {result.get('file2_path', 'N/A')}")
        logger.console("")

        logger.console(f"Status: {result['status']}")

        match_key = result.get('match_key')
        if match_key:
            logger.console(f"Match Key: {match_key}")

        if 'excluded_keys' in result:
            logger.console(f"Excluded Keys: {result['excluded_keys']}")

        # Count unique field differences (matching original logic)
        unique_keys = []
        for diff in result.get('differences', []):
            if diff['type'] == 'FIELD_VALUE_MISMATCH':
                if 'json_key_differences' in diff and diff['json_key_differences']:
                    for jd in diff['json_key_differences']:
                        key = jd.get('path', jd.get('key', 'unknown'))
                        if key not in unique_keys:
                            unique_keys.append(key)
                else:
                    key_value = diff.get('key_value', '')
                    field_key = f"{key_value}_Field{diff.get('field_index', 0)}" if key_value else f"Row{diff.get('row_index', 0)}_Field{diff.get('field_index', 0)}"
                    if field_key not in unique_keys:
                        unique_keys.append(field_key)
            elif diff['type'] == 'ROW_CONTENT_MISMATCH':
                # Handle ROW_CONTENT_MISMATCH with field_differences
                if 'field_differences' in diff and diff['field_differences']:
                    for fd in diff['field_differences']:
                        if 'json_key_differences' in fd and fd['json_key_differences']:
                            for jd in fd['json_key_differences']:
                                key = jd.get('path', jd.get('key', 'unknown'))
                                if key not in unique_keys:
                                    unique_keys.append(key)
                        else:
                            # Simple field difference
                            field_key = f"Field{fd.get('field_index', 0)}"
                            if field_key not in unique_keys:
                                unique_keys.append(field_key)
                else:
                    # ROW_CONTENT_MISMATCH without detailed field_differences
                    row_key = f"ROW_MISMATCH_{diff.get('key_value', diff.get('row_index', 'unknown'))}"
                    if row_key not in unique_keys:
                        unique_keys.append(row_key)
            elif diff['type'] == 'ROW_COUNT_MISMATCH':
                if 'ROW_COUNT' not in unique_keys:
                    unique_keys.append('ROW_COUNT')
            elif diff['type'] == 'HEADER_MISMATCH':
                if 'HEADERS' not in unique_keys:
                    unique_keys.append('HEADERS')
            elif diff['type'] == 'UNMATCHED_ROW_IN_FILE1':
                row_key = f"UNMATCHED_ACTUAL_{diff.get('key_value', '')}"
                if row_key not in unique_keys:
                    unique_keys.append(row_key)
            elif diff['type'] == 'UNMATCHED_ROW_IN_FILE2':
                row_key = f"UNMATCHED_EXPECTED_{diff.get('key_value', '')}"
                if row_key not in unique_keys:
                    unique_keys.append(row_key)
            elif diff['type'] == 'ROW_ORDER_MISMATCH':
                order_key = f"ORDER_MISMATCH_{diff.get('key_value', '')}"
                if order_key not in unique_keys:
                    unique_keys.append(order_key)

        unique_count = len(unique_keys)
        logger.console(f"Unique Field Differences: {unique_count}")

        # Log field differences in clean format - show if there are ANY differences
        if result.get('differences'):
            logger.console("")
            logger.console("FIELD DIFFERENCES:")

            logged_keys = []

            for diff in result.get('differences', []):
                if diff['type'] == 'FIELD_VALUE_MISMATCH':
                    has_key_value = 'key_value' in diff
                    has_json_diff = 'json_key_differences' in diff and diff['json_key_differences']

                    if has_json_diff:
                        # JSON field - show nested key differences
                        for jd in diff['json_key_differences']:
                            key = jd.get('path', jd.get('key', 'unknown'))
                            if key in logged_keys:
                                continue
                            logged_keys.append(key)

                            # Log context for key-based matching
                            if has_key_value:
                                logger.console("")
                                logger.console(f"Matched Row ({diff.get('match_key', '')} = {diff['key_value']}):")

                            jd_type = jd.get('type', jd.get('status', 'VALUE_MISMATCH'))

                            if jd_type in ('VALUE_MISMATCH', 'DIFFERENT'):
                                f1_val = str(jd.get('file1_value', ''))
                                f2_val = str(jd.get('file2_value', ''))
                                logger.console(f"Field: {key}")
                                logger.console(f"Actual: {f1_val}")
                                logger.console(f"Expected: {f2_val}")
                            elif jd_type in ('KEY_ONLY_IN_FILE1', 'ONLY_IN_FILE1'):
                                val = jd.get('value', jd.get('file1_value', ''))
                                logger.console(f"Field: {key}")
                                logger.console(f"Actual: {val}")
                                logger.console(f"Expected: (not present)")
                            elif jd_type in ('KEY_ONLY_IN_FILE2', 'ONLY_IN_FILE2'):
                                val = jd.get('value', jd.get('file2_value', ''))
                                logger.console(f"Field: {key}")
                                logger.console(f"Actual: (not present)")
                                logger.console(f"Expected: {val}")
                    else:
                        # Simple field - show row/field difference
                        if has_key_value:
                            field_key = f"{diff['key_value']}_Field{diff.get('field_index', 0)}"
                        else:
                            field_key = f"Row{diff.get('row_index', 0)}_Field{diff.get('field_index', 0)}"

                        if field_key not in logged_keys:
                            logged_keys.append(field_key)
                            logger.console("")
                            if has_key_value:
                                logger.console(f"Matched Row ({diff.get('match_key', '')} = {diff['key_value']}), Field: {diff.get('field_index', 0)}")
                            else:
                                logger.console(f"Row: {diff.get('row_index', 0)}, Field: {diff.get('field_index', 0)}")
                            logger.console(f"Actual: {diff.get('file1_value', '')}")
                            logger.console(f"Expected: {diff.get('file2_value', '')}")

                elif diff['type'] == 'ROW_CONTENT_MISMATCH':
                    # ROW_CONTENT_MISMATCH - handle both with and without field_differences
                    key_value = diff.get('key_value', '')
                    match_key_name = diff.get('match_key', '')
                    # row_index starts at 1 (skips header at index 0), use directly as data row number
                    row_num = diff.get('row_index', 0)

                    # Check for row matching info (shows where this row exists in the other file)
                    file1_matches_file2 = diff.get('file1_row_matches_file2_rows', [])
                    file2_matches_file1 = diff.get('file2_row_matches_file1_rows', [])

                    if 'field_differences' in diff and diff['field_differences']:
                        for fd in diff['field_differences']:
                            has_json_diff = 'json_key_differences' in fd and fd['json_key_differences']

                            if has_json_diff:
                                for jd in fd['json_key_differences']:
                                    key = jd.get('path', jd.get('key', 'unknown'))
                                    # Use row-specific unique key to avoid skipping same field in different rows
                                    unique_key = f"{row_num}::{key}" if not key_value else f"{key_value}::{key}"
                                    if unique_key in logged_keys:
                                        continue
                                    logged_keys.append(unique_key)

                                    logger.console("")
                                    # Show Row# for positional matching, key=value for key-based matching
                                    if key_value and match_key_name:
                                        logger.console(f"Row ({match_key_name} = {key_value}):")
                                    else:
                                        logger.console(f"Row{row_num}:")

                                    jd_type = jd.get('type', 'VALUE_MISMATCH')
                                    if jd_type == 'VALUE_MISMATCH':
                                        logger.console(f"Field: {key}")
                                        logger.console(f"Actual: {jd.get('file1_value', '')}")
                                        logger.console(f"Expected: {jd.get('file2_value', '')}")
                                    elif jd_type == 'KEY_ONLY_IN_FILE1':
                                        logger.console(f"Field: {key}")
                                        logger.console(f"Actual: {jd.get('value', '')}")
                                        logger.console(f"Expected: (not present)")
                                    elif jd_type == 'KEY_ONLY_IN_FILE2':
                                        logger.console(f"Field: {key}")
                                        logger.console(f"Actual: (not present)")
                                        logger.console(f"Expected: {jd.get('value', '')}")
                            else:
                                # Simple field difference without JSON details
                                field_key = f"{row_num}::Field{fd.get('field_index', 0)}" if not key_value else f"{key_value}::Field{fd.get('field_index', 0)}"
                                if field_key not in logged_keys:
                                    logged_keys.append(field_key)
                                    logger.console("")
                                    if key_value and match_key_name:
                                        logger.console(f"Row ({match_key_name} = {key_value}):")
                                    else:
                                        logger.console(f"Row{row_num}:")
                                    logger.console(f"Field: Column {fd.get('field_index', 0)}")
                                    logger.console(f"Actual: {fd.get('file1_value', '')[:200] if fd.get('file1_value') else ''}")
                                    logger.console(f"Expected: {fd.get('file2_value', '')[:200] if fd.get('file2_value') else ''}")

                        # Show row matching info after field differences (once per row)
                        # Only show where the actual row matches in expected file
                        match_key_log = f"ROW_MATCH_INFO_{row_num}"
                        if match_key_log not in logged_keys:
                            logged_keys.append(match_key_log)
                            if file1_matches_file2:
                                logger.console(f"  --- Row Matching Info ---")
                                logger.console(f"  Actual Row [{row_num}] matches Expected Row {file1_matches_file2}")
                    else:
                        # ROW_CONTENT_MISMATCH without field_differences - show row-level diff
                        row_key = f"ROW_MISMATCH_{key_value or row_num}"
                        if row_key not in logged_keys:
                            logged_keys.append(row_key)
                            logger.console("")
                            if key_value and match_key_name:
                                logger.console(f"Row ({match_key_name} = {key_value}):")
                            else:
                                logger.console(f"Row{row_num}:")
                            logger.console(f"Actual: {str(diff.get('file1_row', ''))[:300]}")
                            logger.console(f"Expected: {str(diff.get('file2_row', ''))[:300]}")

                            # Show row matching info - only where actual row matches in expected file
                            if file1_matches_file2:
                                logger.console(f"  --- Row Matching Info ---")
                                logger.console(f"  Actual Row [{row_num}] matches Expected Row {file1_matches_file2}")

                elif diff['type'] == 'ROW_COUNT_MISMATCH':
                    if 'ROW_COUNT' not in logged_keys:
                        logged_keys.append('ROW_COUNT')
                        logger.console("")
                        logger.console("Row Count Mismatch")
                        logger.console(f"Actual: {diff.get('file1_count', '')} rows")
                        logger.console(f"Expected: {diff.get('file2_count', '')} rows")

                elif diff['type'] == 'HEADER_MISMATCH':
                    if 'HEADERS' not in logged_keys:
                        logged_keys.append('HEADERS')
                        logger.console("")
                        logger.console("Header Mismatch")
                        logger.console(f"Actual: {diff.get('file1_header', '')}")
                        logger.console(f"Expected: {diff.get('file2_header', '')}")

                elif diff['type'] == 'UNMATCHED_ROW_IN_FILE1':
                    key_value = diff.get('key_value', 'unknown')
                    row_key = f"UNMATCHED_ACTUAL_{key_value}"
                    if row_key not in logged_keys:
                        logged_keys.append(row_key)
                        logger.console("")
                        logger.console(f"Row only in actual file ({diff.get('match_key', '')} = {key_value})")

                elif diff['type'] == 'UNMATCHED_ROW_IN_FILE2':
                    key_value = diff.get('key_value', 'unknown')
                    row_key = f"UNMATCHED_EXPECTED_{key_value}"
                    if row_key not in logged_keys:
                        logged_keys.append(row_key)
                        logger.console("")
                        logger.console(f"Row only in expected file ({diff.get('match_key', '')} = {key_value})")

                elif diff['type'] == 'ROW_ORDER_MISMATCH':
                    key_value = diff.get('key_value', 'unknown')
                    order_key = f"ORDER_MISMATCH_{key_value}"
                    if order_key not in logged_keys:
                        logged_keys.append(order_key)
                        logger.console("")
                        logger.console(f"Row order mismatch for {diff.get('match_key', '')} = {key_value}")
                        logger.console(f"Actual position: {diff.get('file1_position', '')}")
                        logger.console(f"Expected position: {diff.get('file2_position', '')}")

        logger.console("")
        logger.console("=" * 50)
