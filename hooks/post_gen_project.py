#!/usr/bin/env python
"""
Post-generation hook for cookiecutter template - ENHANCED DEBUG VERSION
This version includes extensive logging to help diagnose cleanup issues.
"""

import os
import json
import glob
import shutil
import difflib
from pathlib import Path
from typing import List, Dict, Tuple


# --- Define valid systems ---
VALID_SYSTEMS = [
    "oracle", "postgres", "mysql", "sqlserver", "db2", "teradata",
    "snowflake", "salesforce", "kafka", "activemq", "s3", "email",
]

# --- System to Docker profile mapping ---
SYSTEM_TO_PROFILE = {
    "oracle": "oracle-dev",
    "postgres": "postgres-dev",
    "mysql": "mysql-dev",
    "sqlserver": "sqlserver-dev",
    "db2": "db2-dev",
    "teradata": "teradata-dev",
    "snowflake": "snowflake-dev",
    "salesforce": "salesforce-mock-start",
    "kafka": "kafka",
    "activemq": "activemq",
    "s3": "minio",
    "email": "email-mock",
}

# --- System to Makefile name mapping ---
SYSTEM_TO_MAKEFILE = {
    "oracle": "Makefile.oracle",
    "postgres": "Makefile.postgres",
    "mysql": "Makefile.mysql",
    "sqlserver": "Makefile.sqlserver",
    "db2": "Makefile.db2",
    "teradata": "Makefile.teradata",
    "snowflake": "Makefile.snowflake",
    "kafka": "Makefile.kafka",
    "activemq": "Makefile.activemq",
    "s3": "Makefile.minio",
    "email": "Makefile.maildev",
    "salesforce": "Makefile.salesforce",
}


# ------------------------------------------------------
# Step 1: Initialize project information
# Retrieves project root directory and name from cookiecutter variables
# ------------------------------------------------------
def initialize_project_info() -> Tuple[Path, str]:
    project_root = Path.cwd()
    project_name = "{{ cookiecutter.project_name }}"

    print("\n🧭 Project Setup Information")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"📁 Project root: {project_root}")
    print(f"📝 Project name: {project_name}")
    print(f"🔧 Current working directory: {os.getcwd()}")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

    return project_root, project_name


# ------------------------------------------------------
# Step 2: Parse included systems from cookiecutter input
# ------------------------------------------------------
# Parses the cookiecutter.included_systems variable into a list.
# If "all" is specified or input is empty, keeps all files and exits.
# Otherwise, returns a list of lowercase, trimmed system names.
# Example: "Oracle, Kafka" → ["oracle", "kafka"]
# ------------------------------------------------------
def get_included_systems() -> List[str]:
    included_systems_raw = """{{ cookiecutter.included_systems }}"""

    included_systems = []
    if included_systems_raw:
        val = included_systems_raw.strip().lower()
        if val and val != "all":
            included_systems = [s.strip().lower() for s in val.split(",") if s.strip()]

    if not included_systems or included_systems_raw.strip().lower() == "all":
        print("✅ No specific systems specified or 'all' selected — keeping all files.")
        for sm_file in Path(".").rglob("system_mappings.json"):
            try:
                sm_file.unlink()
                print("   Removed system_mappings.json")
            except:
                pass
        exit(0)

    print(f"🔧 Configuring project for systems: {', '.join(included_systems)}")
    return included_systems


# ------------------------------------------------------
# Step 3: Validate systems
# ------------------------------------------------------
# Validates that all specified systems are in the VALID_SYSTEMS list.
# Uses fuzzy matching (difflib) to suggest corrections for typos.
# Filters out invalid systems and continues with valid ones only.
# Exits if no valid systems remain after validation.
# ------------------------------------------------------
def validate_systems(included_systems: List[str]) -> List[str]:
    invalid_systems = [s for s in included_systems if s not in VALID_SYSTEMS]
    if invalid_systems:
        print(f"\n⚠️  Error: Unknown systems specified: {invalid_systems}")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        for invalid in invalid_systems:
            suggestions = difflib.get_close_matches(invalid, VALID_SYSTEMS, n=2, cutoff=0.6)
            if suggestions:
                print(f"   '{invalid}' → Did you mean: {', '.join(suggestions)}?")
        print("\n📋 Valid systems are:")
        print(f"   {', '.join(VALID_SYSTEMS)}")
        print("\n💡 Tip: Use 'oracle,kafka' or 'postgres,mysql', or 'all'")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        included_systems = [s for s in included_systems if s in VALID_SYSTEMS]
        if not included_systems:
            print("\n❌ No valid systems specified. Exiting.")
            exit(1)
        else:
            print(f"\n⏩ Continuing with valid systems: {', '.join(included_systems)}")

    return included_systems


