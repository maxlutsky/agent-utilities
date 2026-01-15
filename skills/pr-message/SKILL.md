---
name: pr-message
description: Draft pull request messages using the team PR template, including type-tagged title, issue link, review time, description, technical details, testing steps, checklist, and review link. Use when asked to create or fill out a PR description/message.
---

# PR Message

## Determine branch context

- Run these commands to gather branch context and recent activity:

```bash
git branch --show-current
git symbolic-ref refs/remotes/origin/HEAD
git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/remotes/origin
```

- Ask for the target branch for this PR and suggest likely options based on git output.
  - Prefer the default branch from `origin/HEAD`.
  - Offer the 3-5 most recently updated remote branches (exclude `origin/HEAD`).
- Use the current branch name to prefill:
  - Related ticket (pattern like `PROJECT-123`).
  - Title hint (convert branch slug to words if no explicit description is given).

## Use the template asset

- Load `assets/pr-message-template.md` and copy it as the starting point for the PR message.
- Preserve headings, separators, and checklist formatting.

## Auto-fill from git

- Infer as much as possible from the repo before asking the user:
  - PR type from the changes (feature/fix/chore/refactor/docs/tests).
  - Brief title from the branch name plus git diff summary.
  - What was done and why from `git diff --stat` and `git log -1 --oneline`.
  - How to test from changes (scripts, tests, README) or `git diff` if present.
  - Technical details from code hotspots and file names.
- Ask only for missing or ambiguous details after auto-filling.

## Fill the template

- Title format: `# [Type]: Brief Description of Changes`
- If no related ticket exists, write `None` after the **Related Issue/Ticket:** label.
- Keep the checklist unchecked unless the user explicitly marks items complete.
- Keep all content in clear, concise Markdown.

## Output rules

- Return only the final PR message in Markdown.
- Do not add extra commentary outside the template.
