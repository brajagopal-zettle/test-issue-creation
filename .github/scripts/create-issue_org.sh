#!/bin/bash

export RELEASE_ISSUE_TITLE="[Release]"
export CLOSE_ISSUE_COMMENT="I'm closing this issue to create a new one."
export SIGN_OFF_SUFFIX="done"
export START_RELEASE_TAG_COMMENT="Create Release"

# Template for the body of the Issue
getIssueBody() {
    issue_body=$(cat <<-EOM
# This is a production release.
<details>
<summary>CHANGELOG $changelog_summary_title</summary>

$changelog_recent

</details>

## Steps

- [ ] Check the progress of the test deployment in concourse and wait until it is done
- [ ] Wait for sign-off by all contributors
  - All commits in the above Changelog must be signed off.
  - Sign off is done when a contributor comment in the issue with pattern: **\"<7 digit commit SHA> $SIGN_OFF_SUFFIX\"**
  - One comment per commit without line breaks.
- [ ] Comment as **"$START_RELEASE_TAG_COMMENT"** in the issue to start the release process
- [ ] Publish the draft release created to initiate the concourse prod deployment
- [ ] Check the progress of the prod deployment in concourse and wait until it is done
- [ ] Post text descriptions (not the raw commit log), including a link to this issue to Slack #release-info
- [ ] Close this Issue


## Rollback

If after deployment you observe multiple errors in the API you should rollback as soon as possible. Do not wait for the author of the change to fix it - rollback the release and then investigate and fix it.
In case you need to rollback please follow the Concourse rollback instructions [here](https://github.com/iZettle/platform-services/blob/main/deploy/concourse/ecs-service-deployment.md#rolling-back-and-rolling-forward)
EOM
)

    echo "$issue_body"
}

# Constructs the changelog. These are all commits from the latest release
# the current going-to-be deploy SHA.
# -----------------------------------
getChangeLogSinceLatestRelease() {
  latest_release_branch=$(gh api repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/releases/latest | jq -r '.target_commitish')

  latest_release_tag=$(gh api -H "Accept: application/vnd.github+json" /repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/releases/latest | jq -r '.tag_name')
  last_release_hash=$(gh api -H "Accept: application/vnd.github+json" /repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/git/ref/tags/"$latest_release_tag" | jq -r '.object.sha')

  if [ -z "$latest_release_branch" ] || [ "$latest_release_branch" = "null" ]; then
    # First release, empty changelog
    echo ""
  else
    changelog=$(git --no-pager log \
                --pretty='* %h %at %an %ad - %s' \
                --no-merges \
                --author-date-order \
                --date=format:'%Y-%m-%d:%H:%M:%S' \
                "$last_release_hash"..."$(git rev-parse HEAD)" | \
                sort -k2,1 --stable)
    echo "$changelog"
  fi
}

# The createIssue will add content to the Issue explain what the issue
# is about. It will add the changelog and link it to the git SHA.
# If an issue with open already exists, it will delete it
# and create a new one.
# ------------------------------------------------------------------------------
createIssue() {
    echo "Creating Issue."
    echo "-----------------------"

    changelog=$1
    total_commits=$(echo -n "$changelog" | wc -l)
    if [ "$total_commits" -eq "0" ] && [ "x$changelog" = "x" ]; then
        changelog_summary_title="(No commits, maybe it's the first time)"
    else
        changelog_summary_title="(all commits)"
    fi

    changelog_recent=$changelog

    # Get the current issues for release and delete them all.
    current_issue=$(gh api -H "Accept: application/vnd.github+json" /repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/issues | jq -r "[ .[] | select( .state | contains(\"open\")) | select( .title | contains(\"$RELEASE_ISSUE_TITLE\"))] | .[].number")

    echo "$current_issue"
    # Delete all the drafted release issues
    if [[ -n $current_issue ]]; then
       printf '%s\n' "$current_issue" |
        for issue in $current_issue
          do
            echo "Closing current issue=$issue"
            gh issue close "$issue" -c "$CLOSE_ISSUE_COMMENT"
        done

    fi

    issue_body=$(getIssueBody)
    gh issue create --title "$RELEASE_ISSUE_TITLE v$(date +%Y%m%d%H%M)" \
                    --body "$issue_body"
}


# Main entry point
# ----------------
echo "Starting the create issue script"
set -x
changelog=$(getChangeLogSinceLatestRelease)
createIssue "$changelog"
set +x
echo "Done!"
