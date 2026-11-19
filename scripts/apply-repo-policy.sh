#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-Deepnest-Commercial
#
# Apply the deepnest CLA/CI policy to one repo. Idempotent.
#   scripts/apply-repo-policy.sh <repo> [app-private-key.pem]
#
# Public repos:  label `cla-signed` + ruleset "deepnest-policy" (PR required, checks
#                "cla / cla" and "ci-required", no force push/deletion, org admins bypass).
# Private repos: label + repo-level CLA_APP_CLIENT_ID / CLA_APP_PRIVATE_KEY, because on
#                GitHub Free org secrets/variables and rulesets don't apply to private repos.
#                The key file is required then. CLA_APP_CLIENT_ID is read from the env or
#                from the org variable.
set -euo pipefail

ORG=deepnest-next
repo=${1:?usage: $0 <repo> [app-private-key.pem]}
key=${2:-}
full="$ORG/$repo"
here=$(cd "$(dirname "$0")/.." && pwd)

gh label create cla-signed --repo "$full" --force \
  --color 0e8a16 --description "All committers signed the deepnest CLA v2.0"

for wf in cla.yml ci.yml; do
  gh api "repos/$full/contents/.github/workflows/$wf" --silent 2>/dev/null ||
    echo "warning: $full has no .github/workflows/$wf (copy it from workflow-templates/)" >&2
done

visibility=$(gh repo view "$full" --json visibility -q .visibility)
if [ "$visibility" = PUBLIC ]; then
  id=$(gh api "repos/$full/rulesets" -q '.[] | select(.name == "deepnest-policy") | .id')
  if [ -n "$id" ]; then
    gh api -X PUT "repos/$full/rulesets/$id" --input "$here/rulesets/main.json" --silent
    echo "$full: ruleset deepnest-policy updated"
  else
    gh api -X POST "repos/$full/rulesets" --input "$here/rulesets/main.json" --silent
    echo "$full: ruleset deepnest-policy created"
  fi
else
  [ -n "$key" ] || { echo "error: $full is private; pass the App private key file as 2nd argument" >&2; exit 1; }
  client_id=${CLA_APP_CLIENT_ID:-$(gh variable get CLA_APP_CLIENT_ID --org "$ORG")}
  gh variable set CLA_APP_CLIENT_ID --repo "$full" --body "$client_id"
  gh secret set CLA_APP_PRIVATE_KEY --repo "$full" < "$key"
  echo "$full: private repo, App credentials set. GitHub Free has no rulesets for private repos:"
  echo "  the CLA and CI checks show red, but merging is NOT blocked."
fi
