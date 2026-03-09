#!/usr/bin/env bash
#
# Local test script for the release-note bot.
# Gathers the same PR context as the GitHub Actions workflow and calls the
# GitHub Models API to generate a release note in your terminal.
#
# Prerequisites: gh (GitHub CLI), jq, curl
#
# Usage:
#   ./test-release-note.sh <pr-url-or-repo> [pr-number] [label]
#
# Examples:
#   # Pass a full PR URL (label defaults to release_note:enhancement)
#   ./test-release-note.sh https://github.com/elastic/kibana/pull/123
#
#   # PR URL with explicit label
#   ./test-release-note.sh https://github.com/elastic/kibana/pull/123 release_note:fix
#
#   # owner/repo + PR number + label
#   ./test-release-note.sh elastic/kibana 123 release_note:feature

set -euo pipefail

# ── Parse arguments ──────────────────────────────────────────────────────────

if [ $# -lt 1 ]; then
  echo "Usage: $0 <pr-url-or-owner/repo> [pr-number] [label]" >&2
  exit 1
fi

# Detect whether the first arg is a GitHub PR URL or owner/repo
if [[ "$1" =~ ^https://github\.com/([^/]+/[^/]+)/pull/([0-9]+) ]]; then
  REPO="${BASH_REMATCH[1]}"
  PR_NUMBER="${BASH_REMATCH[2]}"
  LABEL="${2:-release_note:enhancement}"
else
  REPO="$1"
  PR_NUMBER="${2:?Error: PR number is required when using owner/repo format}"
  LABEL="${3:-release_note:enhancement}"
fi

OWNER="${REPO%%/*}"
REPO_NAME="${REPO##*/}"

# ── Resolve the API token ───────────────────────────────────────────────────

GITHUB_TOKEN="${GH_MODELS_TOKEN:-$(gh auth token 2>/dev/null || true)}"
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: Set GH_MODELS_TOKEN or log in with 'gh auth login'." >&2
  exit 1
fi

echo "╭──────────────────────────────────────────────╮"
echo "│  Release Note Bot — local test               │"
echo "╰──────────────────────────────────────────────╯"
echo ""
echo "  PR:    ${OWNER}/${REPO_NAME}#${PR_NUMBER}"
echo "  Label: ${LABEL}"
echo ""

# ── Gather PR context via gh CLI ─────────────────────────────────────────────

echo "⏳ Fetching PR metadata..."
PR_JSON=$(gh api "repos/${OWNER}/${REPO_NAME}/pulls/${PR_NUMBER}")
PR_TITLE=$(echo "$PR_JSON" | jq -r '.title')
PR_BODY=$(echo "$PR_JSON" | jq -r '.body // "(no description)"')

echo "⏳ Fetching PR diff..."
PR_DIFF=$(gh api "repos/${OWNER}/${REPO_NAME}/pulls/${PR_NUMBER}" \
  -H "Accept: application/vnd.github.v3.diff")
MAX_DIFF=10000
if [ ${#PR_DIFF} -gt $MAX_DIFF ]; then
  PR_DIFF="${PR_DIFF:0:$MAX_DIFF}

... (diff truncated for length)"
fi

echo "⏳ Fetching changed files..."
PR_FILES=$(gh api "repos/${OWNER}/${REPO_NAME}/pulls/${PR_NUMBER}/files" \
  --paginate --jq '.[] | "\(.status): \(.filename) (+\(.additions) -\(.deletions))"')

echo "⏳ Fetching PR comments..."
PR_COMMENTS=$(gh api "repos/${OWNER}/${REPO_NAME}/issues/${PR_NUMBER}/comments" \
  --paginate --jq '
    [.[] | select(.user.type != "Bot") | select(.body | contains("<!-- release-note-bot -->") | not)]
    | map("@\(.user.login): \(.body)") | join("\n\n")
  ')
if [ -z "$PR_COMMENTS" ]; then PR_COMMENTS="(no comments)"; fi

echo "⏳ Resolving linked issues..."
LINKED_ISSUES="(none)"
ISSUE_NUMBERS=$(echo "$PR_BODY" | grep -oE '(?<![/\w])#[0-9]+' | grep -oE '[0-9]+' || true)
if [ -n "$ISSUE_NUMBERS" ]; then
  ISSUES_TEXT=""
  for NUM in $ISSUE_NUMBERS; do
    ISSUE_JSON=$(gh api "repos/${OWNER}/${REPO_NAME}/issues/${NUM}" 2>/dev/null || true)
    if [ -n "$ISSUE_JSON" ]; then
      ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
      ISSUE_BODY=$(echo "$ISSUE_JSON" | jq -r '.body // "(no description)"')
      ISSUES_TEXT="${ISSUES_TEXT}### ${OWNER}/${REPO_NAME}#${NUM}: ${ISSUE_TITLE}
${ISSUE_BODY}

"
    fi
  done
  if [ -n "$ISSUES_TEXT" ]; then LINKED_ISSUES="$ISSUES_TEXT"; fi
fi

# ── Determine word limit ────────────────────────────────────────────────────

case "$LABEL" in
  release_note:breaking)     WORD_LIMIT="100" ;;
  release_note:deprecation)  WORD_LIMIT="100" ;;
  release_note:feature)      WORD_LIMIT="50" ;;
  release_note:enhancement)  WORD_LIMIT="30" ;;
  release_note:fix)          WORD_LIMIT="20" ;;
  *)                         WORD_LIMIT="30" ;;
