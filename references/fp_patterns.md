# False Positive (FP) Patterns in Snyk Code

This reference documents common scenarios where Snyk Code might report a vulnerability that is actually a false positive. Use these patterns to validate findings.

## Common FP Scenarios

### 1. Sanitized Input
- **Pattern**: Data is passed through a well-known sanitization or validation library before reaching the sink.
- **Example**: `validator.escape(user_input)` before HTML output for XSS.
- **Validation**: Check if the sanitizer is robust for the specific CWE (e.g., `parseInt` for SQLi).

### 2. Internal/Admin-Only Context
- **Pattern**: The sink is only reachable by authenticated administrators or is part of an internal-only microservice.
- **Validation**: Check the route protection (middleware like `isAuthenticated`, `isAdmin`).

### 3. Constant/Hardcoded Values
- **Pattern**: Snyk flags a variable as "tainted" but it is assigned a hardcoded string or a value from a trusted configuration file.
- **Validation**: Trace the variable assignment to its origin.

### 4. Non-Executable Code/Dead Code
- **Pattern**: The vulnerability is in a function or file that is never imported or executed in the production build.
- **Validation**: Check import graphs and build configurations.

### 5. Mock/Test Data
- **Pattern**: Findings in `test/`, `spec/`, or `__tests__` directories where "vulnerable" patterns are used intentionally for testing.
- **Validation**: Confirm the file path is excluded from production.

## Common FP Patterns by CWE

### CWE-79 (Cross-site Scripting)
- **FP if**: Using a framework that auto-escapes (like React's default behavior) and the input isn't passed to `dangerouslySetInnerHTML`.
- **FP if**: Content-Type is set to `application/json` or other non-HTML types.

### CWE-89 (SQL Injection)
- **FP if**: Using an ORM (Prisma, TypeORM) with parameterized queries, even if the query *looks* dynamic.
- **FP if**: Using `?` or named placeholders in raw SQL.

### CWE-22 (Path Traversal)
- **FP if**: Input is strictly validated against an allowlist of filenames or UUIDs.
- **FP if**: `path.basename()` is used to strip directory info.
