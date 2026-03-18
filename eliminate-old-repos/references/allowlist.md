## Allowlist JSON

The allowlist file (`allowlist.json` by default) is a JSON array of repository full names (`owner/name`).

- Matching is **exact**
- Any repo listed is **excluded** from deletion

### Example

```json
[
  "snyk-code-support/do-not-delete",
  "snyk-code-support/another-repo-to-keep"
]
```
