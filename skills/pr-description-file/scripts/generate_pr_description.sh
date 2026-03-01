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

clean_subject() {
  local raw="$1"
  printf '%s' "${raw}" \
    | sed -E 's/^\[[^]]+\]:[[:space:]]*//; s/^[A-Z]+-[0-9]+[[:space:]:-]*//; s/^[a-zA-Z]+(\([^)]+\))?:[[:space:]]*//' \
    | trim
}

to_sentence() {
  local text="$1"
  text="$(printf '%s' "${text}" | trim)"
  [[ -z "${text}" ]] && return 0
  text="$(printf '%s' "${text}" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
  if [[ "${text}" =~ [.!?]$ ]]; then
    printf '%s' "${text}"
  else
    printf '%s.' "${text}"
  fi
}

sentence_case() {
  local text="$1"
  text="$(printf '%s' "${text}" | trim)"
  [[ -z "${text}" ]] && return 0
  printf '%s' "${text}" | awk '{print toupper(substr($0,1,1)) substr($0,2)}'
}

camel_to_words() {
  local input="$1"
  printf '%s' "${input}" \
    | sed -E 's/([a-z0-9])([A-Z])/\1 \2/g; s/([A-Z])([A-Z][a-z])/\1 \2/g' \
    | tr '[:upper:]' '[:lower:]'
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
COMMIT_SUBJECTS="$(git log --reverse --pretty=format:'%s' "${RANGE}")"
COMMIT_COUNT="$(git rev-list --count "${RANGE}")"
CHANGED_FILE_COUNT="$(git diff --name-only "${RANGE}" | sed '/^$/d' | wc -l | tr -d ' ')"

if [[ -n "${TITLE_OVERRIDE}" ]]; then
  BRIEF_TITLE="${TITLE_OVERRIDE}"
else
  FIRST_SUBJECT_RAW="$(printf '%s\n' "${COMMITS_RAW}" | head -n 1 | cut -d'|' -f1)"
  FIRST_SUBJECT="$(sentence_case "$(clean_subject "${FIRST_SUBJECT_RAW}")")"
  if [[ -n "${FIRST_SUBJECT}" ]]; then
    BRIEF_TITLE="${FIRST_SUBJECT}"
  else
    BRIEF_TITLE="Update changes from ${CURRENT_BRANCH} into ${BASE_BRANCH}"
  fi
fi

LOWER_TYPE="$(printf '%s' "${PR_TYPE}" | tr '[:upper:]' '[:lower:]')"
if [[ "${LOWER_TYPE}" == "fix" || "${LOWER_TYPE}" == "bugfix" || "${LOWER_TYPE}" == "refactor" ]]; then
  WHY_REASON="$(printf '%s\n' "${COMMIT_SUBJECTS}" | awk 'BEGIN{IGNORECASE=1} /(fix|bug|regress|crash|stability|issue|warning|refactor)/ {print; exit}')"
  WHY_REASON="$(clean_subject "${WHY_REASON}")"
  WHY_REASON="$(to_sentence "${WHY_REASON}")"
  if [[ -z "${WHY_REASON}" ]]; then
    WHY_REASON="Address stability/quality issues discovered in the previous implementation."
  fi
  WHY_BLOCK="$(cat <<'EOF'
* **Why it was done:**
    * __WHY_REASON__
EOF
)"
  WHY_BLOCK="${WHY_BLOCK/__WHY_REASON__/${WHY_REASON}}"
else
  WHY_BLOCK=""
fi

DIRS="$(git diff --name-only "${RANGE}" | awk -F/ 'NF {print $1}' | sort | uniq | head -n 4 | paste -sd ', ' -)"
if [[ -z "${DIRS}" ]]; then
  DIRS="core modules"
fi

WHAT_DONE_BULLETS="$(
  printf '%s\n' "${COMMIT_SUBJECTS}" \
    | sed '/^$/d' \
    | while IFS= read -r subject; do
        cleaned="$(clean_subject "${subject}")"
        sentence="$(to_sentence "${cleaned}")"
        if [[ -n "${sentence}" ]]; then
          printf '    * %s\n' "${sentence}"
        fi
      done \
    | awk '!seen[$0]++' \
    | head -n 4
)"

