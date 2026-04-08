Make your changes in a new git branch:

```bash
  git checkout -b name/my-fix-branch main
```

Create your feature, **including appropriate test cases**.

## Pull Request Scope and Size (Enforced)

We require small, focused PRs tied to a single Linear issue. The pre-commit and CI checks will fail if your branch exceeds:

- **25 files** changed
- **800 lines** changed (additions + deletions)
- **400 lines** changed in any single file

If you exceed these limits, split the work into smaller, stacked PRs or separate changes by issue. If you think an exception is warranted, coordinate with a maintainer before opening the PR.

Install the hooks so size checks run locally:

```bash
pre-commit install
pre-commit install --hook-type pre-push
pre-commit run --all-files
```

Run the full test suite and ensure that all tests pass.

```bash
  uv run pytest
```

Commit your changes using a descriptive commit message that follows our commit message conventions. Adherence to these conventions is necessary because release notes are automatically generated from these messages.

```bash
  git commit -a
```

Note: the optional commit `-a` command line option will automatically "add" and "rm" edited files.

Push your branch to GitHub:

```bash
 git push origin name/my-fix-branch
```

In GitHub, send a pull request to `oculus-backend:main`.

### Using GitHub CLI

You can also create a pull request using the GitHub CLI:

```
gh pr create --title "fix: resolve issue with voice agent" --body "Fixes #AI-123"
```

#### Retrieving PR Review Comments

When reviewers leave comments on your PR, you can retrieve and view them locally using GitHub CLI:

```bash
# View PR details including review status
gh pr view <pr-number>

# List all review comments on a PR
gh pr view <pr-number> --comments

# View PR diff with inline comments
gh pr diff <pr-number>

# Check PR review status
gh pr checks <pr-number>

# View specific review details
gh api repos/:owner/:repo/pulls/<pr-number>/reviews

# Get review comments with file context
gh api repos/:owner/:repo/pulls/<pr-number>/comments
```

For your current branch:

```bash
# View comments on the PR associated with current branch
gh pr view --comments

# View review status for current branch's PR
gh pr checks
```

#### Responding to Review Comments

After reviewing comments locally:

- If changes are suggested then:
    - Make the required updates.
    - Re-run the test suites to ensure tests are still passing.
    - Rebase your branch and force push to your GitHub repository (this will update your Pull Request):

```bash
git rebase main -i
git push -f
```

You can also respond to comments via CLI:

```bash
# Add a comment to the PR
gh pr comment <pr-number> --body "Thanks for the review! I've addressed all the comments."

# Mark a review comment as resolved (requires PR write access)
gh api -X PUT repos/:owner/:repo/pulls/comments/<comment-id>/reactions \
  -f content='+1'
```

## Pull Request Merge Strategy

We use **squash and merge** for all pull requests to maintain a clean, linear commit history on the main branch. This approach:

- Combines all commits from your feature branch into a single commit
- Keeps the main branch history clean and easy to follow
- Preserves the full development history in the PR discussion

### Merge Process

1. **Squash and Merge**: When your PR is approved, use GitHub's "Squash and merge" button
1. **Commit Message**: Ensure the squash commit message follows our [commit message guidelines](#commit-message-guidelines)
1. **Branch Cleanup**: Delete your feature branch after merging (see cleanup instructions below)

#### Using GitHub CLI for Merging

Maintainers can merge PRs using the GitHub CLI:

```bash
# Squash and merge (default for this repository)
gh pr merge <number> --squash

# Squash and merge with custom commit message
gh pr merge <number> --squash --subject "feat(voice): add new agent capabilities"

# Auto-merge when checks pass
gh pr merge <number> --squash --auto

# Delete branch after merge
gh pr merge <number> --squash --delete-branch
```

### Alternative: Rebase and Merge

For PRs with a clean, logical commit history, maintainers may choose "Rebase and merge" to preserve individual commits. This is used when:

- Each commit represents a logical, complete change
- Commit messages follow our guidelines
- The commit history tells a clear story of the development process

#### After your pull request is merged

After your pull request is merged, delete your branch and pull the changes from the main (upstream) repository:

```
git push origin --delete name/my-fix-branch
```

Check out the main branch:

```bash
  git checkout main -f
```

Delete the local branch:

```bash
  git branch -D name/my-fix-branch
```

Update your main with the latest upstream version:

```bash
  git pull --ff upstream main
```

## Commit Message Guidelines

### Commit Message Format

Each commit message consists of a **header** only. The header has a special format that includes a **type**, a **scope** and a **subject**:

```
<type>(<scope>): <subject>
```

The **header** is mandatory and the **scope** of the header is optional.

Any line of the commit message cannot be longer 100 characters.

Link the pull request to an issue by using a supported keyword in the pull request's description:

- close
- closes
- closed
- fix
- fixes
- fixed
- resolve
- resolves
- resolved

The Linear team is called AI, so issue numbers are prepended by 'AI-'.

Single issue: KEYWORD #AI-ISSUE-NUMBER (for example, Closes #AI-10)

Multiple issues: Use full syntax for each issue (for example, Resolves #AI-10, resolves #AI-123, resolves name/ai-1-test-mcp-integration)

### Revert

If the commit reverts a previous commit, it should begin with `revert:`, followed by the header of the reverted commit.

### Type

Must be one of the following:

- **build**: Changes that affect the build system or external dependencies
- **ci**: Changes to our CI configuration files and scripts
- **docs**: Documentation only changes
- **feat**: A new feature
- **fix**: A bug fix
- **perf**: A code change that improves performance
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **style**: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
- **test**: Adding missing tests or correcting existing tests

### Subject

The subject contains a succinct description of the change:

- use the imperative, present tense: "change" not "changed" nor "changes"
- don't capitalize the first letter
- no dot (.) at the end
