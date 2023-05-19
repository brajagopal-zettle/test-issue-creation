#!/bin/bash

export PRE_RELEASE_TITLE="[deploy] Release v"
export CLOSE_ISSUE_COMMENT="I'm closing this issue to create a new one."

issue_steps=$(cat <<-EOM
<br/><br/>
## Steps

- [ ] Wait for sign-off by all contributors
- [ ] Start `prod` deployment by publishing the `prerelease` Release tag to trigger the CirceCI deployment.
- [ ] Monitor the logs in splunk
- [ ] Post text descriptions (not the raw commit log), including a link to this issue to Slack #release-info
- [ ] Close this Issue

## Abort

In case of any issue with `prod` deployment or want to abort this release process, please close this issue to unlock the master branch
so that further pull request can be merged.

EOM
)

# Fetch the current open issue that was created before.
# Ideally this case should not happen since the issue either would have been closed after release or not created at all.
# This is fail safe where some body rerun the Release Process workflow again then existing issue will be closed and new one will be opened

# Get the current issues for release and delete them all.
current_issue=$(gh api -H "Accept: application/vnd.github+json" /repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/issues | jq -r "[ .[] | select( .state | contains(\"open\")) | select( .title | contains(\"$PRE_RELEASE_TITLE\"))] | .[].number")

if [[ -n $current_issue ]]; then
     printf '%s\n' "$current_issue" |
      for issue in $current_issue
        do
          echo "Closing current issue=$issue"
          gh issue close "$issue" -c "$CLOSE_ISSUE_COMMENT"
      done
fi

# Fetch the latest Pre Release tag
pre_release_tag=$(gh api "/repos/$REPO_OWNER/$PROJECT_REPONAME/releases" | jq --arg PRE_RELEASE_TITLE "$PRE_RELEASE_TITLE" -r '.[] | select(.prerelease) | select(.name | startswith($PRE_RELEASE_TITLE))')

# Fetch name and body of the Pre Release tag
issue_name=$(echo "$pre_release_tag" | jq -r '.name')
issue_body=$(echo "$pre_release_tag" | jq -r '.body')
issue_body+=$issue_steps

gh issue create --title "$issue_name" --body "$issue_body"
