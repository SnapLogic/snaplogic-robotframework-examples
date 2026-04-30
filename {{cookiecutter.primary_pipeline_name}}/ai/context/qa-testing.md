# QA Testing — Shared Knowledge for Testing Forge Agents

This document provides testing best practices and conventions that apply across
ALL Testing Forge skills (analyze-requirements, generate-tests, etc.).

## Core Testing Principles

### 1. Test Independence
- Each test must run independently — no shared mutable state
- Tests must work in any order
- Use setup/teardown or fixtures to reset state

### 2. AAA Pattern (Arrange-Act-Assert)
Every test should follow:
- **Arrange** — set up inputs and dependencies
- **Act** — execute the code under test
- **Assert** — verify expected behavior

### 3. One Logical Assertion Per Test
Prefer multiple focused tests over one mega-test with 10 assertions.
Exception: parametrized tests that assert the same behavior across inputs.

### 4. Descriptive Test Names
Use naming conventions that describe what is being tested:
- Python/pytest: `test_<what>_<when>_<expected>` (e.g., `test_hello_with_empty_input_returns_default_greeting`)
- JUnit: `shouldDoSomethingWhenCondition`
- Avoid vague names like `test1`, `test_it_works`

## Coverage Targets

Testing Forge targets these coverage thresholds:
- **Line coverage**: 90%+ minimum (100% target)
- **Branch coverage**: 85%+ minimum (100% target)

When coverage gaps exist, document WHY they're acceptable (e.g., "defensive check for impossible state").

## Framework-Specific Conventions

### pytest (Python)
- Use `pytest.mark.parametrize` for data-driven tests
- Prefer fixtures over global setup
- Mark slow tests with `@pytest.mark.slow`

### JUnit 5 (Java)
- Use `@DisplayName` for human-readable test descriptions
- Use `@Nested` classes to group related tests
- Use `@ParameterizedTest` for data-driven tests

### Jest (JavaScript)
- Use `describe`/`it` blocks for structure
- Prefer `toEqual` over `toBe` for object comparison
- Mock external dependencies with `jest.mock`

### Robot Framework (Python — integration / E2E)
- Test files use `.robot` extension; reusable keyword libraries use `.resource`
- Test structure uses section markers: `*** Settings ***`, `*** Variables ***`, `*** Keywords ***`, `*** Test Cases ***`
- **Keyword-driven testing** — prefer reusable named keywords over inline step logic
- `Library` imports bring in Python/Java extensions (e.g. `DatabaseLibrary`, `SeleniumLibrary`, `RequestsLibrary`)
- `Resource` imports share keyword definitions across test suites
- Tags (`[Tags]`) for selective test execution: `pytest robot -t smoke`
- `[Template]` for data-driven tests that apply the same keyword to multiple rows
- Setup/teardown at suite/test level: `Suite Setup`, `Test Setup`, `Test Teardown`
- Common signals the project uses RF:
    - `.robot` files present
    - `robotframework` listed in `requirements.txt` or `pyproject.toml`
    - `resources/` or `keywords/` folder with `.resource` files
    - Project-specific pattern: `{{cookiecutter.primary_pipeline_name}}/test/suite/` layout
- For SnapLogic pipeline testing specifically:
    - Tests often import `RequestsLibrary` + custom Snaplogic keywords
    - Oracle/DB tests use `DatabaseLibrary` + environment variables from `.env`
    - Kafka/messaging tests use topic setup/teardown keywords

## Universal DO NOTs

- ❌ Do NOT modify production code from within tests
- ❌ Do NOT make network calls to real external services in unit tests (use mocks)
- ❌ Do NOT commit test data that contains real customer information
- ❌ Do NOT write tests that depend on system time unless time is mocked
- ❌ Do NOT use `sleep()` to handle race conditions — use proper synchronization

## Categories of Tests to Consider

| Category    | What it covers                         |
| ----------- | -------------------------------------- |
| Happy path  | Normal, expected inputs                |
| Edge cases  | Empty, zero, max, min, boundary values |
| Error paths | Invalid input, missing data, timeouts  |
| Security    | Injection, auth, input sanitization    |
| Performance | Large inputs, concurrent access        |
| Regression  | Previously fixed bugs                  |

## Report Priorities

Use this priority system when analyzing scenarios:
- **P0** (Critical) — Test must exist before code ships
- **P1** (Important) — Should exist; gap should be explicitly tracked
- **P2** (Nice-to-have) — Add when time allows

## Output Conventions

- All generated markdown reports use the unified 2-part format
  (human summary at top, technical details below)
- All generated test files follow the target framework's conventions
- Reports use anchor links (e.g., `[details](#3-scenarios)`) for navigation