#!/usr/bin/env bash
# Prepare a signed release in a branch/PR, then publish after the PR is merged.
#
#   git switch -c release/1.4.50 main
#   ./Scripts/release.sh 1.4.50 -m "recording split button"
#   # Merge the PR, update local main, then:
#   ./Scripts/release.sh publish 1.4.50
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NEW=""
MODE="prepare"
SUMMARY=""
NOTES_TEXT=""
NOTES_FILE=""
NO_PUSH=0

if [[ "${1:-}" == "publish" ]]; then
  MODE="publish"
  shift
fi

usage() {
  cat <<'EOF'
Usage: Scripts/release.sh <version> -m <summary> [--notes <text> | --notes-file <path>] [--no-push]
       Scripts/release.sh publish <version> [--notes <text> | --notes-file <path>]

Prepare must run on a clean release/<version> branch based on main. It bumps
version files, builds and notarizes assets, commits, pushes the branch, and
opens a PR. Publish runs on clean, up-to-date main after that PR is merged;
it verifies the assets, pushes a tag, and creates the GitHub release.

  -m, --message     One-line summary (commit, ARCHITECTURE row, default notes)
  --notes           GitHub release body (markdown)
  --notes-file      Read release body from a file
  --no-push         Prepare and commit locally; do not push or open a PR
  -h, --help

The working tree must be clean. Requires xcodegen, gh,
a Developer ID Application certificate, and notarytool credentials. See
BUILD_AND_DEPLOY.md.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message)
      SUMMARY="${2:-}"
      shift 2
      ;;
    --notes)
      NOTES_TEXT="${2:-}"
      shift 2
      ;;
    --notes-file)
      NOTES_FILE="${2:-}"
      shift 2
      ;;
    --no-push)
      NO_PUSH=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "error: unknown option: $1 (try --help)" >&2
      exit 1
      ;;
    *)
      if [[ -n "$NEW" ]]; then
        echo "error: unexpected argument: $1" >&2
        exit 1
      fi
      NEW="$1"
      shift
      ;;
  esac
done

if [[ -z "$NEW" || ( "$MODE" == "prepare" && -z "$SUMMARY" ) ]]; then
  usage >&2
  exit 1
