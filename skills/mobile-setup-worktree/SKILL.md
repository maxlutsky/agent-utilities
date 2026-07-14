---
name: mobile-setup-worktree
description: >
  Creates a new git worktree at a given path with a given branch, then links the AI/Claude
  context into it by running /mobile-link-context. Handles existing local branches, remote
  branches (creates a tracking branch), and brand-new branches (created from a start point,
  defaulting to develop). After the worktree exists it asks the user for the AI source
  repository location and symlinks the context in.
  Use when the user says "setup worktree", "create worktree", "new worktree", "add worktree",
  "worktree with linked context", or invokes /mobile-setup-worktree.
model: claude-haiku-4-5-20251001
argument-hint: "<worktree-path> <branch> [start-point] [--source <ai-repo-path>] [--dry-run]"
---

# Mobile Setup Worktree

You are a DevOps assistant that spins up a ready-to-use git worktree: it checks out the
requested branch in a new working directory, then links the shared AI/Claude context into it
via `/mobile-link-context` so the worktree has `CLAUDE.md`, `.claude/`, etc. without copying.

Pairs with `/mobile-link-context` (does the linking) and `/mobile-sync-context` (copies context to/from a mirror).

## Arguments

Parse `$ARGUMENTS`:
- `worktree-path` (required) — where to create the new worktree, e.g. `../novus-ios-worktrees/NOVUS-1234`.
  May be relative (resolved against the current repo) or absolute.
- `branch` (required) — the branch to check out in the worktree. May already exist locally,
  exist on `origin`, or be brand new (it will be created).
- `start-point` (optional) — base commit/branch for a **new** branch. Defaults to `develop`
  if it exists (the team convention), otherwise the current `HEAD`. Ignored when the branch already exists.
- `--source <ai-repo-path>` (optional) — AI source repo for the link step. If omitted, the skill
  **asks the user** for it before linking.
- `--dry-run` (optional) — print the plan and exit without creating anything.

If `worktree-path` or `branch` is missing, stop and ask the user to provide them.

---

## Step 1: Validate environment

Confirm the current directory is a git repository and resolve its absolute path:

```bash
git rev-parse --show-toplevel
```

If this fails, stop and inform the user: "Run this skill from inside the git repository you want to branch from."

Store the result as `REPO_ROOT`.

Resolve the worktree path to an absolute path (it does not exist yet — create its parent first):

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)"
WT_INPUT="<worktree-path>"

case "$WT_INPUT" in
  /*) WT_PARENT="$(dirname "$WT_INPUT")"; WT_BASE="$(basename "$WT_INPUT")";;
  *)  WT_PARENT="$(dirname "$REPO_ROOT/$WT_INPUT")"; WT_BASE="$(basename "$WT_INPUT")";;
esac
mkdir -p "$WT_PARENT"
WT_PATH="$(cd "$WT_PARENT" && pwd)/$WT_BASE"

if [ -e "$WT_PATH" ]; then
  echo "❌ Target path already exists: $WT_PATH"
  exit 1
fi
echo "✅ Worktree will be created at: $WT_PATH"
```

---

## Step 2: Resolve the branch strategy

Fetch first so remote branches are visible, then classify the branch:

```bash
BRANCH="<branch>"
START="<start-point or empty>"

git -C "$REPO_ROOT" fetch origin --quiet 2>/dev/null || true

# A branch can only be checked out in one worktree at a time.
if git -C "$REPO_ROOT" worktree list --porcelain | grep -q "^branch refs/heads/$BRANCH$"; then
  echo "❌ Branch '$BRANCH' is already checked out in another worktree."
  exit 1
fi

if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  BRANCH_MODE="local"
elif git -C "$REPO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  BRANCH_MODE="remote"
else
  BRANCH_MODE="new"
  if [ -z "$START" ]; then
    if git -C "$REPO_ROOT" show-ref --verify --quiet refs/heads/develop \
       || git -C "$REPO_ROOT" show-ref --verify --quiet refs/remotes/origin/develop; then
      START="develop"
    else
      START="HEAD"
    fi
  fi
fi

echo "Branch mode: $BRANCH_MODE${START:+  (start point: $START)}"
```

- **local** — check out the existing local branch.
- **remote** — create a local tracking branch from `origin/<branch>`.
- **new** — create `<branch>` from `START`.

---

## Step 3: Show the plan and confirm

```
Worktree plan
─────────────────────────────────────────
Repo:          REPO_ROOT
Worktree path: WT_PATH
Branch:        BRANCH   (mode: local | remote | new)
Start point:   START          (only for a new branch)
Link source:   <--source value, or "will ask">
```

If `--dry-run`: print plan and exit.

Otherwise ask: `Create this worktree and link AI context? [y/N]`

---

## Step 4: Create the worktree

Run the command matching the branch mode:

```bash
case "$BRANCH_MODE" in
  local)  git -C "$REPO_ROOT" worktree add "$WT_PATH" "$BRANCH";;
  remote) git -C "$REPO_ROOT" worktree add --track -b "$BRANCH" "$WT_PATH" "origin/$BRANCH";;
  new)    git -C "$REPO_ROOT" worktree add -b "$BRANCH" "$WT_PATH" "$START";;
esac

echo ""
echo "✅ Worktree created:"
git -C "$REPO_ROOT" worktree list | tail -1
```

If the command fails, stop and show the error — do not proceed to linking.

---

## Step 5: Request the AI source location

If `--source <ai-repo-path>` was provided, use it as `AI_SOURCE`.

Otherwise **ask the user**: "Where is the AI source repository to link context from?
(e.g. `../novus-ios-ai`)". Use the `AskUserQuestion` tool. Do not guess — wait for the answer.

Validate it before continuing:

```bash
AI_SOURCE="<answer or --source value>"
RESOLVED="$(cd "$REPO_ROOT" && cd "$AI_SOURCE" 2>/dev/null && pwd)"
[ -d "$RESOLVED" ] || { echo "❌ AI source repo not found: $AI_SOURCE"; exit 1; }
echo "✅ AI source: $RESOLVED"
```

---

## Step 6: Link AI context into the new worktree

Run the `/mobile-link-context` skill, targeting the freshly created worktree explicitly with
`--target` (the worktree is the project to link into):

```
/mobile-link-context <AI_SOURCE> --target <WT_PATH>
```

Pass through `--dry-run` if it was set on this skill. Let `mobile-link-context` handle conflict
detection, the gitignore audit, confirmation, and the link report.

---

## Step 7: Report

```
✅ Worktree ready
   Path:    WT_PATH
   Branch:  BRANCH   (mode)
   Context: linked from AI_SOURCE via /mobile-link-context

   Open it:        cd WT_PATH
   Remove it later: git worktree remove WT_PATH   (then: git branch -d BRANCH if you created it)
   Re-detach links: /mobile-link-context AI_SOURCE --target WT_PATH --unlink
```

---

## Notes

- **One branch, one worktree.** Git refuses to check out the same branch in two worktrees;
  Step 2 detects this and stops early.
- **New branches default to `develop`.** Matches the team convention (NOVUS-* branches off
  `develop`). Pass an explicit `start-point` to override.
- **Linked, not copied.** The context files in the worktree are symlinks into the AI source
  repo — the single source of truth. They live at gitignored paths, so they are not committed
  to the worktree's branch.
- **Cleanup.** Use `git worktree remove <path>` to delete the worktree; the symlinks go with it.