# ------------------------------------------------------
# Step 4: Load system mappings
# ------------------------------------------------------
# Loads system_mappings.json which contains glob patterns for cleanup.
# This file maps each system to a list of file patterns to remove.
# If not found, cleanup falls back to directory-based matching only.
# ------------------------------------------------------
def load_system_mappings(project_root: Path) -> Dict:
    system_mappings = {}
    local_mappings = project_root / "system_mappings.json"
    
    print(f"\n🔍 Looking for system_mappings.json at: {local_mappings}")
    
    if local_mappings.exists():
        with open(local_mappings, "r") as f:
            system_mappings = json.load(f)
        print(f"✅ Loaded cleanup patterns from system_mappings.json")
        print(f"   Found {len(system_mappings)} system definitions")
        
        # Show what systems are defined
        print(f"   Systems in mappings: {', '.join(system_mappings.keys())}")
    else:
        print(f"❌ WARNING: system_mappings.json not found at {local_mappings}")
        print("   Skipping pattern-based cleanup")
    
    return system_mappings


# ------------------------------------------------------
# Step 5: Pattern-based cleanup using reversed logic
# Collects files from excluded systems, protects included system files, deletes remainder
# ------------------------------------------------------
def pattern_based_cleanup(system_mappings: Dict, included_systems: List[str]):
    """
    Reversed logic cleanup:
    1. Collect all files from EXCLUDED systems (deletion candidates)
    2. Remove files from INCLUDED systems (protect them)
    3. Delete what remains
    """
    if not system_mappings:
        print("\n⚠️  No system mappings loaded - skipping cleanup")
        return

    print("\n🧹 Starting pattern-based cleanup (Reversed Logic)...")
    print(f"   Systems to KEEP: {', '.join(included_systems)}")
    
    # ═══════════════════════════════════════════════════════════
    # STEP 1: Collect all files from EXCLUDED systems
    # ═══════════════════════════════════════════════════════════
    print("\n📋 STEP 1: Collecting files from EXCLUDED systems...")
    
    files_to_delete = set()  # Use set to avoid duplicates
    excluded_systems = []
    
    for system, path_config in system_mappings.items():
        if system in included_systems:
            continue  # Skip included systems for now
            
        excluded_systems.append(system)
        print(f"   Scanning {system}...")
        
        # Extract all paths from the configuration
        patterns = _extract_patterns_from_config(path_config)
        
        for pattern in patterns:
            matches = glob.glob(pattern, recursive=True)
            for match in matches:
                if Path(match).exists():
                    files_to_delete.add(match)
    
    print(f"   ✓ Found {len(files_to_delete)} files from excluded systems")
    print(f"   Excluded systems: {', '.join(excluded_systems)}")
    
    # ═══════════════════════════════════════════════════════════
    # STEP 2: Remove files from INCLUDED systems (protection)
    # ═══════════════════════════════════════════════════════════
    print("\n🛡️  STEP 2: Protecting files from INCLUDED systems...")
    
    files_to_protect = set()
    
    for system, path_config in system_mappings.items():
        if system not in included_systems:
            continue  # Only process included systems
            
        print(f"   Protecting {system} files...")
        
        # Extract all paths from the configuration
        patterns = _extract_patterns_from_config(path_config)
        
        for pattern in patterns:
            matches = glob.glob(pattern, recursive=True)
            for match in matches:
                if match in files_to_delete:
                    files_to_protect.add(match)
                    files_to_delete.remove(match)
    
    print(f"   ✓ Protected {len(files_to_protect)} files (removed from deletion list)")
    
    if files_to_protect:
        print(f"\n   Protected files (sample):")
        for protected_file in list(files_to_protect)[:5]:
            print(f"      🛡️  {protected_file}")
        if len(files_to_protect) > 5:
            print(f"      ... and {len(files_to_protect) - 5} more")
    
    # ═══════════════════════════════════════════════════════════
    # STEP 3: Delete remaining files
    # ═══════════════════════════════════════════════════════════
    print(f"\n🗑️  STEP 3: Deleting {len(files_to_delete)} remaining files...")
    
    removed_count = 0
    
    for file_path in sorted(files_to_delete):
        match_path = Path(file_path)
        
        if not match_path.exists():
            continue
        
        try:
            if match_path.is_dir():
                shutil.rmtree(match_path, ignore_errors=True)
                if not match_path.exists():
                    print(f"   ✓ Removed directory: {file_path}")
                    removed_count += 1
            elif match_path.is_file():
                match_path.unlink()
                if not match_path.exists():
                    print(f"   ✓ Removed file: {file_path}")
                    removed_count += 1
        except Exception as e:
            print(f"   ❌ Error removing {file_path}: {e}")
    
    print("\n" + "━" * 70)
    print(f"📊 CLEANUP SUMMARY:")
    print(f"   Files from excluded systems: {len(files_to_delete) + len(files_to_protect)}")
    print(f"   Files protected (included): {len(files_to_protect)}")
    print(f"   Files deleted: {removed_count}")
    print("━" * 70)


