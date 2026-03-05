# False Negative (FN) Patterns in Snyk Code

This reference documents common scenarios where Snyk Code might miss a vulnerability (False Negative). Use these patterns to identify missed findings.

## Common FN Scenarios

### 1. Complex Data Flow
- **Pattern**: Data passes through complex transformations (e.g., custom serialization, complex objects, non-standard event emitters) that Snyk cannot trace.
- **Validation**: Manually trace input from source to sink.

### 2. Use of Obscure Libraries
- **Pattern**: Findings in a library that Snyk doesn't yet support or have rules for.
- **Validation**: Check if the library has a history of vulnerabilities or performs sensitive operations.

### 3. Missing Source or Sink Definitions
- **Pattern**: Snyk lacks a definition for a specific framework's source (input) or sink (dangerous function).
- **Validation**: Verify if the framework is supported and if custom rules are needed.

### 4. Logic Flaws
- **Pattern**: Snyk Code focuses on data flow, so it may miss logic flaws like improper authorization checks or business logic errors.
- **Validation**: Analyze code for missing checks, privilege escalation, etc.

## How to Identify Missed Findings

- **Compare with Other Tools**: If another SAST tool reports a finding but Snyk doesn't, investigate why.
- **Contextual Knowledge**: Use your knowledge of the application's sensitive data and operations to identify high-risk areas.
- **Dynamic Analysis**: If a DAST scan or manual pentest reveals a vulnerability, trace it back to the code to see if Snyk missed it.
