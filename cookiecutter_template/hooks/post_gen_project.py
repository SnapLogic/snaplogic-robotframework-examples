#!/usr/bin/env python
"""
Post-generation hook for cookiecutter template.
Cleans up files and directories for systems not included in the project,
including docker folders, env files, Makefile includes, and test directories.
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
    "oracle",
    "postgres",
    "mysql",
    "sqlserver",
    "db2",
    "teradata",
    "snowflake",
    "salesforce",
    "kafka",
    "activemq",
    "s3",
    "email",
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


# ------------------------------------------------------
# Step 1: Initialize project information
# ------------------------------------------------------
def initialize_project_info() -> Tuple[Path, str]:
    project_root = Path.cwd()
    project_name = "{{ cookiecutter.project_name }}"

    print("\n🧭 Project Setup Information")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"📁 Project root: {project_root}")
    print(f"📝 Project name: {project_name}")
    print(f"👤 Author: {{ cookiecutter.author_name }}")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

    return project_root, project_name


# ------------------------------------------------------
# Step 2: Parse included systems from cookiecutter input
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
                print(f"   Removed system_mappings.json")
            except:
                pass
        exit(0)

    print(f"🔧 Configuring project for systems: {', '.join(included_systems)}")
    return included_systems


# ------------------------------------------------------
# Step 3: Validate systems
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
# Step 4: Update COMPOSE_PROFILES in Makefile.common
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
# Step 5: Load system mappings
# ------------------------------------------------------
def load_system_mappings(project_root: Path) -> Dict:
    system_mappings = {}
    local_mappings = project_root / "system_mappings.json"
    if local_mappings.exists():
        with open(local_mappings, "r") as f:
            system_mappings = json.load(f)
        print("\n📖 Loaded cleanup patterns from system_mappings.json")
    else:
        print("\n⚠️  Warning: system_mappings.json not found - using directory-based cleanup only")
    return system_mappings


# ------------------------------------------------------
# Step 6: Pattern-based cleanup
# ------------------------------------------------------
def pattern_based_cleanup(system_mappings: Dict, included_systems: List[str]):
    if not system_mappings:
        return
    removed_count = 0
    patterns_to_remove = []
    print("\n🧹 Removing files for excluded systems:")
    for system, patterns in system_mappings.items():
        if system not in included_systems:
            patterns_to_remove.extend(patterns)
            print(f"   - {system}")
    for pattern in patterns_to_remove:
        for match_path in glob.glob(pattern, recursive=True):
            path = Path(match_path)
            try:
                if path.exists():
                    if path.is_dir():
                        shutil.rmtree(path, ignore_errors=True)
                    elif path.is_file():
                        path.unlink()
                    removed_count += 1
            except:
                pass
    if removed_count > 0:
        print(f"   ✓ Removed {removed_count} files/directories")


# ------------------------------------------------------
# Step 7: Directory-based cleanup (docker/tests/env/makefiles)
# ------------------------------------------------------
# ------------------------------------------------------
# Helper Function: Remove unmatched directories
# ------------------------------------------------------
def remove_unmatched_dirs(base_path: Path, included_systems: List[str], always_keep: List[str] = None) -> int:
    always_keep = always_keep or []
    if not base_path.exists():
        return 0
    removed_count = 0
    for folder in base_path.iterdir():
        if folder.is_dir():
            folder_name = folder.name.lower()
            if any(sys in folder_name for sys in included_systems) or folder_name in always_keep:
                continue
            try:
                shutil.rmtree(folder, ignore_errors=True)
                removed_count += 1
            except:
                pass
    return removed_count

# ------------------------------------------------------
# Step 7a: Clean up makefiles (file-based filtering)
# ------------------------------------------------------
def cleanup_makefiles(project_root: Path, included_systems: List[str]):
    """
    Clean up makefiles - remove individual Makefile files for excluded systems.
    Keeps all category folders (database_services, messaging_services, mock_services, common_services)
    but removes specific Makefile.* files for systems not in included_systems.
    """
    makefiles_root = project_root / "makefiles"
    if not makefiles_root.exists():
        return
    
    print("\n📝 Cleaning makefiles directory...")
    removed_count = 0
    
    # Define makefile name to system mapping
    makefile_to_system = {
        "makefile.oracle": "oracle",
        "makefile.postgres": "postgres",
        "makefile.mysql": "mysql",
        "makefile.sqlserver": "sqlserver",
        "makefile.db2": "db2",
        "makefile.teradata": "teradata",
        "makefile.snowflake": "snowflake",
        "makefile.kafka": "kafka",
        "makefile.activemq": "activemq",
        "makefile.minio": "s3",
        "makefile.maildev": "email",
        "makefile.salesforce": "salesforce",
    }
    
    # Iterate through all category folders and their files
    for category_folder in makefiles_root.iterdir():
        if category_folder.is_dir() and category_folder.name != "common_services":
            for makefile in category_folder.glob("Makefile.*"):
                makefile_name = makefile.name.lower()
                system = makefile_to_system.get(makefile_name)
                
                # Remove if system not in included systems
                if system and system not in included_systems:
                    try:
                        makefile.unlink()
                        removed_count += 1
                    except:
                        pass
    
    if removed_count > 0:
        print(f"   ✓ Removed {removed_count} Makefile files for excluded systems")

# ------------------------------------------------------
# Step 7: Directory-based cleanup (tests/docker/makefiles/env)
# ------------------------------------------------------
def directory_based_cleanup(project_root: Path, included_systems: List[str]):
    pipeline_tests_dir = project_root / "test" / "suite" / "pipeline_tests"
    if pipeline_tests_dir.exists():
        print("\n📁 Cleaning pipeline_tests directory...")
        count = remove_unmatched_dirs(pipeline_tests_dir, included_systems)
        if count > 0:
            print(f"   ✓ Removed {count} test directories")

    docker_root = project_root / "docker"
    if docker_root.exists():
        print("\n🐳 Cleaning docker directory...")
        count = remove_unmatched_dirs(docker_root, included_systems, always_keep=["groundplex"])
        if count > 0:
            print(f"   ✓ Removed {count} docker directories")

    # Clean up makefiles using the new file-based strategy
    cleanup_makefiles(project_root, included_systems)

    env_root = project_root / "env_files"
    if env_root.exists():
        print("\n📄 Filtering .env files...")
        removed_count = 0
        for env_file in env_root.rglob(".env.*"):
            filename = env_file.name.lower()
            if filename == ".env.ports":
                continue
            if not any(sys in filename for sys in included_systems):
                try:
                    env_file.unlink()
                    removed_count += 1
                except:
                    pass
        if removed_count > 0:
            print(f"   ✓ Removed {removed_count} .env files")


# ------------------------------------------------------
# Step 8a: Update docker-compose.yml service includes
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
# Step 8b: Update main Makefile includes
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
# Step 8: Update configuration files (orchestrator)
# ------------------------------------------------------
def update_configuration_files(project_root: Path, included_systems: List[str]):
    update_docker_compose(project_root, included_systems)
    update_makefile(project_root, included_systems)


# ------------------------------------------------------
# Step 9: Remove empty directories
# ------------------------------------------------------
def remove_empty_directories(project_root: Path):
    print("\n🗑️  Cleaning up empty directories...")
    for dirpath, dirnames, filenames in os.walk(project_root, topdown=False):
        dirpath = Path(dirpath)
        if dirpath == project_root:
            continue
        if not dirnames and not filenames:
            try:
                os.rmdir(dirpath)
            except:
                pass


# ------------------------------------------------------
# Step 10a: Clean up root-level .env file
# ------------------------------------------------------
def cleanup_env_files(project_root: Path):
    """
    Remove the root-level .env file.
    """
    print("\n🧹 Removing root-level .env file...")
    for env_file in project_root.glob(".env"):
        try:
            env_file.unlink()
            print(f"   ✓ Removed {env_file}")
        except Exception as e:
            print(f"   ⚠️ Could not remove {env_file}: {e}")


# ------------------------------------------------------
# Step 10b: Clean up template artifacts
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


# ------------------------------------------------------
# Step 11: Summary
# ------------------------------------------------------
def print_final_summary(project_name: str, included_systems: List[str], compose_profiles_value: str, project_root: Path):
    print("\n" + "=" * 50)
    print("🎉 PROJECT CONFIGURATION COMPLETE!")
    print("=" * 50)
    print(f"📦 Project: {project_name}")
    print(f"🔧 Systems: {', '.join(included_systems)}")
    print(f"🐳 Docker Profiles: {compose_profiles_value}")
    print(f"📁 Location: {project_root}")
    print("\n💡 Next steps:")
    print("   1. cd {project_name}")
    print("   2. make tools-start  # Start selected services")
    print("   3. make robot-run-tests")
    print("=" * 50 + "\n")


# ------------------------------------------------------
# Main Orchestration
# ------------------------------------------------------
def main():
    project_root, project_name = initialize_project_info()
    included_systems = validate_systems(get_included_systems())
    compose_profiles_value = update_compose_profiles(project_root, included_systems)
    system_mappings = load_system_mappings(project_root)
    pattern_based_cleanup(system_mappings, included_systems)
    directory_based_cleanup(project_root, included_systems)
    update_configuration_files(project_root, included_systems)
    remove_empty_directories(project_root)
    cleanup_env_files(project_root)
    cleanup_template_artifacts(project_root)
    print_final_summary(project_name, included_systems, compose_profiles_value, project_root)


if __name__ == "__main__":
    main()