# ==============================================================================
# Helper Function: Extract File Patterns from System Configuration
# ==============================================================================
# This function parses the new system_mappings.json structure where each
# system endpoint (oracle, postgres, etc.) has a nested dictionary of paths:
#
# Example structure:
# {
#   "oracle": {
#     "docker_path": "docker/oracle/**",
#     "env_path": "env_files/database_accounts/.env.oracle",
#   }
# }
#
# The function flattens this nested structure into a simple list of all
# file patterns, regardless of whether they are single strings or lists.
# ==============================================================================

def _extract_patterns_from_config(path_config: Dict) -> List[str]:
    patterns = []
    
    for key, value in path_config.items():
        if isinstance(value, list):
            # Handle lists like pipeline_paths, env_paths, etc.
            patterns.extend(value)
        elif isinstance(value, str):
            # Handle single strings like docker_path, makefile_path, etc.
            patterns.append(value)
    
    return patterns
# ------------------------------------------------------
# Step 6: Update COMPOSE_PROFILES in Makefile.common
# ------------------------------------------------------
# Builds and updates the COMPOSE_PROFILES variable with selected system profiles.
# Always includes "tools" profile, then adds Docker profiles for each included system.
# Updates the COMPOSE_PROFILES line in makefiles/common_services/Makefile.common.
# Example: If systems = ["oracle", "kafka"], profiles = "tools,oracle-dev,kafka"
# ------------------------------------------------------
def update_compose_profiles(project_root: Path, included_systems: List[str]) -> str:
    print("\n🔧 Updating Docker Compose profiles in Makefile.common...")

    profiles = ["tools"]
    for system in included_systems:
        if system in SYSTEM_TO_PROFILE:
            profiles.append(SYSTEM_TO_PROFILE[system])

    compose_profiles_value = ",".join(profiles)
    print(f"   New COMPOSE_PROFILES: {compose_profiles_value}")

    makefile_common = project_root / "makefiles" / "common_services" / "Makefile.common"
    if makefile_common.exists():
        try:
            with open(makefile_common, "r") as f:
                lines = f.readlines()
            for i, line in enumerate(lines):
                if line.strip().startswith("COMPOSE_PROFILES ?="):
                    lines[i] = f"COMPOSE_PROFILES ?= {compose_profiles_value}\n"
                    print("   ✅ Updated COMPOSE_PROFILES line")
                    break
            with open(makefile_common, "w") as f:
                f.writelines(lines)
        except Exception as e:
            print(f"   ❌ Error updating Makefile.common: {e}")
    else:
        print("   ⚠️  Makefile.common not found")

    return compose_profiles_value


# ------------------------------------------------------
# Step 7:  Updates docker-compose.yml include files
# ------------------------------------------------------
# Filters docker-compose.yml to keep only service includes for selected systems.
# Preserves lines starting with "- docker/" that match included_systems or "groundplex".
# Removes service includes for excluded systems to avoid loading unnecessary containers.
# ------------------------------------------------------
def update_docker_compose(project_root: Path, included_systems: List[str]):
    compose_file = project_root / "docker-compose.yml"
    if not compose_file.exists():
        return
    print("\n🔧 Updating docker-compose.yml...")
    try:
        with open(compose_file, "r") as f:
            lines = f.readlines()
        new_lines, removed = [], 0
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("- docker/"):
                if any(sys in stripped for sys in included_systems) or "groundplex" in stripped:
                    new_lines.append(line)
                else:
                    removed += 1
            else:
                new_lines.append(line)
        with open(compose_file, "w") as f:
            f.writelines(new_lines)
        if removed > 0:
            print(f"   ✓ Removed {removed} service includes")
    except Exception as e:
        print(f"   ⚠️  Error updating docker-compose.yml: {e}")

