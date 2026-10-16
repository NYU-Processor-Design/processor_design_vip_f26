## Project Git Workflow

### Phase 1: Assignment & Setup

1. **Claim an Issue:** Comment *“I want to work on this”* on the target issue. Multiple people can be assigned to the same issue to distribute work fairly.
2. **Fork & Invite:** One team member forks the main repository and invites the others to collaborate on that remote copy.
3. **Verify Git:** Ensure your local Git client is working:
```bash
git status

```


4. **Configure Identity:** Set your author details for commit logs (keep the quotation marks):
```bash
git config --global user.name "<Your Full Name>"
git config --global user.email "<Your Email>"

```



### Phase 2: Branching & Development

5. **Create a Feature Branch:** It is usually easiest to do this directly on GitHub before cloning.
* Use a short, descriptive name.
* Do not use spaces (use `dashes-like-this` or `camelCase`).


6. **Clone the Fork:** Clone your remote repository to your local machine. Verify the remote URL:
```bash
git remote -v

```


7. **Switch Branches:** Move to your newly created feature branch. All edits must be made here.
8. **Edit Files:** Work on your assigned task.
* *Tip:* After staging files, review your exact changes before committing:
```bash
git diff --staged

```





### Phase 3: Commits & Pushing

9. **Write Clear Commit Messages:** Messages should be concise but meaningful. A future reader should understand exactly *what* was changed and *why* just by reading the git log, without needing to check the issue tracker.
10. **Push Changes:** Push commits from your local feature branch to the shared remote fork as you complete important milestones.

### Phase 4: The Pull Request (PR)

11. **Open a PR:** Once the issue is fully resolved, issue a pull request from your fork to the main (upstream) repository.
* Click the green **Compare & pull request** button at the top of your origin repository on GitHub.
* Verify your PR routing:
* **Base repository:** upstream repo | **Base:** `main` (usually)
* **Head repository:** your origin fork | **Compare:** `<your-feature-branch>`


* **Add Context:** Give the PR a descriptive title and replace `<add description>` with a thorough breakdown of your changes.
* **Link the Issue:** Include `Fixes #N` or `Closes #N` (where `N` is the issue number) in the PR body. This ensures GitHub automatically closes the ticket when me or Hans merges the PR.



### Phase 5: Syncing & Cleanup

12. **Sync with Upstream:** Once changes are merged into the main repository, your fork will be out of sync.
* Verify you have the upstream remote added (`git remote -v`). If it is missing, add it using the original repository's HTTPS URL:
```bash
git remote add upstream <URL>

```


* Switch to your local main branch and pull the latest changes:
```bash
git pull upstream main

```


* Push these updates to your fork:
```bash
git push origin main

```




13. **Delete the Feature Branch:** Once everything is synced, safely remove the old branch.
* Delete locally (ensure you are not currently on this branch):
```bash
git branch -D <branch>

```


* Delete from the remote fork (only one team member needs to run this):
```bash
git push -d origin <branch>

```


* *Note:* Remaining team members can simply delete their local branches and pull the updated `main` branch to their local environments.



---

### Co-Authoring Commits

If two people are contributing on the same computer, ensure both get credit in the branch logs by adding the following line on its own in the commit message:

```text
Co-authored-by: Name <name@example.com>

```

*(Replace the placeholder with the contributor's actual GitHub name and email).*