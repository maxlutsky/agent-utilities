---
name: pr-message
description: Generate pull request (PR) descriptions and review checklists using the team's PR template. Use when asked to create or update a PR message, draft a PR description, or fill a PR template for a change set.
---

# PR Message

Generate a PR description that fills the provided template. Keep the tone concise and engineering-focused.

## Inputs to Gather

- PR type and brief summary for the title line (e.g., `Feature`, `Fix`, `Chore`).
- Related ticket link and key (if missing, write `N/A`).
- Base branch to compare against (ask for it if not provided).
- Summary of changes (what + why).
- Technical details that are worth calling out.
- Test steps, expected behavior, and any media.
- Optional notes for reviewers.

If any of the above is missing, ask concise follow-up questions. If a ticket is not provided, write `N/A`.

## Workflow

1. Determine the current branch and base branch:
   - Run `git rev-parse --abbrev-ref HEAD` to get the current branch.
   - Ask the user for the base branch if not provided (e.g., `main`, `develop`, `release/x`).
2. Compute the comparison range:
   - Run `git merge-base <base> HEAD` to find the branch point.
   - Use `<merge-base>..HEAD` for commit and diff summaries.
3. Collect change context:
   - `git log --oneline <merge-base>..HEAD` for a concise commit list.
   - `git diff --stat <merge-base>..HEAD` for scope.
   - If needed, `git diff <merge-base>..HEAD` for details.
4. Derive the PR summary:
   - “What was done” from commit messages + diff summary.
   - “Why it was done” from user notes; if missing, ask.
5. Fill the template precisely.
6. Keep placeholders only when information is unknown and you are waiting on user input.

## Output Template

Always emit the PR description in this exact structure:

```markdown
# [Type]: Brief Description of Changes (e.g., [Feature]: Added User Profile Screen)

**Related Issue/Ticket:** Link to Jira/Asana/Trello ticket, e.g., [PROJECT-123]

**Estimated Review Time**: 5-10 minutes

---

### Description of Changes

* **What was done:**
    * *Clearly and concisely describe the main changes.*
* **Why it was done:**
    * *Explain the problem this PR solves or the new functionality it adds.*

---

### Technical Details

* [Any technical details]

---

### How to Test

* **Steps to reproduce:**
    1.  *Step 1.*
    2.  *Step 2.*
* **Expected behavior:**
    * *Describe what should happen after following the steps.*
* **Screenshots / Video (if applicable):**
    * [Add links or screenshots here]

---

### Pre-Merge Checklist
* [ ] Code adheres to our **Coding Guidelines**.
* [ ] New/changed features are covered by tests (if applicable).
* [ ] All existing tests pass successfully.
* [ ] No new **warnings** in Xcode.
* [ ] Changes tested on a physical device.

---

### Optional Notes

* [Any additional comments, questions for the reviewer, etc.]

### How to review
```

## Notes

- If the base branch does not exist locally, ask the user to provide the correct branch name.
- Do not invent ticket links or testing steps; ask if missing.
