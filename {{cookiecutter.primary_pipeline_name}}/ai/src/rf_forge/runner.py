from __future__ import annotations

import asyncio
import shutil
import tempfile
from pathlib import Path

from claude_gen_agent import ClaudeGenAgent

from rf_forge.report_mode import get_report_instructions
from rf_forge.skills import SkillDef


def _find_plugins_dir() -> Path:
    """Resolve the plugins (SKILL.md) directory.

    Tries 4 locations in order:
    1. rf_forge/_data/plugins/ next to this file (pip install / wheel)
    2. ai/plugins/ relative to this package (editable install — symlink or real dir)
    3. .claude/skills/ in the RF repo root (no symlink needed — direct discovery)
    4. importlib.resources fallback
    """
    # 1. Sibling _data directory (pip install / wheel)
    pkg_data = Path(__file__).resolve().parent / "_data" / "plugins"
    if pkg_data.is_dir() and (pkg_data / "skills").is_dir():
        return pkg_data

    # 2. ai/plugins/ (editable install — may be symlink or real dir)
    ai_root = Path(__file__).resolve().parent.parent.parent  # ai/
    ai_plugins = ai_root / "plugins"
    if ai_plugins.is_dir() and (ai_plugins / "create-account").is_dir():
        return ai_plugins

    # 3. .claude/skills/ in the RF repo root (no symlink needed)
    #    Path: ai/ → parent = {{cookiecutter}}/ → .claude/skills/
    rf_repo_root = ai_root.parent
    claude_skills = rf_repo_root / ".claude" / "skills"
    if claude_skills.is_dir() and (claude_skills / "create-account").is_dir():
        return claude_skills

    # 4. importlib.resources fallback
    try:
        from importlib.resources import files

        res = files("rf_forge") / "_data" / "plugins"
        res_path = Path(str(res))
        if res_path.is_dir():
            return res_path
    except Exception:
        pass

    raise FileNotFoundError(
        "Cannot locate SKILL.md files. Looked in:\n"
        f"  1. {pkg_data}\n"
        f"  2. {ai_plugins}\n"
        f"  3. {claude_skills}\n"
        "Ensure the package is installed correctly or .claude/skills/ exists."
    )


def _find_context_dir() -> Path:
    """Resolve the context directory (qa-testing.md).

    Tries 3 locations:
    1. rf_forge/_data/context/ (pip install / wheel)
    2. ai/context/ (editable install)
    3. importlib.resources fallback
    """
    # 1. Sibling _data directory
    pkg_data = Path(__file__).resolve().parent / "_data" / "context"
    if pkg_data.is_dir() and (pkg_data / "qa-testing.md").exists():
        return pkg_data

    # 2. ai/context/ (editable install)
    ai_root = Path(__file__).resolve().parent.parent.parent
    ai_context = ai_root / "context"
    if ai_context.is_dir() and (ai_context / "qa-testing.md").exists():
        return ai_context

    # 3. importlib.resources fallback
    try:
        from importlib.resources import files

        res = files("rf_forge") / "_data" / "context"
        res_path = Path(str(res))
        if res_path.is_dir():
            return res_path
    except Exception:
        pass

    raise FileNotFoundError(
        "Cannot locate context/qa-testing.md. "
        "Ensure the package is installed correctly."
    )


def _build_filtered_plugins_dir(plugins_dir: Path, skill_name: str) -> Path:
    """Create a temp plugins directory containing only the matched skill.

    Why this exists:
        Without filtering, ClaudeGenAgent loads ALL SKILL.md files in the
        plugins directory (~150K tokens for 15 skills). Each rf-forge run
        uses exactly ONE skill, so loading the others wastes tokens AND can
        push context past Claude's standard 200K limit (triggering the
        "Extra usage required for 1M context" error).

        This function creates a temp directory with only the matched skill
        symlinked in. The agent loads ~25K tokens instead of ~150K — a 6×
        reduction with no functional change.

    Args:
        plugins_dir: The full plugins directory (containing all skill subdirs).
        skill_name: The name of the skill to load (e.g., "create-account").

    Returns:
        Path to a temp directory containing only the matched skill.
        Caller is responsible for cleanup via shutil.rmtree.

    Raises:
        FileNotFoundError: If the skill subdirectory cannot be found.
    """
    # Locate the skill source directory — try both nesting conventions
    skill_src = plugins_dir / skill_name
    if not skill_src.is_dir():
        # Pattern A nesting: plugins/skills/<name>
        skill_src = plugins_dir / "skills" / skill_name
        if not skill_src.is_dir():
            raise FileNotFoundError(
                f"Skill '{skill_name}' not found in {plugins_dir}. "
                f"Looked for {plugins_dir / skill_name} and "
                f"{plugins_dir / 'skills' / skill_name}."
            )

    # Create a temp dir and symlink only the matched skill into it
    temp_root = Path(tempfile.mkdtemp(prefix="rf-forge-plugins-"))
    target = temp_root / skill_name
    target.symlink_to(skill_src.resolve())

    return temp_root