fi
if [[ ! "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must be X.Y.Z (got $NEW)" >&2
  exit 1
fi
if [[ "$SUMMARY" == *"|"* ]]; then
  echo "error: -m summary cannot contain | (ARCHITECTURE table row)" >&2
  exit 1
fi
if [[ "$MODE" == "publish" && "$NO_PUSH" -eq 1 ]]; then
  echo "error: --no-push is only valid while preparing a release" >&2
  exit 1
fi
if [[ -n "$NOTES_TEXT" && -n "$NOTES_FILE" ]]; then
  echo "error: use only one of --notes or --notes-file" >&2
  exit 1
fi
if [[ -n "$NOTES_FILE" ]]; then
  NOTES_TEXT="$(cat "$NOTES_FILE")"
fi
if [[ -z "$NOTES_TEXT" && "$MODE" == "prepare" ]]; then
  NOTES_TEXT="$(printf '## What’s new\n\n- %s\n' "$SUMMARY")"
fi

escape_re() {
  printf '%s' "$1" | sed 's/[.[\*^$()+?{|]/\\&/g'
}

plist_get() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$2"
}

yml_values() {
  local key="$1"
  grep -E "^[[:space:]]*${key}:" project.yml | sed -E "s/.*${key}:[[:space:]]*\"?([^\"]+)\"?.*/\1/"
}

OLD="$(plist_get CFBundleShortVersionString Resources/Info.plist)"
OLD_BUILD="$(plist_get CFBundleVersion Resources/Info.plist)"

require_yml() {
  local key="$1" expect="$2" got n=0
  while IFS= read -r got; do
    n=$((n + 1))
    if [[ "$got" != "$expect" ]]; then
      echo "error: project.yml ${key}=${got} (expected ${expect})" >&2
      exit 1
    fi
  done < <(yml_values "$key")
  if [[ "$n" -ne 2 ]]; then
    echo "error: expected two ${key} entries in project.yml (got ${n})" >&2
    exit 1
  fi
}
require_yml MARKETING_VERSION "$OLD"
require_yml CURRENT_PROJECT_VERSION "$OLD_BUILD"

CASK_VER="$(sed -n 's/^  version "\([^"]*\)"/\1/p' Casks/lockmic.rb | head -1)"
if [[ "$CASK_VER" != "$OLD" ]]; then
  echo "error: Casks/lockmic.rb version $CASK_VER != Info.plist $OLD" >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is dirty; commit or stash first" >&2
  git status --porcelain >&2
  exit 1
fi
if [[ "$MODE" == "publish" ]]; then
  if [[ "$BRANCH" != "main" || "$OLD" != "$NEW" ]]; then
    echo "error: publish requires main at version $NEW (now $BRANCH at $OLD)" >&2
    exit 1
  fi
  git fetch origin main
  if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
    echo "error: local main must match origin/main" >&2
    exit 1
  fi
  ZIP="$ROOT/build/dist/LockMic-${NEW}.zip"
  DMG="$ROOT/build/dist/LockMic-${NEW}.dmg"
  NOTES_SAVED="$ROOT/build/dist/LockMic-${NEW}-release-notes.md"
  for file in "$ZIP" "$DMG" "${ZIP}.sha256" "${DMG}.sha256"; do
    [[ -f "$file" ]] || { echo "error: missing release asset $file" >&2; exit 1; }
  done
  (cd "$ROOT/build/dist" && shasum -a 256 -c "$(basename "${ZIP}.sha256")" && shasum -a 256 -c "$(basename "${DMG}.sha256")")
  HASH="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
  CASK_HASH="$(sed -n 's/^  sha256 "\([0-9a-fA-F]*\)"/\1/p' Casks/lockmic.rb | head -1)"
  [[ "$HASH" == "$CASK_HASH" ]] || { echo "error: zip checksum differs from merged cask" >&2; exit 1; }
  if [[ -z "$NOTES_TEXT" ]]; then
    [[ -f "$NOTES_SAVED" ]] || { echo "error: pass --notes-file or restore $NOTES_SAVED" >&2; exit 1; }
    NOTES_TEXT="$(cat "$NOTES_SAVED")"
  fi
  LOCAL_TAG="$(git rev-parse --verify "refs/tags/v${NEW}^{commit}" 2>/dev/null || true)"
  REMOTE_TAG="$(git ls-remote --tags origin "refs/tags/v${NEW}" | awk '{print $1}')"
  if [[ -n "$LOCAL_TAG" && "$LOCAL_TAG" != "$(git rev-parse HEAD)" ]]; then
    echo "error: local tag v${NEW} points to another commit" >&2
    exit 1
  fi
  if [[ -n "$REMOTE_TAG" && "$REMOTE_TAG" != "$(git rev-parse HEAD)" ]]; then
    echo "error: remote tag v${NEW} points to another commit" >&2
    exit 1
  fi
  gh auth status >/dev/null
  if gh release view "v${NEW}" >/dev/null 2>&1; then
    echo "error: GitHub release v${NEW} already exists" >&2
    exit 1
  fi
  if [[ -z "$LOCAL_TAG" ]]; then git tag "v${NEW}"; fi
  if [[ -z "$REMOTE_TAG" ]]; then git push origin "v${NEW}"; fi
  NOTES_TMP="$(mktemp)"
  printf '%s\n' "$NOTES_TEXT" > "$NOTES_TMP"
  gh release create "v${NEW}" --title "LockMic ${NEW}" --notes-file "$NOTES_TMP" \
    "$DMG" "${DMG}.sha256" "$ZIP" "${ZIP}.sha256"
  rm -f "$NOTES_TMP"
  echo "==> Released ${NEW}"
  exit 0
fi

if [[ "$NEW" == "$OLD" ]]; then
  echo "error: already at $NEW" >&2
  exit 1
fi
NEW_BUILD="$((OLD_BUILD + 1))"
OLD_RE="$(escape_re "$OLD")"
if [[ "$BRANCH" != "release/$NEW" ]]; then
  echo "error: prepare requires release/$NEW (now $BRANCH)" >&2
  exit 1
fi
git fetch origin main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "error: release branch must start at current origin/main" >&2
  exit 1
fi
if git rev-parse --verify --quiet "refs/tags/v${NEW}"; then
  echo "error: tag v${NEW} already exists" >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required (brew install xcodegen)" >&2
  exit 1
fi

# Fail before bumping versions if direct-distribution signing is not configured.
"$ROOT/Scripts/notarize_release.sh" --check

if [[ "$NO_PUSH" -eq 0 ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh is required to publish (brew install gh)" >&2
    exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "error: gh is not logged in (gh auth login)" >&2
    exit 1
  fi
  if gh release view "v${NEW}" >/dev/null 2>&1; then
    echo "error: GitHub release v${NEW} already exists" >&2
    exit 1
  fi
fi

echo "==> $OLD ($OLD_BUILD) → $NEW ($NEW_BUILD)"
echo "    $SUMMARY"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW" Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" Resources/Info.plist

perl -pi -e "s/MARKETING_VERSION: \"${OLD_RE}\"/MARKETING_VERSION: \"${NEW}\"/g" project.yml
perl -pi -e "s/CURRENT_PROJECT_VERSION: \"${OLD_BUILD}\"/CURRENT_PROJECT_VERSION: \"${NEW_BUILD}\"/g" project.yml

perl -pi -e "s/(\\*\\*Version:\\*\\* )[0-9]+\\.[0-9]+\\.[0-9]+/\${1}${NEW}/" README.md
perl -pi -e "s/LockMic-[0-9]+\\.[0-9]+\\.[0-9]+\\.zip/LockMic-${NEW}.zip/" README.md

perl -pi -e "s/(Current version:\\*\\* )[0-9]+\\.[0-9]+\\.[0-9]+/\${1}${NEW}/" ARCHITECTURE.md
if ! grep -qF "| **${NEW}** |" ARCHITECTURE.md; then
  # Insert after the last numeric phase-map row (before the trailing HB-2 / Pro rows).
  awk -v ver="$NEW" -v msg="$SUMMARY" '
    NR > 1 {
      print prev
      if (prev ~ /^\| \*\*[0-9]/ && $0 !~ /^\| \*\*[0-9]/ && !done) {
        print "| **" ver "** | " msg " | Done |"
        done = 1
      }
    }
    { prev = $0 }
    END { if (prev != "") print prev }
  ' ARCHITECTURE.md > ARCHITECTURE.md.tmp
  mv ARCHITECTURE.md.tmp ARCHITECTURE.md
fi

perl -pi -e "s/${OLD_RE}/${NEW}/g" website/public/index.html website/public/llms.txt

perl -pi -e "s/^  version \"${OLD_RE}\"/  version \"${NEW}\"/" Casks/lockmic.rb
perl -pi -e "s/LockMic-${OLD_RE}\\.zip/LockMic-${NEW}.zip/g" Casks/lockmic.rb

echo "==> Building Release"
"$ROOT/Scripts/build_homebrew.sh"
APP_PLIST="$ROOT/build/LockMic.app/Contents/Info.plist"
GOT_VER="$(plist_get CFBundleShortVersionString "$APP_PLIST")"
GOT_BUILD="$(plist_get CFBundleVersion "$APP_PLIST")"
if [[ "$GOT_VER" != "$NEW" || "$GOT_BUILD" != "$NEW_BUILD" ]]; then
  echo "error: built app is $GOT_VER ($GOT_BUILD), expected $NEW ($NEW_BUILD)" >&2
  exit 1
fi

echo "==> Developer ID signing and app notarization"
"$ROOT/Scripts/notarize_release.sh" --app "$ROOT/build/LockMic.app"

echo "==> Packaging"
"$ROOT/Scripts/package_dmg.sh"
ZIP="$ROOT/build/dist/LockMic-${NEW}.zip"
DMG="$ROOT/build/dist/LockMic-${NEW}.dmg"
for f in "$ZIP" "$DMG" "${ZIP}.sha256" "${DMG}.sha256"; do
  if [[ ! -f "$f" ]]; then
    echo "error: missing $f" >&2
    exit 1
  fi
done

echo "==> DMG notarization"
"$ROOT/Scripts/notarize_release.sh" --dmg "$DMG"
shasum -a 256 "$DMG" > "${DMG}.sha256"
HASH="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
perl -pi -e "s/^  sha256 \"[0-9a-fA-F]{64}\"/  sha256 \"${HASH}\"/" Casks/lockmic.rb

echo "==> Checking leftover ${OLD}"
stale=0
for f in \
  Resources/Info.plist \
  project.yml \
  README.md \
  Casks/lockmic.rb \
  website/public/index.html \
  website/public/llms.txt
do
  if grep -n -F "$OLD" "$f"; then
    echo "error: $f still mentions $OLD" >&2
    stale=1
  fi
  if ! grep -q -F "$NEW" "$f"; then
    echo "error: $f does not mention $NEW" >&2
    stale=1
  fi
done
if ! grep -q -F "Current version:** ${NEW}" ARCHITECTURE.md; then
  echo "error: ARCHITECTURE.md header was not bumped" >&2
  stale=1
fi
if [[ "$stale" -ne 0 ]]; then
  exit 1
fi

git add \
  Resources/Info.plist \
  project.yml \
  LockMic.xcodeproj/project.pbxproj \
  README.md \
  ARCHITECTURE.md \
  website/public/index.html \
  website/public/llms.txt \
  Casks/lockmic.rb

if [[ -z "$(git diff --cached --name-only)" ]]; then
  echo "error: nothing to commit after bump" >&2
  exit 1
fi

git commit -m "Prepare ${NEW}: ${SUMMARY}"
printf '%s\n' "$NOTES_TEXT" > "$ROOT/build/dist/LockMic-${NEW}-release-notes.md"
echo "==> Committed release preparation for ${NEW}"

if [[ "$NO_PUSH" -eq 1 ]]; then
  echo "    --no-push: push $BRANCH and open a PR before publishing"
  exit 0
fi

echo "==> Pushing $BRANCH and opening PR"
git push -u origin "$BRANCH"
PR_BODY="$(mktemp)"
printf 'Release %s: %s\n\nSigned and notarized assets are staged locally in `build/dist/`. After merge, run `./Scripts/release.sh publish %s` on updated main from this machine.\n' "$NEW" "$SUMMARY" "$NEW" > "$PR_BODY"
gh pr create --base main --head "$BRANCH" --title "Release ${NEW}: ${SUMMARY}" --body-file "$PR_BODY"
rm -f "$PR_BODY"
echo "==> Merge the PR, update main, then run: ./Scripts/release.sh publish ${NEW}"
