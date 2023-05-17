#!/bin/bash

lock_branch="$1"

# Function to get branch protection settings
get_protection_settings() {
  curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_OWNER/$PROJECT_REPONAME/branches/$MAIN_BRANCH/protection"
}

# Function to update branch protection settings
update_protection() {
  local protection_settings="$1"

  curl -X PUT "https://api.github.com/repos/$REPO_OWNER/$PROJECT_REPONAME/branches/$MAIN_BRANCH/protection" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    -d "$protection_settings"
}

# Get existing branch protection settings
existing_settings=$(get_protection_settings)

# Extract required fields from the existing settings
required_status_checks_strict=$(echo "$existing_settings" | jq -r '.required_status_checks.strict')
required_status_checks_contexts=$(echo "$existing_settings" | jq -r '.required_status_checks.contexts')
enforce_admins=$(echo "$existing_settings" | jq -r '.enforce_admins.enabled')
restrictions=$(echo "$existing_settings" | jq -r '.restrictions')
required_pull_request_reviews=$(echo "$existing_settings" | jq -r '.required_pull_request_reviews | del(.url)')

if [[ -z "${required_status_checks_strict+x}" ]]; then
  required_status_checks_strict=false
fi

if [[ -z "${required_status_checks_contexts+x}" ]]; then
  $required_status_checks_contexts=[]
fi

# Create protection settings JSON
new_settings=$(jq -n \
  --argjson strict "$required_status_checks_strict" \
  --argjson contexts "$required_status_checks_contexts" \
  --argjson enforce_admins "$enforce_admins" \
  --argjson restrictions "$restrictions" \
  --argjson required_pull_request_reviews "$required_pull_request_reviews" \
  '{
    "required_status_checks": {
      "strict": $strict,
      "contexts": $contexts
    },
    "enforce_admins": $enforce_admins,
    "restrictions": $restrictions,
    "required_pull_request_reviews": $required_pull_request_reviews
  }')

# Lock/Unlock the branch
new_settings=$(echo "$new_settings" | jq --argjson lock_branch "$lock_branch" '.lock_branch = $lock_branch')

echo "New Settings: $new_settings"

update_protection "$new_settings"

