---
name: mobile-link-context
description: >
  Creates symlinks in the current project that point at the Claude/AI context files
  living in a local AI source repository (a Devlight context mirror).
  Link mode (default): symlinks CLAUDE.md/AGENTS.md files, .claude/ items, .mcp.json
  from the AI repo into the current project so the AI repo stays the single source of truth.
  Unlink mode (--unlink): removes those symlinks again. Never touches real local files
  (settings.local.json) and never deletes the source.
  Use when the user says "link context", "symlink ai files", "link claude context",
  "create symlinks to ai repo", "unlink context", "злінкувати контекст",
  or invokes /mobile-link-context.
model: claude-haiku-4-5-20251001
argument-hint: "<ai-repo-path> [--target <project-path>] [--unlink] [--force] [--dry-run]"
---

# Mobile Link Context

You are a DevOps assistant that wires a client project to a local AI source repository
(a Devlight context mirror) by creating **symbolic links** instead of copies. The AI repo
becomes the single source of truth: editing a linked file in either place changes both.

This is the symlink-based companion to `/mobile-sync-context` (which copies files). Use this
when you want live links rather than snapshots.

## Modes

- **Link** (default) — AI repo → current project. Creates symlinks pointing at the AI repo's files.
- **Unlink** (`--unlink`) — removes symlinks in the current project that point into the AI repo.

## Arguments

Parse `$ARGUMENTS`:
- `ai-repo-path` (required) — path to the local AI source repository, e.g. `../novus-ios-ai`.
  May be relative (resolved against the current project) or absolute.
- `--target <project-path>` (optional) — link into this project/worktree instead of the
  current git repo. This is how `/mobile-setup-worktree` points the link at a freshly created worktree.
- `--unlink` (optional) — run in unlink mode instead of link mode.
- `--force` (optional, link mode only) — replace existing real files/dirs at a target path.
  The original is backed up to `<target>.pre-link.bak` first.
- `--dry-run` (optional) — print the plan and exit without creating or removing anything.

If `ai-repo-path` is missing, stop and ask the user to provide it.

---

## Step 1: Validate environment

Confirm the current directory is a git repository and resolve its absolute path:

```bash
git rev-parse --show-toplevel
```

If this fails, stop and inform the user: "Run this skill from inside the client project directory."

Store the result as `PROJECT_ROOT`.

If `--target <project-path>` was passed, link into that project/worktree instead of the
current repo (this is how `/mobile-setup-worktree` points the link at a freshly created worktree):

```bash
if [ -n "$TARGET_OVERRIDE" ]; then
  PROJECT_ROOT="$(cd "$TARGET_OVERRIDE" 2>/dev/null && pwd)"
  [ -d "$PROJECT_ROOT" ] || { echo "❌ --target path not found: $TARGET_OVERRIDE"; exit 1; }
fi
git -C "$PROJECT_ROOT" rev-parse --show-toplevel >/dev/null 2>&1 \
  || echo "⚠️  Target is not a git repo/worktree (continuing): $PROJECT_ROOT"
```

Resolve the AI source repo to an absolute path and validate it:

```bash
AI_INPUT="<ai-repo-path>"
# Resolve relative to the project root, fall back to as-given.
SOURCE_ROOT="$(cd "$PROJECT_ROOT" && cd "$AI_INPUT" 2>/dev/null && pwd)"

if [ -z "$SOURCE_ROOT" ] || [ ! -d "$SOURCE_ROOT" ]; then
  echo "❌ AI repo path not found: $AI_INPUT"
  exit 1
fi

if [ "$SOURCE_ROOT" = "$PROJECT_ROOT" ]; then
  echo "❌ AI repo and current project are the same directory — nothing to link."
  exit 1
fi

git -C "$SOURCE_ROOT" rev-parse --show-toplevel >/dev/null 2>&1 \
  && echo "✅ Source is a git repository: $SOURCE_ROOT" \
  || echo "⚠️  Source is not a git repository (continuing): $SOURCE_ROOT"
```

> Symlinks use **absolute** paths to the source, so they keep working regardless of the
> current working directory. If you later move either repo, re-run with `--unlink` and link again.

