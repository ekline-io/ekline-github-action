# EkLine GitHub action

[![Test](https://github.com/ekline-io/ekline-github-action/workflows/Test/badge.svg)](https://github.com/ekline-io/ekline-github-action/actions?query=workflow%3ATest)
[![depup](https://github.com/ekline-io/ekline-github-action/workflows/depup/badge.svg)](https://github.com/ekline-io/ekline-github-action/actions?query=workflow%3Adepup)
[![release](https://github.com/ekline-io/ekline-github-action/workflows/release/badge.svg)](https://github.com/ekline-io/ekline-github-action/actions?query=workflow%3Arelease)
[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/ekline-io/ekline-github-action?logo=github&sort=semver)](https://github.com/ekline-io/ekline-github-action/releases)
[![action-bumpr supported](https://img.shields.io/badge/bumpr-supported-ff69b4?logo=github&link=https://github.com/haya14busa/action-bumpr)](https://github.com/haya14busa/action-bumpr)

## Input

```yaml
inputs:
  content_dir:
    description: 'Content directory relative to the root directory.'
    default: '.'
  ek_token:
    description: 'Token for EkLine application'
    required: true
  filter_mode:
    description: |
      Filtering mode for the EkLine reviewer command [added,diff_context,file,nofilter].
      Default is added.
    default: 'added'
  github_token:
    description: 'GITHUB_TOKEN'
    default: '${{ secrets.github_token }}'
  reporter:
    description: 'Reporter of EkLine review command [github-pr-check,github-check,github-pr-review].'
    default: 'github-pr-check'
```

## Usage

```yaml
name: EkLine
on:
  push:
    branches:
      - master
  pull_request:
jobs:
  test-pr-review:
    if: github.event_name == 'pull_request'
    name: runner / EkLine Reviewer (github-pr-review)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ekline-io/ekline-github-action@v5
        with:
          content_dir: ./src/content
          ek_token: ${{ secrets.ek_token }}
          filter_mode: file
          github_token: ${{ secrets.github_token }}
          reporter: github-pr-review
```

## Reporters

EkLine reviewer can report results in review services as
continuous integration.

### Reporter: GitHub Checks (-reporter=github-pr-check)

github-pr-check reporter reports results to [GitHub Checks](https://help.github.com/articles/about-status-checks/).

### Reporter: GitHub Checks (-reporter=github-check)

It's basically same as `-reporter=github-pr-check` except it works not only for
Pull Request but also for commit.

### Reporter: GitHub PullRequest review comment (-reporter=github-pr-review)

![sample-github-pr-review.png](./image/sample-github-pr-review.png)

github-pr-review reporter reports results to GitHub PullRequest review comments
using GitHub Personal API Access Token.
[GitHub Enterprise](https://enterprise.github.com/home) is supported too.

- Go to https://github.com/settings/tokens and generate new API token.
- Check `repo` for private repositories or `public_repo` for public repositories.


## Filter mode
You can control how EkLine reviewer filter results by `-filter-mode` flag.
Available filter modes are as below.

### `added` (default)
Filter results by added/modified lines.
### `diff_context`
Filter results by diff context. i.e. changed lines +-N lines (N=3 for example).
### `file`
Filter results by added/modified file. i.e. EkLine reviewer will report results as long as they are in added/modified file even if the results are not in actual diff.
### `nofilter`
Do not filter any results. Useful for posting results as comments as much as possible and check other results in console at the same time.

### Filter Mode Support Table
Note that not all reporters provide full support of filter mode due to API limitation.
e.g. `github-pr-review` reporter uses [GitHub Review
API](https://developer.github.com/v3/pulls/reviews/) but it doesn't support posting comment outside diff (`diff_context`),
so EkLine reviewer will use [Check annotation](https://developer.github.com/v3/checks/runs/) as fallback to post those comments [1].

| `-reporter` \ `-filter-mode` | `added` | `diff_context` | `file`                  | `nofilter` |
| ---------------------------- | ------- | -------------- | ----------------------- | ---------- |
| **`github-check`**           | OK      | OK             | OK                      | OK |
| **`github-pr-check`**        | OK      | OK             | OK                      | OK |
| **`github-pr-review`**       | OK      | OK             | Partially Supported [1] | Partially Supported [1] |

- [1] Report results which is outside diff context with Check annotation as fallback if it's running in GitHub actions instead of Review API (comments). All results will be reported to console as well.