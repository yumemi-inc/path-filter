# Path Filter

A GitHub Action to filter changed files in pull requests and commits.
Useful when you want to run steps or jobs if specific files are changed.

[Path filters](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpushpull_requestpull_request_targetpathspaths-ignore) can also be used in workflow triggers, but using this action allows detailed control with steps or jobs.

## Usage

See [action.yml](action.yml) for available action inputs and outputs.
Note that this action requires `contents: read` permission.

### Supported workflow trigger events

Works on any event, including `pull_request` and  `push` events.
