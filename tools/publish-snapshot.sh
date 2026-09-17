#!/usr/bin/env bash
set -euo pipefail
[[ "$GITHUB_REF" == refs/heads/main && ( "$GITHUB_EVENT_NAME" == push || "$GITHUB_EVENT_NAME" == workflow_dispatch ) ]] || exit 1
[[ "$MOD_NAME" =~ ^[A-Za-z0-9_.-]+$ && "$PACKAGE_NAME" =~ ^[A-Za-z0-9_]+$ ]] || exit 1
main=$(gh api "repos/$GH_REPO/git/ref/heads/main" --jq '.object.sha' | tr -d '\r')
if [[ "$main" != "$GITHUB_SHA" ]]; then
  echo 'Snapshot release skipped: commit is no longer the main head.' >> "$GITHUB_STEP_SUMMARY"; exit 0
fi
shopt -s nullglob
packages=(thunderstore/*.zip)
[[ ${#packages[@]} -eq 1 ]] || { echo 'Expected exactly one Thunderstore ZIP.' >&2; exit 1; }
mkdir -p release
version=$(jq -r '.version_number' snapshot/manifest.json | tr -d '\r')
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-snapshot$ ]] || exit 1
thunderstore="Landoria-$PACKAGE_NAME-$version.zip"
cp "${packages[0]}" "release/$thunderstore"
printf 'Latest development snapshot from main. Replaced after each successful snapshot build.\n\nVersion: %s\nCommit: %s\nBuild: %s/%s/actions/runs/%s\n' \
  "$version" "$GITHUB_SHA" "$GITHUB_SERVER_URL" "$GH_REPO" "$GITHUB_RUN_ID" > release/notes.md
if gh api "repos/$GH_REPO/git/ref/tags/snapshot" --silent 2>/dev/null; then
  gh api --method PATCH "repos/$GH_REPO/git/refs/tags/snapshot" -f "sha=$GITHUB_SHA" -F force=true --silent
else
  gh api --method POST "repos/$GH_REPO/git/refs" -f ref=refs/tags/snapshot -f "sha=$GITHUB_SHA" --silent
fi
if gh release view snapshot --json id >/dev/null 2>&1; then
  gh release edit snapshot --title Snapshot --notes-file release/notes.md --prerelease --latest=false
else
  gh release create snapshot --verify-tag --title Snapshot --notes-file release/notes.md --prerelease --latest=false
fi
gh release upload snapshot "release/$thunderstore" --clobber
assets=$(gh release view snapshot --json assets)
while IFS= read -r name; do
  name=${name//$'\r'/}
  [[ "$name" == "$thunderstore" ]] || gh release delete-asset snapshot "$name" --yes
done < <(jq -r '.assets[].name' <<< "$assets")
printf 'Snapshot release: %s/%s/releases/tag/snapshot\n' "$GITHUB_SERVER_URL" "$GH_REPO" >> "$GITHUB_STEP_SUMMARY"
