[![CI](https://github.com/yumemi-inc/path-filter/actions/workflows/ci.yml/badge.svg)](https://github.com/yumemi-inc/path-filter/actions/workflows/ci.yml)

# Path Filter

A GitHub Action to filter changed files in pull requests and commits.
It is useful when you want to run steps or jobs based on changed files.

Compared to [GitHub's path filter](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpushpull_requestpull_request_targetpathspaths-ignore), this action allows detailed control with steps and jobs, and there is no [limit](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#git-diff-comparisons) to the number of files.
The behavior of this action is simple, just compare head ref and base ref.
Works fast and can handle differences between thousands of files.
Additionally, do not require code checkout in previous steps.

> [!NOTE]  
> For `pull_request` events, [yumemi-inc/changed-files](https://github.com/yumemi-inc/changed-files) can also be used.
> There are [limitations](https://github.com/yumemi-inc/changed-files#specify-comparison-targets) due to using GitHub API, but in `pull_request` events, there are no problems and it has more functions.

## Usage

See [action.yml](action.yml) for available action inputs and outputs.
Note that this action requires `contents: read` permission.

### Supported workflow trigger events

Works on any event.
See [Specify comparison targets](#specify-comparison-targets) for details.

### Basic

If there are changes to the files specified by `pattern` input, `exists` output will be `'true'`.
This is useful for controlling step execution.

```yaml
- uses: yumemi-inc/path-filter@v2
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
- uses: yumemi-inc/path-filter@v2
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
- uses: yumemi-inc/path-filter@v2
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
- uses: yumemi-inc/path-filter@v2
  id: filter-src
  with:
    patterns: |
      **/*.ts
      package.json
- uses: yumemi-inc/path-filter@v2
  id: filter-build
  with:
    patterns: 'dist/**'
- if: steps.filter-src.outputs.exists == 'true' && steps.filter-build.outputs.exists != 'true'
  run: |
    echo "::error::Please check if you forgot to build."
    exit 1
```

```yaml
- uses: yumemi-inc/path-filter@v2
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
  - uses: yumemi-inc/path-filter@v2
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
      - uses: yumemi-inc/path-filter@v2
        id: filter-src
        with:
          patterns: 'src/**'
      - uses: yumemi-inc/path-filter@v2
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

Simply, the change files are determined between `head-ref` input and `base-ref` input references.
The default values ​​for each workflow trigger event are as follows:

| event | head-ref | base-ref |
|:---|:---|:---|
| pull_request | github.sha | github.base_ref |
| push | github.sha | github.event.before[^1] / default branch |
| merge_group | github.sha | github.event.merge_group.base_sha |
| other events[^2] | github.sha | default branch |

[^1]: Not present on tag push or new branch push. In that case, the default branch will be applied.
[^2]: There is no default value for `pull_request_target` events, but you can specify `refs/pull/${{ github.event.number }}/merge` to `head-ref` input.

Specify these inputs explicitly if necessary.
**Any branch, tag, or commit SHA** can be specified for tease inputs[^3].

[^3]: In addition to direct specification of branch names and tag names, references such as `refs/heads/xxx`, `refs/pull/xxx/merge`, and `refs/tags/xxx` are also supported.

```yaml
- uses: yumemi-inc/path-filter@v2
  with:
    head-ref: 'main' # branch to be released
    base-ref: 'release-x.x.x' # previous release tag
    patterns: '**/*.js'
    run: |
      ...
      npm run deploy
```

By default, [two-dot](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-comparing-branches-in-pull-requests#three-dot-and-two-dot-git-diff-comparisons) comparison is performed.
If you want to compare with three-dot, set `use-merge-base` input to `'true'`.

## Tips

### List of changed files and list after filtering

They are output to a file in JSON format and can be accessed as follows:

- `${{ steps.<id>.outputs.action-path }}/files.json`
- `${{ steps.<id>.outputs.action-path }}/filtered_files.json`.

<details>
<summary>more</summary>

Refer to these files when debugging `head-ref`, `base-ref`, and `patterns` inputs.
For example, display them in the job summary like this:

```yaml
- uses: yumemi-inc/path-filter@v2
  id: filter
  with:
    patterns: '!**/*.md'
- run: |
    {
      echo '### files before filtering'
      echo '```json'
      cat '${{ steps.filter.outputs.action-path }}/files.json' | jq
      echo '```'
      echo '### files after filtering'
      echo '```json'
      cat '${{ steps.filter.outputs.action-path }}/filtered_files.json' | jq
      echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
```

You may use these files for purposes other than debugging, but note that these files will be overwritten if you use this action multiple times in the same job.

And, in this action's `run` input, access them with Bash variables like `$GITHUB_ACTION_PATH/files.json`, but note that the Bash script in `run` input will not be executed if there are no files after filtering.
</details>

## About the glob expression of `pattern` input

Basically, it complies with the [minimatch](https://www.npmjs.com/package/minimatch) library used in this action.
Please refer to the implementation in [action.yml](action.yml) for the specified options.
