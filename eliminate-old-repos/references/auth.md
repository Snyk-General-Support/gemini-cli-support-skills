## Authentication

These scripts use the GitHub REST API via `curl`.

### Token environment variables

- Prefer `GITHUB_TOKEN`
- Fallback: `GH_TOKEN`

### Required permissions

The token must be authorized to delete repositories in the target org.

- **Classic PAT**: needs `delete_repo`
- **Fine-grained PAT**: needs repository administration permissions for the repos being deleted (and access to the org / repos in scope)

### API endpoint

- List repos: `GET /orgs/{org}/repos`
- Delete repo: `DELETE /repos/{owner}/{repo}`
