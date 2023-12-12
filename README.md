[![CI](https://github.com/yumemi-inc/path-filter/actions/workflows/ci.yml/badge.svg)](https://github.com/yumemi-inc/path-filter/actions/workflows/ci.yml)

# Path Filter

A GitHub Action to filter changed files in pull requests and commits.
It is useful when you want to run steps or jobs based on changed files.

Compared to [GitHub's path filter](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpushpull_requestpull_request_targetpathspaths-ignore), this action allows detailed control with steps and jobs, and there is no [limit](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#git-diff-comparisons) to the number of files.
The behavior of this action is simple, just compare head ref and base ref with git-diff.
Works fast and can handle differences between thousands of files.
Additionally, do not require code checkout in previous steps.

> [!NOTE]  
> For `pull_request` events, [yumemi-inc/changed-files](https://github.com/yumemi-inc/changed-files) can also be used.
> There are [limitations](https://github.com/yumemi-inc/changed-files#specify-comparison-targets) due to using GitHub API, but in `pull_request` events, there are no problems and it has more functions.

## Usage

See [action.yml](action.yml) for available action inputs and outputs.
Note that this action requires `contents: read` permission.

### Supported workflow trigger events

Works on any event, including `pull_request` and  `push` events.
See [Specify comparison targets](#specify-comparison-targets) for details.

### Basic

If there are changes to the files specified by `pattern` input, `exists` output will be `'true'`.
This is useful for controlling step execution.

```yaml
- uses: yumemi-inc/path-filter@v1
  id: filter
  with:
    patterns: |
      **/*.{js,ts}
      !tools/**
- if: steps.filter.outputs.exists == 'true'
  run: npm run test
```

> **Note:**
> In `pattern` input, characters after `#` are treated as comments.

If you just want to run a Bash script, you can use `run` input.
In this case, there is no need to define `id:`, since `exists` output is not used.

```yaml
- uses: yumemi-inc/path-filter@v1
  with:
    patterns: |
      **/*.{js,ts}
      !tools/**
    run: npm run test
```

<details>
<summary>examples of other uses</summary>

#### Add a label to a pull request:

```yaml
- uses: yumemi-inc/path-filter@v1
  id: filter
  with:
    patterns: |
      **/*.js
      !server/**
- env:
    GH_REPO: ${{ github.repository }}
    GH_TOKEN: ${{ github.token }}
  run: |
    gh pr edit ${{ github.event.number }} ${{ steps.filter.outputs.exists == 'true' && '--add-label' || '--remove-label' }} 'frontend'
```

#### Use for various checks:

```yaml
- uses: yumemi-inc/path-filter@v1
  id: filter-src
  with:
    patterns: |
      **/*.ts
      package.json
- uses: yumemi-inc/path-filter@v1
  id: filter-build
  with:
    patterns: 'dist/**'
- if: steps.filter-src.outputs.exists == 'true' && steps.filter-build.outputs.exists != 'true'
  run: |
    echo "::error::Please check if you forgot to build."
    exit 1
```

```yaml
- uses: yumemi-inc/path-filter@v1
  id: filter
  with:
    patterns: 'CHANGELOG.md'
- if: github.base_ref == 'main' && steps.filter.outputs.exists != 'true'
  run: |
    echo "::error::CHANGELOG.md is not updated."
    exit 1
```

</details>

### Control job execution

Set this action's `exists` output to the job's output, and reference it in subsequent jobs.

```yaml
outputs:
  exists: ${{ steps.filter.outputs.exists }}
steps:
  - uses: yumemi-inc/path-filter@v1
    id: filter
    with:
      patterns: '**/*.{kt,kts}'
```

<details>
<summary>examples</summary>

#### Run two jobs in parallel, then run a common job:

```yaml
jobs:
  filter:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      exists-src: ${{ steps.filter-src.outputs.exists }}
      exists-doc: ${{ steps.filter-doc.outputs.exists }}
    steps:
      - uses: yumemi-inc/path-filter@v1
        id: filter-src
        with:
          patterns: 'src/**'
      - uses: yumemi-inc/path-filter@v1
        id: filter-doc
        with:
          patterns: 'doc/**'
  job-src:
    needs: [filter]
    if: needs.filter.outputs.exists-src == 'true'
    runs-on: ubuntu-latest
    steps:
      ...
  job-doc:
    needs: [filter]
    if: needs.filter.outputs.exists-doc == 'true'
    runs-on: ubuntu-latest
    steps:
      ...
  job-common:
    needs: [job-src, job-doc]
    # treat skipped jobs as successful
    if: cancelled() != true && contains(needs.*.result, 'failure') == false
    runs-on: ubuntu-latest
    steps:
      ...
```
</details>

### Specify comparison targets

Basically, it is not necessary when using this action in `pull_request` events and `push` events, but you can specify `head-ref` and `base-ref` inputs if necessary.
Any branch, tag, or commit SHA can be specified for tease inputs.

```yaml
- uses: yumemi-inc/path-filter@v1
  with:
    head-ref: 'main' # branch to be released
    base-ref: 'release-x.x.x' # previous release tag
    patterns: '**/*.js'
    run: |
      ...
      npm run deploy
```

A comparison is made between head ref and base ref.
If `base-ref` input is not set, the changed files are from the single commit (if a branch is specified, its head commit) specified in `head-ref` input.

The default for `head-ref` input is `${{ github.sha }}`, which includes all commits of that pull request in `pull_request` events.
`base-ref` input is basically not set by default, but `${{ github.event.before }}` is set in `push` events (to clear it for some reason, specify an empty string like `''`).

So when using this action in `pull_request` events and `push` events, these inputs do not need to be changed from the default unless necessary.
If needed for these events or for use in other events, specify them explicitly.

The comparison in this action is [two-dot](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-comparing-branches-in-pull-requests#three-dot-and-two-dot-git-diff-comparisons).
In every workflow event, only a pure comparison of head ref and base ref is performed, so the specification is easy to understand.

## Tips

### Debugging

A list of changed files before and after filtering is output to a file in JSON format and can be accessed as follows:

```yaml
- uses: yumemi-inc/path-filter@v1
  id: filter
  with:
    patterns: '!**/*.md'
- run: |
    # before filtering
    cat '${{ steps.filter.outputs.action-path }}/files.json'
    # after filtering
    cat '${{ steps.filter.outputs.action-path }}/filtered_files.json'
```

Refer to these files when debugging `head-ref`, `base-ref`, and `patterns` inputs.
You may use these files for purposes other than debugging, but note that these files will be overwritten if you use this action multiple times in the same job.

## About the glob expression of `pattern` input

Basically, it complies with the [minimatch](https://www.npmjs.com/package/minimatch) library used in this action.
Please refer to the implementation in [action.yml](action.yml) for the specified options.