if [[ -z "${WHAT_DONE_BULLETS}" ]]; then
  WHAT_DONE_BULLETS="$(cat <<EOF
    * Implemented ${COMMIT_COUNT} commit(s) from \`${CURRENT_BRANCH}\` compared to \`${BASE_REF}\`.
    * Delivered high-level updates across ${DIRS} with a scoped change set of ${CHANGED_FILE_COUNT} file(s).
EOF
)"
fi

DIFF_PATCH="$(git diff -U1 "${RANGE}")"

NEW_TYPES="$(
  printf '%s\n' "${DIFF_PATCH}" \
    | awk '
      /^\+[[:space:]]*(class|struct|actor|protocol|enum)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ {
        gsub(/^\+/, "", $0);
        kind=$1;
        name=$2;
        gsub(/[^A-Za-z0-9_].*$/, "", name);
        if (name != "") print kind "|" name;
      }
    ' \
    | awk '!seen[$0]++' \
    | head -n 4
)"

ADDED_FUNCS="$(
  printf '%s\n' "${DIFF_PATCH}" \
    | awk '
      /^\+[[:space:]]*(public|private|internal|fileprivate|open|static|final|override|mutating|nonmutating|async|throws|rethrows|@MainActor|@discardableResult|@Sendable|@escaping|@objc|@available|convenience|required|lazy|indirect)?[[:space:]]*func[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ {
        line=$0;
        sub(/^\+/, "", line);
        sub(/^.*func[[:space:]]+/, "", line);
        sub(/\(.*/, "", line);
        gsub(/[^A-Za-z0-9_].*$/, "", line);
        if (line != "") print line;
      }
    ' \
    | awk '!seen[$0]++' \
    | head -n 6
)"

TECH_DETAILS_BULLETS=""

if [[ -n "${NEW_TYPES}" ]]; then
  while IFS='|' read -r kind name; do
    [[ -z "${name}" ]] && continue
    topic="$(camel_to_words "${name}" | sed -E 's/[[:space:]]+(service|manager|provider|client|repository|coordinator|use case|usecase)$//')"
    if [[ "${name}" =~ (Service|Manager|Provider|Client|Repository|Coordinator)$ ]]; then
      TECH_DETAILS_BULLETS="${TECH_DETAILS_BULLETS}"$'\n'"* Created \`${name}\` (${kind}) to centralize ${topic} logic."
      usage_count="$(
        git diff --name-only "${RANGE}" \
          | sed '/^$/d' \
          | while IFS= read -r f; do
              git diff -U0 "${RANGE}" -- "${f}" | grep -Eq "^\+.*\b${name}\b" && printf '%s\n' "${f}"
            done \
          | wc -l | tr -d ' '
      )"
      if [[ "${usage_count}" -gt 1 ]]; then
        TECH_DETAILS_BULLETS="${TECH_DETAILS_BULLETS}"$'\n'"* Integrated \`${name}\` across multiple updated flows/components."
      fi
    else
      TECH_DETAILS_BULLETS="${TECH_DETAILS_BULLETS}"$'\n'"* Added \`${name}\` (${kind}) to support the updated flow."
    fi
  done <<< "${NEW_TYPES}"
fi

if [[ -n "${ADDED_FUNCS}" ]]; then
  FUNCS_INLINE="$(printf '%s\n' "${ADDED_FUNCS}" | sed 's/^/`/; s/$/()`/' | paste -sd ', ' -)"
  TECH_DETAILS_BULLETS="${TECH_DETAILS_BULLETS}"$'\n'"* Implemented/updated key methods: ${FUNCS_INLINE}."
fi

if [[ -z "${TECH_DETAILS_BULLETS}" ]]; then
  COMMIT_TECH_LINES="$(
    printf '%s\n' "${COMMIT_SUBJECTS}" \
      | sed '/^$/d' \
      | head -n 4 \
      | while IFS= read -r subject; do
          line="$(to_sentence "$(clean_subject "${subject}")")"
          [[ -n "${line}" ]] && printf '* %s\n' "${line}"
        done
  )"
  TECH_DETAILS_BULLETS="${COMMIT_TECH_LINES}"
fi

if [[ -z "${TECH_DETAILS_BULLETS}" ]]; then
  TECH_DETAILS_BULLETS="* No key implementation details detected in the selected range."
fi

TECH_DETAILS_BULLETS="$(printf '%s\n' "${TECH_DETAILS_BULLETS}" | sed '/^$/d' | awk '!seen[$0]++' | head -n 6)"

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
${WHAT_DONE_BULLETS}
${WHY_BLOCK}

---

### Technical Details

${TECH_DETAILS_BULLETS}

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
