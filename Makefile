# Makefile for Cookiecutter Template Repository
# Root-level makefile for managing the cookiecutter template

# The actual template directory name (with curly braces)
TEMPLATE_DIR = \{\{cookiecutter.project_name\}\}
OUTPUT_DIR ?= ..

.PHONY: change-dir help generate-project

# Default help target
help:
	@echo "📦 Cookiecutter Template Management"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Available targets:"
	@echo "  make change-dir        - Use with: eval \$(make change-dir)"
	@echo "  make generate-project  - Generate a new project from template"
	@echo ""
	@echo "Change to template directory:"
	@echo "  eval \$(make change-dir)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Navigate to cookiecutter template directory
# Usage: eval $(make change-dir)
change-dir:
	@echo "cd $(TEMPLATE_DIR)"

# -----------------------------------------------------------------------------
# Generate a new project from this template
# -----------------------------------------------------------------------------
# Description:
#   Creates a new project from the cookiecutter template
#
# Parameters:
#   OUTPUT_DIR - Directory where the project will be created (default: ..)
#
# Usage Examples:
#   make generate-project
#   make generate-project OUTPUT_DIR=.
#   make generate-project OUTPUT_DIR=/Users/spothana/Projects
#   make generate-project OUTPUT_DIR=~/QADocs
# -----------------------------------------------------------------------------
generate-project:
	@echo "🔨 Generating project from cookiecutter template..."
	@echo "📁 Output directory (relative): $(OUTPUT_DIR)"
	@mkdir -p $(OUTPUT_DIR)
	@echo "📂 Output directory (absolute): $$(cd $(OUTPUT_DIR) && pwd)"
	@cookiecutter . -o $(OUTPUT_DIR)
