# Test Documentation Guides

This directory contains comprehensive guides and templates for documenting Robot Framework test cases in the SnapLogic test automation framework.

---

## 📚 Available Resources

### 1. **Generic Test Case Documentation Template** 
**File**: [generic_test_case_documentation_template.md](./generic_test_case_documentation_template.md)

**Purpose**: Comprehensive guide explaining the standardized format for documenting test cases.

**Contents**:
- Complete documentation structure overview
- Detailed explanation of each section
- Best practices and guidelines
- Multiple examples and patterns
- Common pitfalls to avoid

**Use When**: 
- Creating documentation for new test cases
- Reviewing existing documentation
- Understanding documentation standards
- Training new team members

---

### 2. **Quick Reference Cheat Sheet**
**File**: [quick_reference_cheat_sheet.md](./quick_reference_cheat_sheet.md)

**Purpose**: Quick access reference for common documentation patterns and templates.

**Contents**:
- Ready-to-use documentation template
- Required vs optional sections table
- Quick checklist
- Common patterns and formats
- Pro tips

**Use When**:
- Need quick reference while writing documentation
- Want to verify documentation completeness
- Need a quick template to copy

---

## 🎯 How to Use These Guides

### For New Test Cases

1. Open [generic_test_case_documentation_template.md](./generic_test_case_documentation_template.md)
2. Read through the structure overview
3. Copy the appropriate template (template-based or non-template)
4. Fill in each section according to your test case
5. Use the checklist to verify completeness

### For Existing Test Cases

1. Open [quick_reference_cheat_sheet.md](./quick_reference_cheat_sheet.md)
2. Check the required sections checklist
3. Compare against your existing documentation
4. Add missing sections following the format examples
5. Update examples to be more practical if needed

### For Code Reviews

1. Reference the required sections table in the cheat sheet
2. Verify all required sections are present
3. Check that argument numbering is sequential
4. Ensure 3-5 usage examples are provided
5. Confirm assertions are comprehensive

---

## 📖 Documentation Structure

All test case documentation follows this structure:

```
Brief Description (Required)
  ↓
Detailed Explanation (Required)
  ↓
Prerequisites (Optional - if dependencies exist)
  ↓
Argument Details (Required - numbered sequentially)
  ↓
Returns (Optional - if test returns values)
  ↓
To Add Multiple (Optional - for template tests)
  ↓
Usage Examples (Required - 3-5 examples)
  ↓
Assertions (Required - all validations)
  ↓
Special Sections (Optional - as needed)
```

---

## 🎨 Section Icons Reference

Use these emoji icons for visual consistency:

| Icon | Section | Usage |
|------|---------|-------|
| 📋 | General Information | Prerequisites, Argument Details, Assertions, Verification Details |
| 📄 | Returns | Values returned by the test |
| 💡 | Instructions | How to add multiple records/items |
| 📝 | Examples | Usage examples section |
| 🔍 | Comparison | Comparison features |
| 📊 | Export | Export/data details |
| 📚 | Reference | Documentation reference |

---

## ✅ Documentation Standards

### Required Elements

1. **Brief Description**: Clear one-line summary
2. **Argument Details**: All parameters numbered and documented
3. **Usage Examples**: At least 3-5 practical examples
4. **Assertions**: Complete list of validations

### Best Practices

1. **Number arguments sequentially**: Argument 1, Argument 2, etc.
2. **Provide realistic examples**: Use actual variable names and values
3. **Progress from simple to complex**: Start with basic, end with advanced
4. **Be specific**: Concrete examples over abstract descriptions
5. **Stay consistent**: Use same format across all test cases
6. **Update regularly**: Keep docs in sync with code

---

## 🔍 Example Test Cases

For reference implementations of this documentation standard, see:

- **Snowflake Tests**: `test/suite/pipeline_tests/snowflake/snowflake_baseline_tests.robot`
- All test cases in this file follow the standardized documentation format

---

## 📝 Quick Start

### 1. For Writing New Documentation

```bash
# Step 1: Open the full template guide
open README/How\ To\ Guides/test_documentation_guides/generic_test_case_documentation_template.md

# Step 2: Copy the appropriate template section

# Step 3: Fill in your test case details

# Step 4: Check against the checklist
```

### 2. For Quick Reference

```bash
# Open the cheat sheet
open README/How\ To\ Guides/test_documentation_guides/quick_reference_cheat_sheet.md

# Copy the quick template

# Fill in and save
```

---

## 🤝 Contributing

When adding new test cases:

1. Follow the documentation template
2. Include all required sections
3. Provide realistic usage examples
4. Update this guide if introducing new patterns
5. Reference this guide in your test file's Settings section

---

## 📞 Support

For questions or clarifications about test documentation:

1. Review the [Generic Template Guide](./generic_test_case_documentation_template.md)
2. Check the [Quick Reference](./quick_reference_cheat_sheet.md)
3. Look at example test cases in the codebase
4. Reach out to the test automation team

---

## 🔗 Related Resources

- **Robot Framework Documentation**: https://robotframework.org/
- **SnapLogic API Keywords Guide**: ../robot_framework_guides/snaplogic_common_robot_library_guide.md
- **Test Execution Flow**: ../robot_framework_guides/robot_framework_test_execution_flow.md
- **Make Commands Guide**: ../robot_framework_guides/robot_tests_make_commands.md

---

**Location**: `README/How To Guides/test_documentation_guides/`

**Last Updated**: 2025-01-09

**Version**: 1.0
