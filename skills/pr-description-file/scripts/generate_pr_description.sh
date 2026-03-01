#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  generate_pr_description.sh --base <target-branch> [options]

Options:
  --base <branch>      Target branch to compare against (required)
  --output <file>      Output markdown file path (default: PR_DESCRIPTION.md)
  --type <Type>        PR type for title, e.g. Feature|Fix|Refactor|Chore (default: Feature)
  --title <text>       Brief title text override
  --ticket <text>      Ticket value (markdown link or ticket ID, default: N/A)
  -h, --help           Show this help
EOF
}

require_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: not inside a git repository." >&2
    exit 1
  fi
}

trim() {
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

BASE_BRANCH=""
OUTPUT_FILE="PR_DESCRIPTION.md"
PR_TYPE="Feature"
TITLE_OVERRIDE=""
TICKET="N/A"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      BASE_BRANCH="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    --type)
      PR_TYPE="${2:-}"
      shift 2
      ;;
    --title)
      TITLE_OVERRIDE="${2:-}"
      shift 2
      ;;
    --ticket)
      TICKET="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${BASE_BRANCH}" ]]; then
  echo "Error: --base is required." >&2
  usage
  exit 1
fi

require_git_repo

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

if git show-ref --verify --quiet "refs/heads/${BASE_BRANCH}"; then
  BASE_REF="${BASE_BRANCH}"
elif git show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"; then
  BASE_REF="origin/${BASE_BRANCH}"
else
  echo "Error: target branch '${BASE_BRANCH}' was not found locally or on origin." >&2
  exit 1
fi

MERGE_BASE="$(git merge-base "${BASE_REF}" HEAD)"
RANGE="${MERGE_BASE}..HEAD"

COMMITS_RAW="$(git log --reverse --pretty=format:'%s|%h' "${RANGE}")"
COMMIT_COUNT="$(git rev-list --count "${RANGE}")"
CHANGED_FILE_COUNT="$(git diff --name-only "${RANGE}" | sed '/^$/d' | wc -l | tr -d ' ')"

if [[ -n "${TITLE_OVERRIDE}" ]]; then
  BRIEF_TITLE="${TITLE_OVERRIDE}"
else
  FIRST_SUBJECT="$(printf '%s\n' "${COMMITS_RAW}" | head -n 1 | cut -d'|' -f1 | trim)"
  if [[ -n "${FIRST_SUBJECT}" ]]; then
    BRIEF_TITLE="${FIRST_SUBJECT}"
  else
    BRIEF_TITLE="Update changes from ${CURRENT_BRANCH} into ${BASE_BRANCH}"
  fi
fi

LOWER_TYPE="$(printf '%s' "${PR_TYPE}" | tr '[:upper:]' '[:lower:]')"
if [[ "${LOWER_TYPE}" == "fix" || "${LOWER_TYPE}" == "bugfix" || "${LOWER_TYPE}" == "refactor" ]]; then
  WHY_BLOCK="$(cat <<'EOF'
* **Why it was done:**
    * Address issues found in the previous implementation and reduce risk in the impacted area.
EOF
)"
else
  WHY_BLOCK=""
fi

DIRS="$(git diff --name-only "${RANGE}" | awk -F/ 'NF {print $1}' | sort | uniq | head -n 4 | paste -sd ', ' -)"
if [[ -z "${DIRS}" ]]; then
  DIRS="core modules"
fi

WHAT_DONE_LINE_1="Implemented ${COMMIT_COUNT} commit(s) from \`${CURRENT_BRANCH}\` compared to \`${BASE_REF}\`."
WHAT_DONE_LINE_2="Delivered high-level updates across ${DIRS} with a scoped change set of ${CHANGED_FILE_COUNT} file(s)."

TECH_FILES="$(git diff --name-only "${RANGE}" | sed '/^$/d' | head -n 12)"
if [[ -z "${TECH_FILES}" ]]; then
  TECH_FILES="- No file changes detected in range."
else
  TECH_FILES="$(printf '%s\n' "${TECH_FILES}" | sed 's|^|- `|; s|$|`|')"
fi

TECH_ENTITIES="$(git diff -U0 "${RANGE}" | awk '
  /^@@/ {
    split($0, parts, "@@");
    if (length(parts) >= 3) {
      s=parts[3];
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s);
      if (s != "") print s;
    }
  }
' | sed '/^$/d' | sort -u | head -n 10)"

if [[ -z "${TECH_ENTITIES}" ]]; then
  TECH_ENTITIES="- No function/entity names detected from diff hunks."
else
  TECH_ENTITIES="$(printf '%s\n' "${TECH_ENTITIES}" | sed 's|^|- `|; s|$|`|')"
fi

if [[ -z "${COMMITS_RAW}" ]]; then
  COMMIT_NOTES="- No commits found between ${BASE_REF} and HEAD."
else
  COMMIT_NOTES="$(printf '%s\n' "${COMMITS_RAW}" | sed 's/|/ (/; s/$/)/; s/^/- /')"
fi

cat > "${OUTPUT_FILE}" <<EOF
# [${PR_TYPE}]: ${BRIEF_TITLE}

**Related Issue/Ticket:** ${TICKET}

**Estimated Review Time**: 5-10 minutes

---

### Description of Changes

* **What was done:**
    * ${WHAT_DONE_LINE_1}
    * ${WHAT_DONE_LINE_2}
${WHY_BLOCK}

---

### Technical Details

* **Key files changed:**
${TECH_FILES}
* **Impacted entities/functions (from diff context):**
${TECH_ENTITIES}

---

### How to Test

* **Steps to reproduce:**
    1. Check out \`${CURRENT_BRANCH}\` and sync dependencies.
    2. Run the affected flow(s) and test scenarios related to modified files.
* **Expected behavior:**
    * The updated behavior from this branch works as intended with no regressions in impacted areas.
* **Screenshots / Video (if applicable):**
    * Add links or screenshots here.

---

### Pre-Merge Checklist
* [ ] Code adheres to our **Coding Guidelines**.
* [ ] New/changed features are covered by tests (if applicable).
* [ ] All existing tests pass successfully.
* [ ] No new **warnings** in Xcode.
* [ ] Changes tested on a physical device.

---

### Optional Notes

* **Compared against:** \`${BASE_REF}\`
* **Merge base:** \`${MERGE_BASE}\`
* **Commit list:**
${COMMIT_NOTES}

### How to review
* [Code Review Guidelines](https://devlight.atlassian.net/wiki/x/OgDVGgE)
EOF

echo "Created ${OUTPUT_FILE}"
