#!/bin/bash

export RELEASE_TAG_PREFIX="release"
export RELEASE_TITLE_PREFIX="[deploy] Release"
export LAST_ISSUE="[Release]"
export CLOSE_ISSUE_COMMENT="I'm closing this issue to create a new one."

# Template for the body of the Issue
getIssueBody() {
    issue_body=$(cat <<-EOM
This is a production release.
<details>
<summary>CHANGELOG $changelog_summary_title</summary>

$changelog_recent

</details>
EOM
)

    echo "$issue_body"
}

# Get the latest from default branch
# ----------------------------------
getLatest() {
    git checkout "$MAIN_BRANCH" remotes/origin/"$MAIN_BRANCH"
    git pull --rebase origin "$MAIN_BRANCH"
}

# Constructs the changelog. These are all commits from the latest release
# the current going-to-be deploy SHA.
# -----------------------------------
getChangeLogSinceLatestRelease() {
  latest_release_branch=$(gh api repos/brajagopal-zettle/"$PROJECT_REPONAME"/releases/latest | jq -r '.target_commitish')

  latest_release_tag=$(gh api -H "Accept: application/vnd.github+json" /repos/brajagopal-zettle/"$PROJECT_REPONAME"/releases/latest | jq -r '.tag_name')
  last_release_hash=$(gh api -H "Accept: application/vnd.github+json" /repos/brajagopal-zettle/"$PROJECT_REPONAME"/git/ref/tags/"$latest_release_tag" | jq -r '.object.sha')

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

    # Show all commits in the changelog if the number of commits is less than 10
    # Otherwise show only the most recent.
    # If it's less than `num_recent`, then no need to post a PR comment for
    # the changelog.
    total_commits=$(echo -n "$changelog" | wc -l)
    num_recent=20
    changelog_summary_title="($num_recent most recent commits)"
    if [ "$total_commits" -eq "0" ] && [ "x$changelog" = "x" ]; then
        changelog_summary_title="(No commits, maybe it's the first time)"
        changelog_recent=$changelog
    elif [ "$total_commits" -le "$num_recent" ]; then
        changelog_summary_title="(all commits)"
        changelog_recent=$changelog
    else
        changelog_recent=$(echo "$changelog" | tail -$num_recent)
    fi

    # Get the current draft release tag and delete them all.
    current_issue=$(gh api -H "Accept: application/vnd.github+json" /repos/brajagopal-zettle/test-git-workflow/issues | jq -r "[ .[] | select( .state | contains(\"open\")) | select( .title | contains(\"$LAST_ISSUE\"))] | .[].number")

    echo "$current_issue"
    # Delete all the draft releases
    if [[ -n $current_issue ]]; then
       printf '%s\n' "$current_issue" |
        for issue in $current_issue
          do
            echo "Closing current issue=$issue"
            gh issue close "$issue" -c "$CLOSE_ISSUE_COMMENT"
        done

    fi

    issue_body=$(getIssueBody)
    gh issue create --title "$LAST_ISSUE v$(date +%Y%m%d%H%M)" \
                    --body "$issue_body"
}


# Main entry point
# ----------------
# validate
#getLatest
set -x
changelog=$(getChangeLogSinceLatestRelease)
createIssue "$changelog"
set +x
echo "Done!"