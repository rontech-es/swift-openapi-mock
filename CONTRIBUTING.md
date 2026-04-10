# Contributing

## Before you start

- Check if there is already an open issue for what you want to work on.
- If there isn't one, open it before starting.
- Every PR must reference at least one issue.

## Branch naming

Use the issue type as the branch prefix:

| Type | Prefix | Example |
|------|--------|---------|
| Task | `task/` | `task/add-ci-workflow` |
| Feature | `feature/` | `feature/add-timeout-support` |
| Bug fix | `fix/` | `fix/recording-middleware-crash` |

## Pull requests

- Title must use an imperative verb: `Add X`, `Fix Y`, `Remove Z`, `Update X`, `Refactor X`
- Fill out all required sections in the PR template
- Each linked issue must be on its own line (`Closes #N`) — GitHub only links the first when comma-separated

## Running tests locally

Please run the tests locally before submitting a PR and make sure everything passes.
