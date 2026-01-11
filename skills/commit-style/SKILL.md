---
name: commit-style
description: Conventional commit message format with ticket extraction from branch names
---

# Commit Message Format

Format: `<type>(<scope>): <subject>`

**type**: feat | fix | docs | style | refactor | test | chore  
**scope**: Ticket ID from branch (e.g., BROCARD-123) or branch name if no ticket  
**subject**: Present tense, no period, <72 chars

**Never include author names** - Git tracks authorship automatically

## Commit Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Formatting, no code change
- **refactor**: Code restructuring, no behavior change
- **test**: Test changes, no production code change
- **chore**: Build tasks, dependencies, no production code change

## Scope Extraction

Extract `PROJECTNAME-NUMBER` from branch name:
- `feature/MYPROJECT-985` → `MYPROJECT-985`
- `bugfix/MYPROJECT-123-fix-login` → `MYPROJECT-123`

If no ticket pattern found, use full branch name:
- `main` → `main`
- `hotfix` → `hotfix`

## Examples
```
feat(MYPROJECT-985): add total count to recently viewed products
fix(MYPROJECT-123): resolve login timeout issue
refactor(main): rename user service methods
```