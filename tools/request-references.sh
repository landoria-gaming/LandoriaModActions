#!/usr/bin/env bash
set -euo pipefail
repository=${1:?Reference repository required}
[[ -n "${GH_TOKEN:-}" ]] || { echo 'Configure MOD_REFERENCES_TOKEN with Actions: write on LandoriaModReferences only.' >&2; exit 1; }
[[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid reference repository.' >&2; exit 1; }
dispatch=$(gh api --method POST -H 'X-GitHub-Api-Version: 2026-03-10' "repos/$repository/actions/workflows/update-references.yml/dispatches" -f ref=main)
run_id=$(jq -er '.workflow_run_id | numbers' <<< "$dispatch" | tr -d '\r')
[[ "$run_id" =~ ^[0-9]+$ ]] || exit 1
deadline=$(( $(date +%s) + ${REFERENCE_TIMEOUT_SECONDS:-3300} ))
while true; do
  run=$(gh api "repos/$repository/actions/runs/$run_id")
  jq -e '.head_branch == "main" and .event == "workflow_dispatch"' <<< "$run" >/dev/null
  if [[ $(jq -r '.status' <<< "$run" | tr -d '\r') == completed ]]; then
    if ! jq -e '.conclusion == "success"' <<< "$run" >/dev/null; then
      jq -r '"Reference update failed (\(.conclusion)): \(.html_url)"' <<< "$run" >&2; exit 1
    fi
    artifacts=$(gh api "repos/$repository/actions/runs/$run_id/artifacts")
    jq -e '[.artifacts[] | select(.name == "mod-compilation-references" and .expired == false)] | length == 1' <<< "$artifacts" >/dev/null
    printf 'run-id=%s\n' "$run_id" >> "$GITHUB_OUTPUT"
    break
  fi
  (( $(date +%s) < deadline )) || { echo "Timed out waiting for reference run $run_id" >&2; exit 1; }
  sleep 15
done
