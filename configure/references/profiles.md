## Which profile file?

| Shell | Typical file        | Notes |
|-------|---------------------|--------|
| zsh   | `~/.zprofile`       | Loaded for **login** shells (Terminal.app default on macOS). |
| bash  | `~/.bash_profile`   | Common on macOS for login bash. |

Interactive-only zsh sessions sometimes use `~/.zshrc` only; if tokens are missing after login, the user can add the same `export` lines to `~/.zshrc` or ensure the terminal starts a login shell.

## After changing the profile

```bash
source ~/.zprofile
# or
source ~/.bash_profile
```

Or open a new terminal tab/window.

## Cases directory

Configure creates **`~/Desktop/cases`** by default and sets **`SNYK_CASES_DIR`** in the managed profile block so skills can store per-case artifacts there.