# ------------------------------------------------------
# Step 8: Update main Makefile includes
# -----------------------------------------------------
# Filters the main Makefile to keep only includes for selected systems.
# Always preserves common service makefiles (common, testing, groundplex, docker, quality).
# Removes makefile includes for excluded systems to avoid referencing non-existent files.
# ------------------------------------------------------
def update_makefile(project_root: Path, included_systems: List[str]):
    makefile_path = project_root / "Makefile"
    if not makefile_path.exists():
        return
    print("\n📝 Updating Makefile...")
    try:
        with open(makefile_path, "r") as f:
            lines = f.readlines()

        new_lines, removed = [], 0
        keep_keywords = [
            "common_services/Makefile.common",
            "common_services/Makefile.testing",
            "common_services/Makefile.groundplex",
            "common_services/Makefile.docker",
            "common_services/Makefile.quality",
        ]

        for line in lines:
            stripped = line.strip()
            if stripped.startswith("include makefiles/"):
                if any(k in stripped for k in keep_keywords) or any(sys in stripped for sys in included_systems):
                    new_lines.append(line)
                else:
                    removed += 1
            else:
                new_lines.append(line)

        with open(makefile_path, "w") as f:
            f.writelines(new_lines)
        if removed > 0:
            print(f"   ✓ Removed {removed} Makefile includes")
    except Exception as e:
        print(f"   ⚠️  Error updating Makefile: {e}")


# ------------------------------------------------------
# Step 9: Remove empty directories
# Recursively removes empty directories from the project.
# Uses bottom-up traversal (topdown=False) to clean nested empty folders.
# Skips the project root directory itself.
# ------------------------------------------------------
def remove_empty_directories(project_root: Path):
    print("\n🗑️  Cleaning up empty directories...")
    removed = 0
    for dirpath, dirnames, filenames in os.walk(project_root, topdown=False):
        dirpath = Path(dirpath)
        if dirpath == project_root:
            continue
        if not dirnames and not filenames:
            try:
                os.rmdir(dirpath)
                print(f"   Removed empty directory: {dirpath}")
                removed += 1
            except Exception as e:
                pass
    if removed > 0:
        print(f"   ✓ Removed {removed} empty directories")


# ------------------------------------------------------
# Step 10: Clean up root-level .env file
# ------------------------------------------------------
def cleanup_root_level_env_file(project_root: Path):
    print("\n🧹 Removing root-level .env file...")
    for env_file in project_root.glob(".env"):
        try:
            env_file.unlink()
            print(f"   ✓ Removed {env_file}")
        except Exception as e:
            print(f"   ⚠️ Could not remove {env_file}: {e}")


# ------------------------------------------------------
# Step 11: Clean up template artifacts
# ------------------------------------------------------
def cleanup_template_artifacts(project_root: Path):
    print("\n🧹 Removing template artifacts...")
    for pattern in ["system_mappings.json", ".cookiecutterignore"]:
        for file_path in project_root.rglob(pattern):
            try:
                file_path.unlink()
                print(f"   ✓ Removed {pattern}")
            except:
                pass

def print_final_summary(project_name: str, included_systems: List[str], compose_profiles_value: str, project_root: Path):
    print("\n" + "=" * 50)
    print("🎉 PROJECT CONFIGURATION COMPLETE!")
    print("=" * 50)
    print(f"📦 Project: {project_name}")
    print(f"🔧 Systems: {', '.join(included_systems)}")
    print(f"🐳 Docker Profiles: {compose_profiles_value}")
    print(f"📁 Location: {project_root}")
    print("\n💡 Next steps:")
    print(f"\n💡 change directory to the newly created project: {project_root}")
    print("   1. make start-services   # Start selected services")
    print('   2. make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True  # Create projectspace, launch groundplex and run Robot tests with the "oracle" tag')
    print('   3. make robot-run-all-tests TAGS="oracle"  # For later executions if you already have project space set up, ignore the argument PROJECT_SPACE_SETUP=True')
    print("\n📚 For more commands and tutorials, visit:")
    print("   https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/Tutorials/03.pipelineExecution_5-step%20quick%20start.md")
    print("=" * 50 + "\n")


# ------------------------------------------------------
# Main
# ------------------------------------------------------
def main():
    project_root, project_name = initialize_project_info()
    included_systems = validate_systems(get_included_systems())
    compose_profiles_value = update_compose_profiles(project_root, included_systems)
    system_mappings = load_system_mappings(project_root)
    pattern_based_cleanup(system_mappings, included_systems)
    update_docker_compose(project_root, included_systems)
    update_makefile(project_root, included_systems)
    remove_empty_directories(project_root)
    # cleanup_root_level_env_file(project_root)
    cleanup_template_artifacts(project_root)
    print_final_summary(project_name, included_systems, compose_profiles_value, project_root)


if __name__ == "__main__":
    main()