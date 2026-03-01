---
name: pr-description-file
description: Create a Markdown pull request description file by directly analyzing git changes between the current branch and a user-provided target branch. Use when asked to generate PR description text/file from branch diffs without scripts.
---

# PR Description File

Create a PR description Markdown file from git history and diff between `HEAD` and a target branch provided by the user.

## Required Input

- Target branch/ref (for example: `main`, `develop`, `release/5.6.0`, `origin/release/5.6.0`).
- Optional ticket (if missing, write `N/A`).
- Optional PR type override (`Feature`, `Fix`, `Refactor`, `Chore`).

Ask for missing target branch/ref when it cannot be resolved locally.

## No-Script Workflow

1. Resolve branch context and range.
- Run `git rev-parse --abbrev-ref HEAD`.
- Resolve target ref in this order: `refs/heads/<target>`, `refs/remotes/origin/<target>`, exact ref.
- Run `git merge-base <target-ref> HEAD`.
- Define comparison range as `<merge-base>..HEAD`.

2. Load changes into context.
- Run `git log --reverse --pretty=format:'%h %s' <range>`.
- Run `git diff --stat <range>`.
- Run `git diff -U1 <range>` and inspect added/changed behavior.

3. Derive PR content from meaning, not file inventory.
- `What was done`: short, high-level behavior changes based on commits and diff intent.
- `Why it was done`: include only for bugfix/refactor when reason is non-obvious.
- `Technical Details`: minimal key implementation points.
- Mention key entities (service/manager/protocol/method/flow).
- Mention file names only when a file is a key implementation artifact.
- Do not output a per-file list as the main technical section.

4. Write output file.
- Create `PR_DESCRIPTION.md` in repo root unless user requested another path.
- Fill the template exactly.

## Output Template

Use this exact structure:

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
* Code Review Guidelines
```

## Quality Rules

- Preserve natural sentence casing in title and bullets.
- Prefer 3-6 meaningful bullets total across Description + Technical Details.
- Avoid generic filler like "updated files" or "various fixes".
- If range is empty, explicitly state no commits found and stop before writing a misleading PR.
