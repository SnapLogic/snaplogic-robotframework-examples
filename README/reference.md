# SnapLogic Test Framework Reference Guide

This document provides a comprehensive reference to all documentation available in the SnapLogic Test Automation Framework. Use this as your central hub to navigate to specific guides and tutorials.

## Table of Contents

1. [Tutorials](#tutorials)
2. [How-To Guides](#how-to-guides)
3. [Quick Start Path](#quick-start-path)
4. [Advanced Topics](#advanced-topics)

---

## Tutorials

### Getting Started
- **[Prerequisites to Get Started with Robot Framework](Tutorials/prereqs_to_get_started_with_robotframework.md)** - Essential setup requirements and installation guide

### End-to-End Workflows
- **[Pipeline Execution End-to-End Flow](Tutorials/pipeline_execution_end_end_flow.md)** - Complete walkthrough of pipeline execution from start to finish

---

## How-To Guides

### Infrastructure and Setup
- **[Infrastructure Setup](How%20To%20Guides/Infrastructure_setup.md)** - Complete infrastructure setup and configuration guide

### Docker and Container Management
- **[Docker Compose Guide](How%20To%20Guides/docker_compose_guide.md)** - Comprehensive guide to Docker Compose usage in the framework
- **[Groundplex Launch Guide](How%20To%20Guides/groundplex_launch_guide.md)** - Complete setup, configuration, and troubleshooting for SnapLogic Groundplex

### Service Configuration
- **[MinIO Setup Guide](How%20To%20Guides/minio_setup_guide.md)** - MinIO configuration as S3 mock server for SnapLogic S3 snap testing

### Test Framework and Execution
- **[Robot Framework Test Execution Flow](How%20To%20Guides/robot_framework_test_execution_flow.md)** - Detailed explanation of test execution process and initialization
- **[Robot Framework Make Commands](How%20To%20Guides/robot_framework_tests_make_commands.md)** - Complete guide to make commands for test execution

### Libraries and Dependencies
- **[SnapLogic Common Robot Library Guide](How%20To%20Guides/snaplogic_common_robot_library_guide.md)** - Overview of the SnapLogic common robot library and its dependencies

---

## Quick Start Path

For new users, follow this recommended reading order:

### 1. Prerequisites and Setup
1. [Prerequisites to Get Started with Robot Framework](Tutorials/prereqs_to_get_started_with_robotframework.md)
2. [Infrastructure Setup](How%20To%20Guides/Infrastructure_setup.md)

### 2. Understanding the Framework
3. [Docker Compose Guide](How%20To%20Guides/docker_compose_guide.md)
4. [Robot Framework Test Execution Flow](How%20To%20Guides/robot_framework_test_execution_flow.md)

### 3. Service Configuration
5. [Groundplex Launch Guide](How%20To%20Guides/groundplex_launch_guide.md)
6. [MinIO Setup Guide](How%20To%20Guides/minio_setup_guide.md)

### 4. Test Execution
7. [Robot Framework Make Commands](How%20To%20Guides/robot_framework_tests_make_commands.md)
8. [Pipeline Execution End-to-End Flow](Tutorials/pipeline_execution_end_end_flow.md)

### 5. Advanced Topics
9. [SnapLogic Common Robot Library Guide](How%20To%20Guides/snaplogic_common_robot_library_guide.md)

---

## Advanced Topics

### Infrastructure Deep Dive
- **[Docker Compose Guide](How%20To%20Guides/docker_compose_guide.md)** - Advanced Docker configurations and troubleshooting
- **[Groundplex Launch Guide](How%20To%20Guides/groundplex_launch_guide.md)** - Advanced Groundplex configurations and monitoring

### Development and Customization
- **[SnapLogic Common Robot Library Guide](How%20To%20Guides/snaplogic_common_robot_library_guide.md)** - Library exploration and custom development
- **[Robot Framework Test Execution Flow](How%20To%20Guides/robot_framework_test_execution_flow.md)** - Understanding framework internals

### Testing Strategies
- **[MinIO Setup Guide](How%20To%20Guides/minio_setup_guide.md)** - Mock services and testing strategies
- **[Pipeline Execution End-to-End Flow](Tutorials/pipeline_execution_end_end_flow.md)** - Complete testing workflows

---

## Document Categories

### Setup and Installation
- Infrastructure Setup
- Prerequisites Guide
- Docker Compose Guide

### Service Configuration
- Groundplex Launch Guide
- MinIO Setup Guide

### Testing and Execution
- Robot Framework Test Execution Flow
- Robot Framework Make Commands
- Pipeline Execution End-to-End Flow

### Libraries and Tools
- SnapLogic Common Robot Library Guide

---

## Quick Reference Links

### Essential Commands
- See [Robot Framework Make Commands](How%20To%20Guides/robot_framework_tests_make_commands.md) for all available make commands

### Troubleshooting
- **Docker Issues**: [Docker Compose Guide](How%20To%20Guides/docker_compose_guide.md#troubleshooting-guide)
- **Groundplex Issues**: [Groundplex Launch Guide](How%20To%20Guides/groundplex_launch_guide.md#troubleshooting-guide)
- **MinIO Issues**: [MinIO Setup Guide](How%20To%20Guides/minio_setup_guide.md#troubleshooting)

### Configuration Files
- **Environment Variables**: [Infrastructure Setup](How%20To%20Guides/Infrastructure_setup.md)
- **Docker Compose**: [Docker Compose Guide](How%20To%20Guides/docker_compose_guide.md)
- **Test Configuration**: [Robot Framework Test Execution Flow](How%20To%20Guides/robot_framework_test_execution_flow.md)

---

## Contributing

When adding new documentation:

1. Place **How-To Guides** in the `How To Guides/` directory
2. Place **Tutorials** in the `Tutorials/` directory  
3. Update this reference document with links to new content
4. Follow the established naming convention: `snake_case.md`

---

## Support

For questions or issues with any of these guides:

1. Check the troubleshooting sections in relevant guides
2. Review the complete workflow in [Pipeline Execution End-to-End Flow](Tutorials/pipeline_execution_end_end_flow.md)
3. Ensure all prerequisites from [Prerequisites Guide](Tutorials/prereqs_to_get_started_with_robotframework.md) are met

---

*This reference guide provides navigation to all documentation in the SnapLogic Test Automation Framework. Use the links above to access detailed guides for each component and workflow.*