#!/usr/bin/env bash
# Restores the shared source targets beside the mod repository when required.
set -euo pipefail

if ! grep -q 'Landoria.CodeSnippets.targets' "$PROJECT_FILE"; then
  exit 0
fi

destination=$(cd .. && pwd)/Landoria.CodeSnippets
if [[ -f "$destination/Landoria.CodeSnippets.targets" ]]; then
  exit 0
fi

git clone --depth 1 https://github.com/landoria-gaming/Landoria.CodeSnippets.git "$destination"