esac

if [ -n "$WORD_LIMIT" ]; then
  LENGTH_INSTRUCTION="Your response MUST be ${WORD_LIMIT} words or fewer. Shorter is always better — ${WORD_LIMIT} words is the maximum, not the target."
else
  LENGTH_INSTRUCTION="There is no strict word limit for this type of change, but be as concise as possible."
fi

CHANGE_TYPE="${LABEL#release_note:}"

echo ""
echo "  Type:  ${CHANGE_TYPE}"
echo "  Limit: ${WORD_LIMIT} words"
echo ""

# ── Call GitHub Models API ───────────────────────────────────────────────────

echo "⏳ Generating release note..."
echo ""

PAYLOAD=$(jq -n \
  --arg title "$PR_TITLE" \
  --arg body "$PR_BODY" \
  --arg files "$PR_FILES" \
  --arg diff "$PR_DIFF" \
  --arg comments "$PR_COMMENTS" \
  --arg issues "$LINKED_ISSUES" \
  --arg length "$LENGTH_INSTRUCTION" \
  --arg change_type "$CHANGE_TYPE" \
  '{
    "model": "openai/gpt-4.1",
    "messages": [
      {
        "role": "system",
        "content": ("You are a technical writer who creates clear, concise release notes for end users. You focus on what changed from the USER perspective, not internal code details. Write in plain language. Use present tense. Address the reader directly as \"you\". Write exactly ONE short paragraph. Use all available context — the PR description, discussion comments, and linked issues — to understand the motivation and user impact of the change. CRITICAL: Always use the exact product and feature names as they appear in the PR title and description — never abbreviate, paraphrase, or substitute them (e.g. write \"ES|QL\" not \"EQL\", \"Kibana\" not \"the dashboard tool\"). " + $length)
      },
      {
        "role": "user",
        "content": ("Summarize the following pull request as a release note entry for end users. This is a **" + $change_type + "** change.\n\n## PR Title\n" + $title + "\n\n## PR Description\n" + $body + "\n\n## PR Comments (discussion)\n" + $comments + "\n\n## Linked Issues\n" + $issues + "\n\n## Changed Files\n" + $files + "\n\n## Diff\n```\n" + $diff + "\n```\n\nWrite a single release note paragraph that:\n- Describes what changed from the user/reader perspective\n- Uses clear, non-technical language where possible\n- Starts with a verb (Adds, Fixes, Updates, Removes, etc.)\n- Does NOT mention file names, internal code, or implementation details\n- Uses the linked issues and PR comments to understand WHY the change was made and what problem it solves for users\n\nDo NOT use bullet points. Write exactly one short paragraph. " + $length)
      }
    ],
    "temperature": 0.3,
    "max_tokens": 500
  }')

RESPONSE=$(curl -s -X POST \
  "https://models.github.ai/inference/chat/completions" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

RELEASE_NOTE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')

if [ -z "$RELEASE_NOTE" ]; then
  echo "❌ Failed to generate release note." >&2
  echo "API response:" >&2
  echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE" >&2
  exit 1
fi

WORD_COUNT=$(echo "$RELEASE_NOTE" | wc -w | tr -d ' ')

echo "────────────────────────────────────────────────"
echo ""
echo "$RELEASE_NOTE"
echo ""
echo "────────────────────────────────────────────────"
echo "  Words: ${WORD_COUNT} / ${WORD_LIMIT}"
echo ""
