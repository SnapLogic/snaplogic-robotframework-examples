"""
RF Forge — Command-Line Interface.

Provides standalone utility skills for generating Robot Framework test cases
for SnapLogic pipeline testing. Each skill is an independent subcommand.

Usage:
    rf-forge create-account "Create Oracle account" --codebase-path ./project
    rf-forge import-pipeline "Import MySQL pipeline" --codebase-path ./project
    rf-forge --help
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from rf_forge import __version__
from rf_forge.skills import SKILLS


def _default_codebase_path() -> str | None:
    """Return CODEBASE_PATH from environment, or None."""
    return os.environ.get("CODEBASE_PATH")


def _require_codebase(ns: argparse.Namespace, parser: argparse.ArgumentParser) -> str:
    """Resolve and validate --codebase-path."""
    codebase = ns.codebase_path or _default_codebase_path()
    if not codebase:
        parser.error(
            "--codebase-path is required (or set CODEBASE_PATH env var)"
        )
    p = Path(codebase)
    if not p.exists():
        parser.error(f"Codebase path does not exist: {codebase}")
    return str(p.resolve())


def _build_parser() -> argparse.ArgumentParser:
    """Build the CLI argument parser with all utility skill subcommands."""
    parser = argparse.ArgumentParser(
        prog="rf-forge",
        description="AI-powered CLI for generating Robot Framework test cases for SnapLogic pipeline testing.",
    )
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {__version__}"
    )

    sub = parser.add_subparsers(dest="skill", help="Utility skill to run")

    # Register every skill as a subcommand — all share the same args
    for skill_name, skill_def in SKILLS.items():
        p = sub.add_parser(
            skill_name,
            help=skill_def.description,
            description=skill_def.description,
        )
        p.add_argument(
            "instruction",
            nargs="?",
            default=None,
            help="What to generate (freeform text describing your need)",
        )
        p.add_argument(
            "--file",
            default=None,
            metavar="PATH",
            help="Read instruction from a markdown file instead of positional text",
        )
        p.add_argument(
            "--codebase-path",
            default=None,
            metavar="PATH",
            help="Path to the target Robot Framework project (or set CODEBASE_PATH env var)",
        )
        p.add_argument(
            "--model",
            default="claude-opus-4-7",
            help=(
                "Claude model. Default: claude-opus-4-7 (full ID, bypasses auto-1M-context "
                "behavior of opus/sonnet aliases). Use haiku for cheaper/faster runs."
            ),
        )
        p.add_argument(
            "--raw-json",
            action="store_true",
            help="Output raw JSON stream instead of pretty colors",
        )
        p.add_argument(
            "--json-log",
            default=None,
            metavar="PATH",
            help="Write JSONL audit log to this file",
        )
        p.add_argument(
            "--max-budget",
            type=float,
            default=None,
            metavar="USD",
            help="Dollar cap — stop if cost exceeds this amount",
        )
        p.add_argument(
            "--context-file",
            default=None,
            metavar="PATH",
            help="Additional context file (.md) to inject into Claude's system prompt alongside qa-testing.md",
        )
        p.add_argument(
            "--output-dir",
            default=None,
            metavar="PATH",
            help="Save session log (SESSION_SUMMARY.md, session.jsonl, files_created.txt) to this directory",
        )

    return parser


def _snapshot_files(codebase: str) -> dict[str, float]:
    """Take a snapshot of all files in the codebase with their modification times."""
    snapshot = {}
    codebase_path = Path(codebase)
    for f in codebase_path.rglob("*"):
        if f.is_file() and ".git" not in f.parts and "__pycache__" not in f.parts and "myenv" not in f.parts and ".venv" not in f.parts:
            try:
                snapshot[str(f.relative_to(codebase_path))] = f.stat().st_mtime
            except OSError:
                pass
    return snapshot


def _diff_snapshots(before: dict[str, float], after: dict[str, float]) -> tuple[list[str], list[str], list[str]]:
    """Compare before/after snapshots. Returns (created, modified, unchanged) relative paths."""
    created = []
    modified = []
    unchanged = []

    for path, mtime in after.items():
        if path not in before:
            created.append(path)
        elif mtime != before[path]:
            modified.append(path)
        else:
            unchanged.append(path)

    return sorted(created), sorted(modified), sorted(unchanged)


def _handle_skill(ns: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    """Generic handler for all utility skills."""
    # Lazy import to keep --help fast
    from datetime import datetime
    from rf_forge import runner

    # Resolve instruction — from positional text or --file
    instruction = ns.instruction
    if ns.file:
        if instruction:
            parser.error("Cannot use both --file and a positional instruction")
        file_path = Path(ns.file)
        if not file_path.exists():
            parser.error(f"File not found: {ns.file}")
        instruction = file_path.read_text()
    if not instruction:
        parser.error(
            f"Provide an instruction: rf-forge {ns.skill} \"what to generate\" --codebase-path /path"
        )

    # Resolve and validate codebase path
    codebase = _require_codebase(ns, parser)

    # Look up the skill
    skill = SKILLS[ns.skill]

    # Build args
    args = {
        "instruction": instruction,
        "codebase_path": codebase,
    }

    # Validate extra context file if provided
    extra_context = None
    if ns.context_file:
        ctx_path = Path(ns.context_file)
        if not ctx_path.exists():
            parser.error(f"Context file not found: {ns.context_file}")
        extra_context = str(ctx_path.resolve())

    # Set up output dir for session logs (if requested)
    output_dir = None
    json_log = ns.json_log
    if ns.output_dir:
        output_dir = Path(ns.output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        if not json_log:
            json_log = str(output_dir / "session.jsonl")

    # Snapshot files BEFORE the run
    before_snapshot = _snapshot_files(codebase)

    # Run the skill — agent operates inside the user's codebase
    stats = runner.run_skill(
        skill=skill,
        args=args,
        model=ns.model,
        max_budget=ns.max_budget,
        raw_json=ns.raw_json,
        json_log=json_log,
        cwd=codebase,
        extra_context_files=[extra_context] if extra_context else None,
    )

    # Snapshot files AFTER the run
    after_snapshot = _snapshot_files(codebase)
    created, modified, _ = _diff_snapshots(before_snapshot, after_snapshot)

    # Print file changes to console
    if created or modified:
        print(f"\n📁 Files changed in codebase:")
        for f in created:
            print(f"   ✅ CREATED  {f}")
        for f in modified:
            print(f"   ✏️  MODIFIED {f}")
    else:
        print(f"\n⚠️  No files were created or modified in the codebase.")

    # Write session artifacts to output dir (if requested)
    if output_dir and stats:
        _write_session_summary(
            output_dir=output_dir,
            skill_name=ns.skill,
            instruction=instruction,
            codebase=codebase,
            model=ns.model,
            stats=stats,
            timestamp=datetime.now(),
            created=created,
            modified=modified,
        )

    if stats:
        print(f"\n✅ Done. Stats: {stats}")
        if output_dir:
            print(f"📁 Session log: {output_dir}")


def _write_session_summary(
    output_dir: Path,
    skill_name: str,
    instruction: str,
    codebase: str,
    model: str,
    stats: dict,
    timestamp,
    created: list[str] | None = None,
    modified: list[str] | None = None,
) -> None:
    """Write session summary with file change details to output dir."""
    created = created or []
    modified = modified or []
    total_changed = len(created) + len(modified)

    # Build file status table
    file_table_lines = []
    for i, f in enumerate(created, 1):
        file_table_lines.append(f"| {i} | `{f}` | **Created** |")
    for i, f in enumerate(modified, len(created) + 1):
        file_table_lines.append(f"| {i} | `{f}` | **Modified** |")
    if not file_table_lines:
        file_table_lines.append("| — | No files changed | — |")
    file_table = "\n".join(file_table_lines)

    # Build what-was-created descriptions
    created_details = ""
    if created:
        created_details = "\n### What was created\n\n"
        for f in created:
            fname = Path(f).name
            created_details += f"**`{fname}`** — `{f}`\n\n"

    modified_details = ""
    if modified:
        modified_details = "\n### What was modified\n\n"
        for f in modified:
            fname = Path(f).name
            modified_details += f"**`{fname}`** — `{f}`\n\n"

    summary = f"""# Session Summary — {skill_name}

