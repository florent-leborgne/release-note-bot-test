# release-note-bot-test

Test repo for the **release-note bot** GitHub Action — an AI-powered workflow that generates user-facing release note suggestions for pull requests.

## How it works

1. A PR is opened against `main`
2. A team member adds one of the `release_note:*` labels
3. The bot generates a release note using the GitHub Models API (GPT-4.1)
4. The suggestion is posted as an interactive PR comment
5. The author can edit the wording and check the **Approved** checkbox
6. Approval adds a `release-note:approved` label to the PR

## Labels

| Label | Type | Word limit |
|---|---|---|
| `release_note:feature` | New feature | 100 words |
| `release_note:enhancement` | Enhancement | 50 words |
| `release_note:fix` | Bug fix | 30 words |
| `release_note:breaking` | Breaking change | No limit |
| `release_note:deprecation` | Deprecation | No limit |
| `release-note:approved` | Approved (set by bot) | — |

## Testing

### Option 1: Label a PR

1. Open a PR with any change against `main`
2. Add one of the `release_note:*` labels (e.g. `release_note:fix`)
3. Wait for the Action to run (~30s)
4. Check the PR comments for the bot's suggestion
5. Edit the comment to tweak the wording, then check the **Approved** box

### Option 2: Manual dispatch (dry run)

1. Go to **Actions > Generate Release Notes > Run workflow**
2. Enter a PR number (can be from another repo using the owner/repo fields)
3. Pick a label type from the dropdown
4. Keep **dry_run** checked — the result only appears in the workflow logs, nothing is posted

### Option 3: Local test script

```bash
export GH_MODELS_TOKEN="your_github_pat_with_models_read_scope"

# Test as a fix (30 word limit)
.github/scripts/test-release-note.sh owner/repo 123 release_note:fix

# Test as a feature (100 word limit)
.github/scripts/test-release-note.sh owner/repo 123 release_note:feature
```

## Setup

No secrets are required for the GitHub Actions workflow — it uses the built-in `GITHUB_TOKEN` with `models: read` permission.

For local testing, you need a GitHub PAT with the `models:read` scope.
