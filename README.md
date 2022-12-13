# test-issue-creation

- Make some changes and raise PR
- Once the PR build is completed and reviewed, merge the PR
- After PR merge, an issue is created with list of all the commits from the last release tag
- If an issue already exists, then it is closed and a new one is created
- All the contributors are notified in slack. This is yet to be implemented
- The contributors have to sign off their changes in the issue by commenting as "<7 digit commit SHA> done"
- The releaser can start the prod deployment once all the sign off is completed
- The release has to comment in the issue as "Create Release" to start the process
- A draft release tag is created
- The releaser can publish the draft release to kick start the concourse deployment
- Once the deployment is completed, the issue can be closed
- Testing again