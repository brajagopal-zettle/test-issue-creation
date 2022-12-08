#!/bin/bash

getListOfCommits() {
  latest_release_branch=$(gh api repos/brajagopal-zettle/"$PROJECT_REPONAME"/releases/latest | jq -r '.target_commitish')

  latest_release_tag=$(gh api -H "Accept: application/vnd.github+json" /repos/brajagopal-zettle/"$PROJECT_REPONAME"/releases/latest | jq -r '.tag_name')
  last_release_hash=$(gh api -H "Accept: application/vnd.github+json" /repos/brajagopal-zettle/"$PROJECT_REPONAME"/git/ref/tags/"$latest_release_tag" | jq -r '.object.sha')

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

checkCommitSignOff() {
  commits=$1
  commentsBody=$(gh api -H "Accept: application/vnd.github+json" /repos/brajagopal-zettle/"$PROJECT_REPONAME"/issues/"$ISSUE_NUMBER"/comments | jq -r ".[].body + \",\"")
  signOff=()

  for commit in $commits
    do
      found=false
      while IFS=',' read -ra commentArray;
      do
        for comment in "${commentArray[@]}";
        do
          if [ "$commit done" = "$(echo "$comment" | xargs )" ]; then
            found=true
            break
          fi
        done
      done <<< "$commentsBody"

      if [ "$found" = false ]; then
        signOff+=("<p>* $commit not signed off yet")
      fi
  done

  echo "${signOff[@]}"
}

createComment() {
  gh api --method POST -H "Accept: application/vnd.github+json" /repos/brajagopal-zettle/"$PROJECT_REPONAME"/issues/"$ISSUE_NUMBER"/comments -f body="$1"
}

createRelease() {
  echo "Test"
}


# Main entry point
# ----------------
echo "Starting the create release script"
set -x

commitList=$(getListOfCommits)
notSignedOffCommits=$(checkCommitSignOff "$commitList")
if [[ -n $notSignedOffCommits ]]; then
  gh api --method POST -H "Accept: application/vnd.github+json" /repos/brajagopal-zettle/"$PROJECT_REPONAME"/issues/"$ISSUE_NUMBER"/comments -f body="$notSignedOffCommits"
else
  createRelease
fi
set +x
echo "Done!"