---

## Step 2: Build the file list from the source

Enumerate the AI context files in `SOURCE_ROOT`. Three categories:

**1. CLAUDE.md / AGENTS.md files (any depth):**
```bash
find "$SOURCE_ROOT" \
  \( -name "CLAUDE.md" -o -name "AGENTS.md" \) \
  -not -path "*/.git/*" \
  -not -path "*/.claude/*" \
  -not -path "*/build/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/Pods/*" \
  -not -path "*/DerivedData/*" \
  -not -path "*/.gradle/*"
```

**2. `.claude/` items — allowlist only** (so machine-local state is never linked):
```bash
for item in agents commands hooks rules skills settings.json; do
  [ -e "$SOURCE_ROOT/.claude/$item" ] && echo ".claude/$item"
done
```
Directories (`agents`, `commands`, `hooks`, `rules`, `skills`) become **directory symlinks**;
`settings.json` becomes a **file symlink**. Never link `.claude/settings.local.json` or any `.DS_Store`.

**3. `.mcp.json`** (if present):
```bash
[ -f "$SOURCE_ROOT/.mcp.json" ] && echo ".mcp.json"
```

Count the items so the plan can show a total.

---

## LINK MODE (default)

Proceed with Steps 3–6 when `--unlink` is NOT set.

### Step 3: Gitignore audit

The symlinks must **not** be committed to the client project — they are local plumbing.
Read `$PROJECT_ROOT/.gitignore` (and rely on the global excludes) and check these patterns
are effectively ignoring the targets:

- `/CLAUDE.md`
- `/**/CLAUDE.md`
- `.claude`
- `.mcp.json`

For each target that is **not** ignored, print a warning (do not modify `.gitignore`, continue):

```
⚠️  Project would track this symlink: <path>
    Add it to .gitignore so the link is not committed to the client repo.
```

A quick per-target check:
```bash
git -C "$PROJECT_ROOT" check-ignore -q "<target>" \
  && echo "ok (ignored): <target>" \
  || echo "⚠️  not ignored: <target>"
```

### Step 4: Build the plan and detect conflicts

For each source item, compute the target path inside the project:
```bash
REL="${SRC#$SOURCE_ROOT/}"      # path relative to the source repo
TARGET="$PROJECT_ROOT/$REL"
```

Classify each target:
- **new** — nothing exists at `TARGET` → will create the symlink.
- **already linked** — `TARGET` is a symlink already pointing at `SRC` → skip (idempotent).
- **wrong link** — `TARGET` is a symlink pointing elsewhere → relink only with `--force`.
- **real file/dir** — `TARGET` exists as a real file/dir → skip unless `--force`
  (with `--force`, back it up to `<TARGET>.pre-link.bak` first).

### Step 5: Show the plan and confirm

```
Link plan — <ai-repo-path> → PROJECT_NAME
─────────────────────────────────────────
CLAUDE.md / AGENTS.md:  3 files
.claude/ items:         2 (skills, settings.json)
.mcp.json:              present
Total:                  6 links

new: 5   already linked: 1   conflicts: 0
Source of truth: <SOURCE_ROOT>
```

If `--dry-run`: print plan and exit.

Otherwise ask: `Create 6 symlinks into PROJECT_NAME? [y/N]`

### Step 6: Create the symlinks

Use this helper for every item (works for both files and directories; `-n` prevents
descending into an existing directory symlink):

```bash
FORCE=0   # set to 1 when --force is passed

link_one() {
  local src="$1" target="$2" rel="$3"
  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    if [ "$(readlink "$target")" = "$src" ]; then
      echo "  ⏭️  already linked: $rel"; return
    fi
    if [ "$FORCE" = "1" ]; then
      ln -sfn "$src" "$target"; echo "  🔁 relinked: $rel"
    else
      echo "  ⚠️  other link, skipped: $rel → $(readlink "$target")  (use --force)"
    fi
    return
  fi

  if [ -e "$target" ]; then
    if [ "$FORCE" = "1" ]; then
      mv "$target" "$target.pre-link.bak"
      ln -s "$src" "$target"; echo "  🔁 replaced (backup .pre-link.bak): $rel"
    else
      echo "  ⚠️  real file exists, skipped: $rel  (use --force to replace)"
    fi
    return
  fi

  ln -s "$src" "$target"; echo "  ✅ linked: $rel"
}
```

