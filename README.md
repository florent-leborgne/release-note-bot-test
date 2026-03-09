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
| `release_note:feature` | New feature | 50 words |
| `release_note:enhancement` | Enhancement | 30 words |
| `release_note:fix` | Bug fix | 20 words |
| `release_note:breaking` | Breaking change | 100 words |
| `release_note:deprecation` | Deprecation | 100 words |
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

Run the test script from your terminal. It gathers the same PR context as the workflow, calls the GitHub Models API, and prints the result.

You can pass a full PR URL — the script extracts the repo and PR number automatically:

```bash
# Defaults to release_note:enhancement
.github/scripts/test-release-note.sh https://github.com/elastic/kibana/pull/123

# Specify a label
.github/scripts/test-release-note.sh https://github.com/elastic/kibana/pull/123 release_note:fix
```

Or use the `owner/repo PR_NUMBER [label]` format:

```bash
.github/scripts/test-release-note.sh elastic/kibana 123 release_note:feature
```

**Prerequisites:** [`gh`](https://cli.github.com/) (GitHub CLI), `jq`, `curl`.

## Setup

No secrets are required for the GitHub Actions workflow — it uses the built-in `GITHUB_TOKEN` with `models: read` permission.

For local testing, the script uses your `gh auth` token by default. You can also set `GH_MODELS_TOKEN` explicitly:

```bash
export GH_MODELS_TOKEN="your_github_pat_with_models_read_scope"
```
