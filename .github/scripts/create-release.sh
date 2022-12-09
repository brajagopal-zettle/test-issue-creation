#!/bin/bash

export RELEASE_TITLE_PREFIX="[deploy] Release"
export RELEASE_TAG_PREFIX="release"
export SIGN_OFF_SUFFIX="done"
export ISSUE_NOT_SIGNED_OFF_COMMENT="not signed off yet. Please sign off with comment"
export RELEASE_CREATED_SUCCESS_MESSAGE="Draft Release created successfully with tag-name:"

# Template for the body of the Release
getReleaseBody() {
    release_body=$(cat <<-EOM
This is a production release.
<details>
<summary>CHANGELOG $changelog_summary_title</summary>

$changelog_recent

</details>

EOM
)

    echo "$release_body"
}

# Gets all commits from the latest release to the current merged PR
# -----------------------------------
getListOfCommits() {
  latest_release_branch=$(gh api repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/releases/latest | jq -r '.target_commitish')

  latest_release_tag=$(gh api -H "Accept: application/vnd.github+json" /repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/releases/latest | jq -r '.tag_name')
  last_release_hash=$(gh api -H "Accept: application/vnd.github+json" /repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/git/ref/tags/"$latest_release_tag" | jq -r '.object.sha')

  if [ -z "$latest_release_branch" ] || [ "$latest_release_branch" = "null" ]; then
    # First release, empty commits
    echo ""
  else
    commits=$(git --no-pager log \
                --pretty='%h' \
                --no-merges \
                --author-date-order \
                --date=format:'%Y-%m-%d:%H:%M:%S' \
                "$last_release_hash"..."$(git rev-parse HEAD)" | \
                sort -k2,1 --stable)
    echo "$commits"
  fi
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

# Fetches all the comments for the issue and
# compares if the commit is signed off.
# Pattern to compare '<7 digit Git Commit SHA> $SIGN_OFF_SUFFIX'
# When pattern is not matched, creates array with list of commits yet to be signed off otherwise empty array
# -----------------------------------
checkCommitSignOff() {
  commits=$1
  commentsBody=$(gh api -H "Accept: application/vnd.github+json" /repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/issues/"$ISSUE_NUMBER"/comments | jq -r ".[].body + \",\"")
  signOff=()

  for commit in $commits
    do
      found=false
      while IFS=',' read -ra commentArray;
      do
        for comment in "${commentArray[@]}";
        do
          if [ "$commit $SIGN_OFF_SUFFIX" = "$(echo "$comment" | xargs )" ]; then
            found=true
            break
          fi
        done
      done <<< "$commentsBody"

      if [ "$found" = false ]; then
        signOff+=("<p>* $commit $ISSUE_NOT_SIGNED_OFF_COMMENT \"$commit $SIGN_OFF_SUFFIX\"")
      fi
  done

  echo "${signOff[@]}"
}


createRelease() {
  lastCommit=$(gh api repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/commits/"$MAIN_BRANCH"| jq -r ".sha")
  changelog_recent=$(getChangeLogSinceLatestRelease)
  changelog_summary_title="(all commits)"

  current_release_tags=$(gh api repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/releases | jq -r "[ .[] | select( .name | contains(\"$RELEASE_TITLE_PREFIX\")) | select(.draft) ] | .[].tag_name")

  # Delete all the draft releases
  if [[ -n $current_release_tags ]]; then
      printf '%s\n' "$current_release_tags" |
      while IFS= read -r tag; do
          echo "Deleting draft release with tag=$tag"
          gh release delete -y "$tag"
      done
  fi

  # Generate release tag
  tag_date=$(date +%Y%m%d%H%M)
  tag_name="$RELEASE_TAG_PREFIX-$tag_date"

  echo "Creating new pre-release with name=$tag_name"
  release_body=$(getReleaseBody)
  gh release create "$tag_name" \
      --draft \
      --target "$lastCommit" \
      --title "$RELEASE_TITLE_PREFIX v$tag_date" \
      --notes "$release_body"

  gh api --method POST -H "Accept: application/vnd.github+json" /repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/issues/"$ISSUE_NUMBER"/comments -f body="$RELEASE_CREATED_SUCCESS_MESSAGE $tag_name <p> https://www.github.com/"$REPO_OWNER"/$PROJECT_REPONAME/releases/tag/$tag_name"
}


# Main entry point
# ----------------
echo "Starting the create release script"
set -x

commitList=$(getListOfCommits)
notSignedOffCommits=$(checkCommitSignOff "$commitList")
if [[ -n $notSignedOffCommits ]]; then
  # Comment the issue with commits not signed off yet.
  gh api --method POST -H "Accept: application/vnd.github+json" /repos/"$REPO_OWNER"/"$PROJECT_REPONAME"/issues/"$ISSUE_NUMBER"/comments -f body="$notSignedOffCommits"
else
  createRelease "$commitList"
fi

set +x
echo "Done!"