## Scope of reset

| Action | Included |
|--------|----------|
| Remove configure-managed `GITHUB_TOKEN` / `SNYK_TOKEN` / `SNYK_CASES_DIR` block in `~/.zprofile` or `~/.bash_profile` | Yes |
| Delete **`~/Desktop/cases`** or any files under it | **Never** (only profile exports are removed; cases folder is preserved) |
| Remove same tokens if defined elsewhere in the file (outside the block) | No |
| Unset variables in the **current** shell | No—run `source` your profile or open a new terminal |
| Delete Snyk CLI stored auth | No—use `snyk auth logout` if needed |
| Change git remotes or GitHub credentials | No |
