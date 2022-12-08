#!/bin/bash

commentsBody=$(gh api -H "Accept: application/vnd.github+json" /repos/brajagopal-zettle/test-issue-creation/issues/15/comments | jq -r ".[].body + \",\"")

echo "$commentsBody"

while IFS=',' read -ra ADDR;
do
  for i in "${ADDR[@]}";
  do
    echo "$i"
  done
done <<< "$commentsBody"

