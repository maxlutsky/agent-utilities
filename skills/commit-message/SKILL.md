---
name: commit-message
description: Generate conventional commit messages for the current git changes and optionally perform the commit. Use when asked to draft a commit message, prepare a commit, or summarize staged/working-tree changes into a conventional commit format with scope inferred from branch naming.
---

# Commit Message

## Overview

Generate a conventional commit message by inspecting current git changes, extracting a scope from the branch name, and presenting clear next-step options to the user.

## Workflow

### Step 1: Analyze changes

Run these commands and summarize what changed:

```bash
git status --short
git branch --show-current
git diff --stat
```

Call out key files and their purpose (feature, fix, refactor, docs, tests, build, chore).

### Step 2: Determine scope and type

Extract scope from the branch name using pattern `PROJECTNAME-123` (case sensitive). If missing, use the full branch name as the scope.

Choose the conventional commit type based on the changes:

- `feat`: new feature or significant behavior change
- `fix`: bug fix
- `refactor`: restructuring without behavior change
- `docs`: documentation only
- `test`: test-only changes
- `build`: build system or dependencies
- `chore`: maintenance or misc changes

If a commit-style skill is available in the environment, follow its exact formatting rules.

### Step 3: Generate message

Format the message as:

```
<type>(<scope>): <short summary>
```

Keep the summary concise and aligned with the primary change. If multiple changes are present, bias toward the most impactful one and keep the rest for the body only if asked.

### Step 4: Present options

Offer the following user choices:

1. Accept and commit (execute `git commit -m "<message>"`)
2. Edit the message (prompt for desired edits)
3. Suggest splitting (run `/commit-plan` or provide a multi-commit outline)
4. Cancel