def run_skill(
    skill: SkillDef,
    args: dict[str, str],
    *,
    model: str = "claude-opus-4-7",
    provider: str | None = None,
    bedrock_region: str | None = None,
    effort: str = "high",
    max_turns: int = 10000,
    max_budget: float | None = None,
    init_timeout: int = 120,
    raw_json: bool = False,
    json_log: str | None = None,
    cwd: str | None = None,
    extra_context_files: list[str] | None = None,
) -> dict | None:
    """Build a ClaudeGenAgent for the given skill and run it.

    This is the ONLY function in RFForge that touches claude-gen-agent.
    Every CLI command ultimately ends up calling this.

    Args:
        skill: The skill definition from skills.py
        args: Dict of args matching skill.positional_args
        model: Claude model alias (opus/sonnet/haiku) or full model ID
        provider: Override cloud provider ("anthropic" / "bedrock" / "vertex")
        bedrock_region: Bedrock cross-region prefix ("us" / "eu" / etc.)
        effort: Reasoning effort level ("low" / "medium" / "high" / "max")
        max_turns: Safety cap on conversation turns
        max_budget: Optional dollar cap — stop if cost exceeds this
        init_timeout: Seconds to wait for agent initialization
        raw_json: If True, output raw JSON stream instead of pretty colors
        json_log: Optional path to write JSONL audit log
        cwd: Working directory for the agent

    Returns:
        Dict with num_turns, cost_usd, duration_ms — or None if no result.
    """
    plugins_dir = _find_plugins_dir()
    context_dir = _find_context_dir()

    context_file = context_dir / "qa-testing.md"
    if not context_file.exists():
        raise FileNotFoundError(f"Context file not found: {context_file}")

    # Build context files list — default + any extras from --context-file
    all_context_files = [str(context_file)]
    if extra_context_files:
        all_context_files.extend(extra_context_files)

    # JSONL logging setup
    enable_jsonl = json_log is not None
    jsonl_path = json_log if enable_jsonl else None

    # Build prompt: skill command + unified report format instructions
    prompt = skill.format_prompt(args)
    report_instructions = get_report_instructions(skill.name)
    prompt += f"\n\n{report_instructions}"

    # Filter plugins to ONLY the matched skill — saves ~125K tokens per run
    # (loads ~25K instead of ~150K for all 15 skills). See
    # _build_filtered_plugins_dir docstring for details.
    filtered_plugins_dir = _build_filtered_plugins_dir(plugins_dir, skill.name)

    try:
        agent = ClaudeGenAgent(
            allowed_tools=list(skill.tools),
            system_prompt={"type": "preset", "preset": "claude_code"},
            context_files=all_context_files,
            plugins=[str(filtered_plugins_dir)],
            permission_mode="bypassPermissions",
            setting_sources=None,
            title=f"RF Forge: {skill.name}",
            model=model,
            provider=provider,
            bedrock_region=bedrock_region,
            effort=effort,
            max_turns=max_turns,
            max_budget_usd=max_budget,
            init_timeout_seconds=init_timeout,
            cwd=cwd,
            enable_jsonl_logging=enable_jsonl,
            jsonl_log_path=jsonl_path,
        )

        mode = "raw-json" if raw_json else "pretty"
        asyncio.run(agent.run(prompt, mode=mode))

        # Print cost summary and return stats
        if agent.result_message:
            rm = agent.result_message
            print(
                f"\n--- RF Forge session complete ---\n"
                f"Turns: {rm.num_turns}  "
                f"Cost: ${rm.total_cost_usd:.4f}  "
                f"Duration: {rm.duration_ms / 1000:.1f}s"
            )
            return {
                "num_turns": rm.num_turns,
                "cost_usd": rm.total_cost_usd,
                "duration_ms": rm.duration_ms,
            }
        return None
    finally:
        # Always clean up the temp filtered plugins directory
        shutil.rmtree(filtered_plugins_dir, ignore_errors=True)
