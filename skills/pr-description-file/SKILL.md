---
name: pr-description-file
description: Create a Markdown file containing a filled pull request description by comparing the current branch against a user-provided target branch. Use when asked to generate a PR description file, draft PR text from git history, or prepare a review-ready PR template from branch diffs.
---

# PR Description File

Create a PR description file from git history and diff between `HEAD` and a target branch provided by the user.

## Required Input

- Target branch name (for example: `main`, `develop`, `release/1.2.0`).

Ask for the target branch if it is missing.

## Workflow

1. Confirm branch context:
- Run `git rev-parse --abbrev-ref HEAD` to get current branch.
- Verify the target branch exists locally or as `origin/<target>`.
2. Build the comparison range:
- Run `git merge-base <target-ref> HEAD`.
- Use `<merge-base>..HEAD` as the commit and diff range.
3. Generate PR file with script:
- Run `skills/pr-description-file/scripts/generate_pr_description.sh --base <target-branch>`.
- Optional flags:
- `--output <file.md>` to customize output file.
- `--type <Type>` to set title prefix (`Feature`, `Fix`, `Refactor`, `Chore`).
- `--title "<brief description>"` to override generated title text.
- `--ticket "<markdown link or ticket id>"` to fill Related Issue/Ticket.
4. Return the output path and a short summary of what was generated.

## Content Rules

- `What was done`: keep high-level and short. Do not include low-level technical details.
- `Why it was done`: include this section only for bug fixes or refactors. For features or flow changes, omit the `Why it was done` block entirely.
- `Technical details`: include key implementation notes with specific file names and entity/function names. Do not paste code.

## Output

Produce a Markdown file using the team's PR template, fully filled from branch comparison data plus provided inputs.
