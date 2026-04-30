from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SkillDef:
    """Metadata for a single rf-forge skill."""

    name: str
    description: str
    tools: list[str]
    positional_args: list[str]
    cot_instructions: str = ""

    def format_prompt(self, args: dict[str, str]) -> str:
        """Build structured prompt sent to the agent.

        Combines 3 prompting patterns:
        - Prompt Template (Lesson 03): key-value format with placeholders
        - Chain-of-Thought (Lesson 05): step-by-step reasoning instructions
        - Few-Shot examples live in SKILL.md (Lesson 04), not here

        Uses key-value format rather than space-separated positional args,
        since skills may take long freeform text.
        """
        lines = [f"/{self.name}"]
        for arg_name in self.positional_args:
            lines.append(f"{arg_name}: {args[arg_name]}")

        # Chain-of-Thought: add step-by-step reasoning instructions
        if self.cot_instructions:
            lines.append("")
            lines.append(self.cot_instructions)

        return "\n".join(lines)


# All utility skills share the same tools and args pattern
_UTILITY_TOOLS = [
    "Read", "Glob", "Grep", "Task", "TodoWrite",
    "Write", "Edit", "Bash",
]

_UTILITY_ARGS = ["instruction", "codebase_path"]


SKILLS: dict[str, SkillDef] = {
    "create-account": SkillDef(
        name="create-account",
        description=(
            "Generate Robot Framework test cases for SnapLogic account creation. "
            "Creates payload JSON, env file, .robot test case, and README. "
            "Supports Oracle, PostgreSQL, MySQL, SQL Server, Snowflake, Kafka, S3, "
            "and custom account types."
        ),
        tools=_UTILITY_TOOLS,
        positional_args=_UTILITY_ARGS,
        cot_instructions=(
            "Think step by step before generating any files:\n"
            "1. First, read the codebase to understand the existing project structure\n"
            "2. Check which of the 4 required files already exist (payload, env, .robot, README)\n"
            "3. For existing files, read their content to understand current patterns\n"
            "4. Only create files that are missing — do NOT overwrite existing correct files\n"
            "5. Follow the exact naming conventions used in existing account types"
        ),
    ),
    "import-pipeline": SkillDef(
        name="import-pipeline",
        description=(
            "Generate Robot Framework test cases for importing SnapLogic pipelines. "
            "Creates .robot test files that import .slp pipeline files into a "
            "SnapLogic project space."
        ),
        tools=_UTILITY_TOOLS,
        positional_args=_UTILITY_ARGS,
        cot_instructions=(
            "Think step by step before generating any files:\n"
            "1. First, check what .slp pipeline files exist in src/pipelines/\n"
            "2. Read existing pipeline import tests to understand the project's patterns\n"
            "3. Identify the pipeline name, task names, and account references\n"
            "4. Generate the .robot file following existing conventions"
        ),
    ),
    "upload-file": SkillDef(
        name="upload-file",
        description=(
            "Generate Robot Framework test cases for uploading files to SnapLogic SLDB. "
            "Supports JSON, CSV, expression libraries, pipelines, and JAR files."
        ),
        tools=_UTILITY_TOOLS,
        positional_args=_UTILITY_ARGS,
        cot_instructions=(
            "Think step by step before generating any files:\n"
            "1. First, identify what files need to be uploaded and their types\n"
            "2. Check existing upload tests to understand the project's upload patterns\n"
            "3. Determine the correct destination path based on file type\n"
            "4. Generate the .robot file using the correct upload keyword and protocol"
        ),
    ),
    "create-triggered-task": SkillDef(
        name="create-triggered-task",
        description=(
            "Generate Robot Framework test cases for creating and executing SnapLogic "
            "triggered tasks. Includes task creation, parameter passing, and execution."
        ),
        tools=_UTILITY_TOOLS,
        positional_args=_UTILITY_ARGS,
        cot_instructions=(
            "Think step by step before generating any files:\n"
            "1. First, read the pipeline file to understand its parameters\n"
            "2. Check existing triggered task tests for naming and parameter conventions\n"
            "3. Identify the Groundplex name, task parameters, and notification settings\n"
            "4. Generate the .robot file with correct task creation and execution keywords"
        ),
    ),
    "compare-csv": SkillDef(
        name="compare-csv",
        description=(
            "Generate Robot Framework test cases for comparing actual vs expected CSV "
            "output files. Validates pipeline output against expected results."
        ),
        tools=_UTILITY_TOOLS,
        positional_args=_UTILITY_ARGS,
        cot_instructions=(
            "Think step by step before generating any files:\n"
            "1. First, identify the actual output CSV location and expected CSV location\n"
            "2. Check existing comparison tests for the project's comparison patterns\n"
            "3. Determine if order matters, which columns to compare, and tolerance settings\n"
            "4. Generate the .robot file using the correct comparison template keyword"
        ),
    ),
    "verify-data-in-db": SkillDef(
        name="verify-data-in-db",
        description=(
            "Generate Robot Framework test cases for verifying data in database tables. "
            "Verify record counts, export to CSV, compare actual vs expected output."
        ),
        tools=_UTILITY_TOOLS,
        positional_args=_UTILITY_ARGS,
        cot_instructions=(
            "Think step by step before generating any files:\n"
            "1. First, identify which database and tables to verify\n"
            "2. Read existing verification tests to understand the query patterns\n"
            "3. Check the queries resource file for existing SQL queries\n"
            "4. Determine what assertions are needed (row counts, specific values, exports)\n"
            "5. Generate the .robot file with correct database keywords and assertions"
        ),
    ),
    "export-data-to-csv": SkillDef(
        name="export-data-to-csv",
        description=(
            "Generate Robot Framework test cases for exporting database table data to "
            "CSV files. Supports Oracle, Snowflake, PostgreSQL, and other databases."
        ),
        tools=_UTILITY_TOOLS,
        positional_args=_UTILITY_ARGS,
        cot_instructions=(
            "Think step by step before generating any files:\n"
            "1. First, identify the database type and connection details\n"
            "2. Read existing export tests to understand the project's export patterns\n"
            "3. Determine the SQL query, output path, and file naming convention\n"
            "4. Generate the .robot file using the correct export keyword"
        ),
    ),
    "end-to-end-pipeline-verification": SkillDef(
        name="end-to-end-pipeline-verification",
        description=(
            "Generate a complete Robot Framework test suite with account creation, "
            "file uploads, pipeline import, triggered task execution, and data "
            "verification — all in a single test file."
        ),
        tools=_UTILITY_TOOLS,
        positional_args=_UTILITY_ARGS,
        cot_instructions=(
            "Think step by step before generating any files:\n"
            "1. First, read the full codebase structure to understand all existing patterns\n"
            "2. Identify: which accounts are needed, which pipelines to import, what tasks to create\n"
            "3. Check existing E2E tests (oracle.robot, mysql.robot, etc.) as reference patterns\n"
            "4. Plan the test execution order: accounts → uploads → import → tasks → verify\n"
            "5. Generate a single .robot file with all steps in the correct order\n"
            "6. Include proper Suite Setup, Variables, Test Cases, and Keywords sections"
        ),
    ),
    "analyze-pipeline": SkillDef(
        name="analyze-pipeline",
        description=(
            "Analyze a SnapLogic .slp pipeline file and extract accounts, parameters, "
            "snaps, data flow, and output paths. Produces PIPELINE_ANALYSIS.md with a "
            "test blueprint showing what RF test cases are needed."
        ),
        tools=[
            "Read", "Glob", "Grep", "Task", "TodoWrite",
            "Write",
        ],
        positional_args=_UTILITY_ARGS,
        cot_instructions=(
            "Think step by step before writing the analysis:\n"
            "1. Find all .slp files in src/pipelines/ (or the path the user specified)\n"
            "2. Read each .slp file — it's JSON. Parse property_map, snap_map, link_map\n"
            "3. Extract pipeline parameters from property_map.settings.param_table.value\n"
            "4. Extract accounts from each snap's property_map.account.account_ref.value\n"
            "5. Map snap types to services (oracle, postgres, kafka, s3, etc.)\n"
            "6. Trace data flow using link_map (src_id → dst_id)\n"
            "7. Find output paths (File Writer filename, S3 paths, database tables)\n"
            "8. Write PIPELINE_ANALYSIS.md with test blueprint and suggested rf-forge commands"
        ),
    ),
}
