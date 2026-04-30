"""
Unified report format for RF Forge output.

All skills generate a single markdown format with two parts:
1. Human-Readable Summary (top) — concise, decision-focused, with anchor links
2. Technical Details (bottom) — comprehensive specs for LLM agents and curious humans
"""


def get_report_instructions(skill_name: str) -> str:
    """
    Get unified report generation instructions for a skill.

    Every skill produces ONE markdown format that serves both human reviewers
    and downstream LLM agents. The top part is a concise summary with anchor
    links to technical detail sections at the bottom.

    Args:
        skill_name: Name of the skill (create-account, import-pipeline, etc.)

    Returns:
        Instructions to append to skill prompt for report generation
    """
    return f"""
## Report Format: Unified (Summary + Technical Details)

Generate a **unified** report with two parts in a single markdown file:

### Part 1: Human-Readable Summary (top of document)

This is the first thing a human reviewer sees. Keep it **concise and decision-focused**:

- **Short sections** with bullet points — no walls of text
- **Focus on decisions**: what was chosen, why, and what needs approval
- **Anchor links** to technical details below (e.g., `[details](#section-heading)`)
- **Action-oriented**: end with clear next steps
- **Target length**: ~100-150 lines for the summary portion of {skill_name}

The summary should include:
1. Status and key metadata
2. Key decisions made (with rationale in 1-2 sentences each)
3. Risks, concerns, or questions
4. A review checklist
5. Clear next steps

For each decision or notable item in the summary, add an anchor link like:
`[See details](#3-infrastructure-analysis)` or `[full scenario list](#52-test-scenarios)`
so the reader can jump to the corresponding technical section below.

### Part 2: Technical Details (bottom of document, after a clear divider)

After the summary, include a clearly marked section:

```markdown
---

# Technical Details

> The sections below contain comprehensive technical information referenced
> by the summary above. They are intended for detailed review and for
> downstream LLM agents that consume this document.
```

This part should be **exhaustive and comprehensive**:
- Full test specifications, code snippets, configurations
- Complete scenario lists with all attributes
- All reference test patterns from similar implementations
- Detailed coverage breakdowns and gap analysis
- Full dependency lists and environment requirements
- Everything a downstream agent needs to continue without clarification

### Anchor Link Convention

Use standard markdown heading anchors. For a heading like `## 4. Test Scenarios`,
the anchor is `#4-test-scenarios`. In the summary, link like:

```markdown
- **Scenarios**: 24 test cases identified — [details](#4-test-scenarios)
```

This creates clickable navigation within a single markdown file.

### Key Principle

The summary is for humans who want the high-level picture.
The technical details are for LLM agents (and humans who want to dive deeper).
Both live in one document so nothing is lost between skills.
"""
