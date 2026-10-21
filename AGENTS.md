# Repository workflow

- Make every repository change on a branch created from the current `main`.
- Push the branch and open a pull request targeting `main`.
- Merge changes into `main` only through a pull request. Do not commit or push directly to `main`.
- Apply this rule to code, documentation, configuration, and release/version changes.
- Prepare releases on a `release/X.Y.Z` branch with `Scripts/release.sh X.Y.Z -m "summary"`. Merge its PR before running `Scripts/release.sh publish X.Y.Z` on updated `main`.