**Date:** {timestamp.strftime('%Y-%m-%d %H:%M:%S')}
**Skill:** `{skill_name}`
**Model:** {model}
**Codebase:** `{codebase}`

---

## Instruction

{instruction}

---

## Results

| Metric | Value |
|---|---|
| Turns | {stats['num_turns']} |
| Cost | ${stats['cost_usd']:.4f} |
| Duration | {stats['duration_ms'] / 1000:.1f}s |
| Files created | {len(created)} |
| Files modified | {len(modified)} |
| Total changes | {total_changed} |

---

## Files — Status

| # | File | Status |
|---|------|--------|
{file_table}
{created_details}{modified_details}
---

## How to run the generated tests

```bash
# From the project root:
make robot-run-all-tests TAGS="{skill_name.split('-')[0] if '-' in skill_name else skill_name}" PROJECT_SPACE_SETUP=True
```

---

## Session files

| File | Purpose |
|---|---|
| `SESSION_SUMMARY.md` | This file — what was done, files changed, cost |
| `session.jsonl` | Full audit log — every tool call, response, cost per turn |

---

## How to review

1. Read this summary for the high-level view
2. Check the **Files — Status** table above to see what was created/modified
3. Review the generated files in the codebase (`{codebase}`)
4. Check `session.jsonl` for the detailed tool-call trace

---

## How to undo

To revert all changes made by this session:

```bash
cd {codebase}
git checkout -- .
```

Or selectively remove created files:

```bash
{chr(10).join(f'rm "{f}"' for f in created) if created else '# No files were created'}
```
"""

    # Write SESSION_SUMMARY.md
    summary_path = output_dir / "SESSION_SUMMARY.md"
    summary_path.write_text(summary)

    # Write files_created.txt — simple manifest
    manifest_lines = []
    for f in created:
        manifest_lines.append(f"CREATED   {f}")
    for f in modified:
        manifest_lines.append(f"MODIFIED  {f}")
    manifest_path = output_dir / "files_created.txt"
    manifest_path.write_text("\n".join(manifest_lines) + "\n" if manifest_lines else "# No files changed\n")

    print(f"\n📄 Session summary: {summary_path}")
    print(f"📄 File manifest:   {manifest_path}")


def main(argv: list[str] | None = None) -> None:
    """CLI entry point."""
    parser = _build_parser()
    ns = parser.parse_args(argv)

    if not ns.skill:
        parser.print_help()
        sys.exit(0)

    _handle_skill(ns, parser)
