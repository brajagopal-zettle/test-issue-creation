#!/bin/bash

getList() {
  signOff=("<details>")
  commentsBody=$(gh api -H "Accept: application/vnd.github+json" /repos/brajagopal-zettle/test-issue-creation/issues/15/comments | jq -r ".[].body + \",\"")

  while IFS=',' read -ra ADDR;
  do
    for i in "${ADDR[@]}";
    do
      signOff+=("$i appended")
      echo
    done
  done <<< "$commentsBody"
  echo "${signOff[@]}"
  printf "\n </details>"
}

test=$(getList)
echo "${test[@]}"

