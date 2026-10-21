# Repository workflow

- Make every repository change on a branch created from the current `main`.
- Push the branch and open a pull request targeting `main`.
- Merge changes into `main` only through a pull request. Do not commit or push directly to `main`.
- Apply this rule to code, documentation, configuration, and release/version changes.
- Before releasing, ensure the release workflow follows this rule. The current `Scripts/release.sh` commits and pushes directly to `main`, so do not use its publishing path until it is adapted for a branch and pull request.
