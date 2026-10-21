# Release checklist

Use **[Scripts/release.sh](./Scripts/release.sh)**. Details: [BUILD_AND_DEPLOY.md](./BUILD_AND_DEPLOY.md).

```bash
# After product PRs are merged and main is up to date:
git switch -c release/X.Y.Z main
./Scripts/release.sh X.Y.Z -m "one-line summary"
# Merge the generated PR, then update main:
git switch main && git pull --ff-only origin main
./Scripts/release.sh publish X.Y.Z
```

```text
[ ] Product changes merged through PRs
[ ] gh auth login && brew install xcodegen gh
[ ] Prepare from clean release/X.Y.Z branch with ./Scripts/release.sh X.Y.Z -m "…"
[ ] Merge the release PR and update local main
[ ] ./Scripts/release.sh publish X.Y.Z from the machine with staged assets
[ ] GitHub release has dmg + zip + both checksums
[ ] lockmic.com heading matches X.Y.Z
[ ] brew reinstall --cask --yes lockmic && open /Applications/LockMic.app
```

Do not bump version files by hand unless the script cannot run. Public releases must be Developer ID signed and notarized.
