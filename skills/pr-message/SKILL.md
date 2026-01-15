---
name: pr-message
description: Draft pull request messages using the team PR template, including type-tagged title, issue link, review time, description, technical details, testing steps, checklist, and review link. Use when asked to create or fill out a PR description/message.
---

# PR Message

## Use the template asset

- Load `assets/pr-message-template.md` and copy it as the starting point for the PR message.
- Preserve headings, separators, and checklist formatting.

## Collect inputs

- Ask for any missing details before drafting. Minimum inputs:
  - PR type (e.g., Feature, Fix, Chore, Refactor, Docs)
  - Brief description for the title
  - Related issue/ticket link or explicit "None"
  - What was done
  - Why it was done
  - How to test (steps + expected behavior)
- Optional inputs:
  - Technical details
  - Screenshots/video links
  - Optional notes
  - Estimated review time (default to 5-10 minutes when not provided)

## Fill the template

- Title format: `# [Type]: Brief Description of Changes`
- If no related ticket exists, write `None` after the **Related Issue/Ticket:** label.
- Keep the checklist unchecked unless the user explicitly marks items complete.
- Keep all content in clear, concise Markdown.

## Output rules

- Return only the final PR message in Markdown.
- Do not add extra commentary outside the template.
