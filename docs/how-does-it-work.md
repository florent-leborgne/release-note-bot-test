# Release Note Bot — How it works

The release-note bot is a GitHub Actions workflow that uses AI to generate user-facing release note suggestions for pull requests. This document explains what the bot does, how it gathers context, and what content rules it follows.

## Workflow overview

```
PR labeled with release_note:* → Gather PR context → Call AI model → Post interactive comment
```

### 1. Trigger

The bot activates when one of the following labels is added to a PR targeting `main`:

- `release_note:feature`
- `release_note:enhancement`
- `release_note:fix`
- `release_note:breaking`
- `release_note:deprecation`

### 2. Context gathering

The bot collects as much context as possible to produce an accurate summary:

| Source | What it captures |
|---|---|
| **PR metadata** | Title and description |
| **PR diff** | The actual code changes (truncated to 10,000 characters if very large) |
| **Changed files** | List of files with additions/deletions counts |
| **PR comments** | Human conversation on the PR (bot comments are filtered out) |
| **Linked issues** | Any issues referenced in the PR body (`#123`, `owner/repo#123`, or full GitHub URLs) — the bot fetches each issue's title and body |

### 3. AI generation

The bot calls the **GitHub Models API** (using OpenAI GPT-4.1) with all the gathered context. The AI model is instructed to produce a release note following specific content rules (see below).

### 4. Interactive comment

The bot posts a PR comment with:

- The suggested release note text (editable)
- A tip explaining the author can edit the comment directly
- An **Approved** checkbox

When the checkbox is checked, a separate workflow adds the `release-note:approved` label to the PR. Unchecking removes it.

## Content rules

The AI model follows these rules when generating release notes:

### Voice and tone

- **Address the reader as "you"** — e.g., "You can now..." not "Users can now..."
- **Plain language** — avoid jargon and internal terminology where possible
- **Present tense** — "Adds", "Fixes", "Updates", not "Added", "Fixed"
- **Start with a verb** — the first word should be an action verb (Adds, Fixes, Updates, Removes, Deprecates, etc.)

### Format

- **One short paragraph** — no bullet points, no headings
- **No file names or code details** — describe the change from the user's perspective, not the implementation
- **Use the linked issues and comments** to understand *why* the change was made

### Word limits by change type

The word limit varies depending on the label. These are maximums, not targets — shorter is always better.

| Label | Change type | Max words |
|---|---|---|
| `release_note:feature` | New feature | 100 |
| `release_note:enhancement` | Enhancement | 50 |
| `release_note:fix` | Bug fix | 30 |
| `release_note:breaking` | Breaking change | No limit |
| `release_note:deprecation` | Deprecation | No limit |

### Naming accuracy

The bot is instructed to **always use exact product and feature names** as they appear in the PR title and description. It must never abbreviate, paraphrase, or substitute them. For example:

- Write "ES|QL", not "EQL" or "ESQL"
- Write "Kibana", not "the dashboard tool"
- Write "Elastic Agent", not "the agent"

## Approval workflow

1. The bot posts the suggested release note as a PR comment
2. The PR author (or any collaborator) can **edit the comment** to refine the wording
3. When satisfied, they **check the Approved box**
4. A second workflow detects the checkbox change and adds the `release-note:approved` label
5. If the box is unchecked, the label is automatically removed

This two-step process ensures a human always reviews and approves the final text before it's used in release notes.
