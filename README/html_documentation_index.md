# SnapLogic Robot Framework - Documentation Index

This document provides a comprehensive list of all HTML documentation files available in this repository.

## How to View HTML Files

- **Relative Path**: Use for local access or viewing raw file in GitHub
- **GitHub Link**: Click to open and render HTML directly in your browser (uses `htmlpreview.github.io`)

---

## Tutorials

Step-by-step guides for getting started with the framework.

| Document Name                  | Description                                              | Relative Path                                                      | GitHub Link                                                                                                                                                                        |
| ------------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Prerequisites                  | System requirements and software dependencies            | `README/How To Guides/robot_framework_guides/html_docs/01_prerequisites.html`                 | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/robot_framework_guides/html_docs/01_prerequisites.html)                 |
| Architecture Overview          | High-level architecture and component overview           | `README/How To Guides/robot_framework_guides/html_docs/02_architecture_overview.html`         | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/robot_framework_guides/html_docs/02_architecture_overview.html)         |
| Pre-Execution Setup            | Configuration and environment setup before running tests | `README/How To Guides/robot_framework_guides/html_docs/04_configuration_setup.html`           | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/robot_framework_guides/html_docs/04_configuration_setup.html)           |
| Pipeline Execution Quick Start | Getting started with running your first pipeline test    | `README/How To Guides/robot_framework_guides/html_docs/05_pipeline_execution_quickstart.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/robot_framework_guides/html_docs/05_pipeline_execution_quickstart.html) |
| Testing Phases                 | Understanding the different phases of test execution     | `README/How To Guides/robot_framework_guides/html_docs/06_testing_phases.html`                | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/robot_framework_guides/html_docs/06_testing_phases.html)                |

---

## Robot Framework Guides

Detailed guides for Robot Framework test development and execution.

| Document Name | Description | Relative Path | GitHub Link |
| --- | --- | --- | --- |
| Complete End-to-End Workflow | Full workflow from setup to test execution | `README/How To Guides/robot_framework_guides/html_docs/robotframework_end_to_end_workflow_steps.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/robot_framework_guides/html_docs/robotframework_end_to_end_workflow_steps.html) |
| Account Creation Guide | How to create and configure SnapLogic accounts | `README/How To Guides/robot_framework_guides/html_docs/account_creation_guide.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/robot_framework_guides/html_docs/account_creation_guide.html) |
| Make Targets Documentation | Makefile commands for test execution | `README/How To Guides/robot_framework_guides/html_docs/robot_framework_make_targets_documentation.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/robot_framework_guides/html_docs/robot_framework_make_targets_documentation.html) |
| Test Initialization Workflow | init.robot file and suite setup | `README/How To Guides/robot_framework_guides/html_docs/test_initialization_workflow_init_file.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/robot_framework_guides/html_docs/test_initialization_workflow_init_file.html) |
| Triggered Task Guide | Working with SnapLogic triggered tasks | `README/How To Guides/robot_framework_guides/html_docs/triggered_task_guide.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/robot_framework_guides/html_docs/triggered_task_guide.html) |

---

## Test Case Tutorials

Walkthroughs of specific test cases inside the framework — designed for layman audiences and demo recordings. Each tutorial sits next to the corresponding `.robot` test file.

