---
name: snyk-code-analysis
description: Analyze Snyk Code and Open Source scan results to validate findings. Use when Gemini CLI needs to determine if a Snyk vulnerability is a false positive (FP) or false negative (FN) by analyzing the source code context, data flow, and sink locations.
---

# Snyk Code Analysis

## Overview

This skill enables Gemini CLI to analyze Snyk Code and Open Source scan results to validate findings. It focuses on identifying false positives (FP) and false negatives (FN) by examining the source code context, data flow, and potential sinks.

## Workflow

To validate a Snyk finding, follow these steps:

1. **Case Setup**:
   - Ask the user for the **case number**.
   - Use `scripts/setup_case.sh <case_number>` to create the case directory under `~/Documents/Snyk/customers/`.
   - All subsequent analysis and results should be stored in this directory.
2. **Locate Finding**: Identify the target finding by its Issue ID, CWE, file path, and line number.
3. **Context Analysis**: Examine the code surrounding the finding to understand the data flow and potential for vulnerability.
4. **Trace Data Flow**: Trace the input from its source to its sink, looking for sanitizers, validators, or complex transformations.
5. **Consult FP/FN Patterns**:
   - Refer to [fp_patterns.md](references/fp_patterns.md) for common false positive scenarios.
   - Refer to [fn_patterns.md](references/fn_patterns.md) for scenarios where a vulnerability might be missed.
6. **Generate Report**: Provide a validation report that includes:
   - **Finding Details**: ID, CWE, File, Line.
   - **Validation Result**: Legitimate vs. False Positive/Negative.
   - **Reasoning**: Detailed explanation based on code analysis and referenced patterns.
   - **Recommendation**: Suggested remediation or why the finding can be ignored.

## Resources

### scripts/

- `setup_case.sh`: Creates a case directory under `~/Documents/Snyk/customers/`.
- `run_snyk_code.sh`: Runs Snyk Code test and outputs JSON for analysis.

### references/

- `fp_patterns.md`: Common patterns for identifying false positives in Snyk results.
- `fn_patterns.md`: Common scenarios where Snyk might miss a vulnerability.