Drive it over the file list from Step 2:
```bash
# CLAUDE.md / AGENTS.md
while IFS= read -r src; do
  rel="${src#$SOURCE_ROOT/}"
  link_one "$src" "$PROJECT_ROOT/$rel" "$rel"
done < <(find "$SOURCE_ROOT" \( -name CLAUDE.md -o -name AGENTS.md \) \
  -not -path "*/.git/*" -not -path "*/.claude/*" -not -path "*/build/*" \
  -not -path "*/node_modules/*" -not -path "*/Pods/*" \
  -not -path "*/DerivedData/*" -not -path "*/.gradle/*")

# .claude/ allowlist
mkdir -p "$PROJECT_ROOT/.claude"
for item in agents commands hooks rules skills settings.json; do
  [ -e "$SOURCE_ROOT/.claude/$item" ] || continue
  link_one "$SOURCE_ROOT/.claude/$item" "$PROJECT_ROOT/.claude/$item" ".claude/$item"
done

# .mcp.json
[ -f "$SOURCE_ROOT/.mcp.json" ] && link_one "$SOURCE_ROOT/.mcp.json" "$PROJECT_ROOT/.mcp.json" ".mcp.json"
```

### Step 7: Link report

```
✅ Link complete
   Links created:  5
   Already linked: 1
   Conflicts:      0   (re-run with --force to replace)
   Source:         <SOURCE_ROOT>

   The AI repo is now the single source of truth — edits propagate both ways.
   Run with --unlink to detach.
```

---

## UNLINK MODE (--unlink)

Proceed with Steps 8–10 when `--unlink` IS set.

### Step 8: Find symlinks pointing into the source

Scan the project for symlinks whose target resolves into `SOURCE_ROOT` (prune heavy dirs):

```bash
find "$PROJECT_ROOT" -type l \
  -not -path "*/.git/*" -not -path "*/Pods/*" -not -path "*/node_modules/*" \
  -not -path "*/DerivedData/*" -not -path "*/build/*" -not -path "*/.gradle/*" \
  | while IFS= read -r link; do
      case "$(readlink "$link")" in
        "$SOURCE_ROOT"/*) echo "${link#$PROJECT_ROOT/}";;
      esac
    done
```

### Step 9: Show the plan and confirm

```
Unlink plan — PROJECT_NAME ✕ <ai-repo-path>
─────────────────────────────────────────
Symlinks pointing into source: 5

These links will be removed. Real files and *.pre-link.bak backups are left untouched.
```

If `--dry-run`: print plan and exit.

Otherwise ask: `Remove 5 symlinks from PROJECT_NAME? [y/N]`

### Step 10: Remove the symlinks and report

```bash
# For each link found in Step 8:
rm "$PROJECT_ROOT/<rel>" && echo "  🗑️  removed: <rel>"
```

If a matching `<rel>.pre-link.bak` exists, tell the user they can restore it with
`mv <rel>.pre-link.bak <rel>` — do not restore automatically.

```
✅ Unlink complete
   Links removed: 5
   Source repo:   untouched
   Backups (*.pre-link.bak), if any, were left in place for you to restore manually.
```

---

## Notes

- **Single source of truth.** Linked files are not copies — editing through the project edits
  the AI repo's file and vice versa. Commit context changes in the AI repo, not the client repo.
- **Never committed to the client.** The links live at ignored paths (`CLAUDE.md`, `.claude/`,
  `.mcp.json`); Step 3 warns if any would be tracked.
- **Local-only files are safe.** `.claude/settings.local.json` is never linked, so each machine
  keeps its own tokens/settings.
- **Pairs with `/mobile-sync-context`.** Use `sync` to copy snapshots to/from a remote mirror;
  use `link` to point a project at a local mirror live.