| Document Name | Description | Relative Path | GitHub Link |
| --- | --- | --- | --- |
| Create Account &mdash; Manual vs Automation | Side-by-side comparison of creating a SnapLogic account by hand in Designer versus via the `Create Account From Template` Robot keyword. Includes a sample test case, the `overwrite_if_exists` flag, and `make` invocation examples. | `{{cookiecutter.primary_pipeline_name}}/test/suite/pipeline_tests/tutorial_testcases/accounts/create_account_explained.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/%7B%7Bcookiecutter.primary_pipeline_name%7D%7D/test/suite/pipeline_tests/tutorial_testcases/accounts/create_account_explained.html) |
| Import Pipeline &mdash; Two Ways | Walkthrough of `Import Pipelines From Template` vs `Import Pipeline With Original Name`. Covers all 4–5 arguments per keyword, the `duplicate_check` flag, the `unique_id` suffix behaviour, common pitfalls, and the suite-variable side effects. | `{{cookiecutter.primary_pipeline_name}}/test/suite/pipeline_tests/tutorial_testcases/03.pipelines/import_pipeline_explained.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/%7B%7Bcookiecutter.primary_pipeline_name%7D%7D/test/suite/pipeline_tests/tutorial_testcases/03.pipelines/import_pipeline_explained.html) |
| Create Triggered Task &mdash; Two Ways | Walkthrough of `Create Triggered Task From Template` vs `Create Triggered Task For Original Pipeline Name`. Explains the 8 arguments, Robot Framework positional vs named arguments, when `unique_id` is appended (task only, never pipeline), all 11 valid call patterns, and which import keyword pairs with which task keyword. | `{{cookiecutter.primary_pipeline_name}}/test/suite/pipeline_tests/tutorial_testcases/04.tasks/triggered_task_explained.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/%7B%7Bcookiecutter.primary_pipeline_name%7D%7D/test/suite/pipeline_tests/tutorial_testcases/04.tasks/triggered_task_explained.html) |

---

## Infrastructure Setup Guides

Guides for setting up various infrastructure components.

### Docker

| Document Name                     | Description                                        | Relative Path                                                                     | GitHub Link                                                                                                                                                                                         |
| --------------------------------- | -------------------------------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Docker Compose Architecture       | Docker Compose configuration and architecture flow | `README/How To Guides/infra_setup_guides/docker/docker-compose.html`              | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/infra_setup_guides/docker/docker-compose.html)              |
| Docker Infrastructure Guide       | Docker container setup and management              | `README/How To Guides/infra_setup_guides/docker/docker_infrastructure_guide.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/infra_setup_guides/docker/docker_infrastructure_guide.html) |
| Configuration Files Documentation | Makefile, Docker, and environment files explained  | `README/How To Guides/infra_setup_guides/docker_makefile_envfiles_details.html`   | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/infra_setup_guides/docker_makefile_envfiles_details.html)   |

### Kafka

| Document Name        | Description                            | Relative Path                                                             | GitHub Link                                                                                                                                                                                 |
| -------------------- | -------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Kafka Core Concepts  | End-to-end Kafka workflow and concepts | `README/How To Guides/infra_setup_guides/kafka/kafka-core-concepts.html`  | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/infra_setup_guides/kafka/kafka-core-concepts.html)  |
| Kafka Docker Compose | Kafka Docker container configuration   | `README/How To Guides/infra_setup_guides/kafka/kafka-docker-compose.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/infra_setup_guides/kafka/kafka-docker-compose.html) |

### Salesforce

| Document Name                  | Description                                            | Relative Path                                                                                   | GitHub Link                                                                                                                                                                                                             |
| ------------------------------ | ------------------------------------------------------ | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Stateless vs Stateful Workflow | Understanding workflow patterns for Salesforce testing | `README/How To Guides/infra_setup_guides/salesforce/README/stateless vs stateful workflow.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/infra_setup_guides/salesforce/README/stateless%20vs%20stateful%20workflow.html) |

### Authentication

| Document Name | Description | Relative Path | GitHub Link |
| --- | --- | --- | --- |
| JWT & OAuth2 Authentication Setup | Setting up JWT and OAuth2 authentication for SnapLogic pipelines | `README/How To Guides/infra_setup_guides/setup_jwt_oauth2_authentication.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/infra_setup_guides/setup_jwt_oauth2_authentication.html) |

### VS Code

| Document Name       | Description                            | Relative Path                                           | GitHub Link                                                                                                                                                             |
| ------------------- | -------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| VS Code Setup Guide | IDE configuration and extensions setup | `README/How To Guides/robot_framework_guides/html_docs/03_vscode_setup_guide.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/robot_framework_guides/html_docs/03_vscode_setup_guide.html) |

### Git

| Document Name | Description | Relative Path | GitHub Link |
| --- | --- | --- | --- |
| Git Pull with Local Changes | How to save local changes, pull latest code, and restore your customizations | `README/How To Guides/infra_setup_guides/git/git_pull_with_local_changes.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/infra_setup_guides/git/git_pull_with_local_changes.html) |

### Windows

| Document Name              | Description                                          | Relative Path                                                                              | GitHub Link                                                                                                                                                                                                          |
| -------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Windows WSL Setup Guide    | WSL installation and VS Code integration for Windows | `README/How To Guides/infra_setup_guides/windows/windows_wsl_vscode_setup.html`            | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/infra_setup_guides/windows/windows_wsl_vscode_setup.html)                    |
| Windows Linux WSL Fundamentals | Core WSL concepts and Linux fundamentals for Windows users | `README/How To Guides/infra_setup_guides/windows/windows_linux_wsl_fundamentals.html` | [Open](https://htmlpreview.github.io/?https://github.com/SnapLogic/snaplogic-robotframework-examples/blob/main/README/How%20To%20Guides/infra_setup_guides/windows/windows_linux_wsl_fundamentals.html) |



