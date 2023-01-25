# EkLine Documentation Reviewer action

[![Test](https://github.com/ekline-io/ekline-github-action/workflows/Test/badge.svg)](https://github.com/ekline-io/ekline-github-action/actions?query=workflow%3ATest)
[![reviewdog](https://github.com/ekline-io/ekline-github-action/workflows/reviewdog/badge.svg)](https://github.com/ekline-io/ekline-github-action/actions?query=workflow%3Areviewdog)
[![depup](https://github.com/ekline-io/ekline-github-action/workflows/depup/badge.svg)](https://github.com/ekline-io/ekline-github-action/actions?query=workflow%3Adepup)
[![release](https://github.com/ekline-io/ekline-github-action/workflows/release/badge.svg)](https://github.com/ekline-io/ekline-github-action/actions?query=workflow%3Arelease)
[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/ekline-io/ekline-github-action?logo=github&sort=semver)](https://github.com/ekline-io/ekline-github-action/releases)
[![action-bumpr supported](https://img.shields.io/badge/bumpr-supported-ff69b4?logo=github&link=https://github.com/haya14busa/action-bumpr)](https://github.com/haya14busa/action-bumpr)

## Input

```yaml
inputs:
  github_token:
    description: 'GITHUB_TOKEN'
    default: '${{ github.token }}'
  workdir:
    description: 'Working directory relative to the root directory.'
    default: '.'
  ### Flags for reviewdog ###
  level:
    description: 'Report level for reviewdog [info,warning,error]'
    default: 'error'
  reporter:
    description: 'Reporter of reviewdog command [github-pr-check,github-check,github-pr-review].'
    default: 'github-pr-check'
  filter_mode:
    description: |
      Filtering mode for the reviewdog command [added,diff_context,file,nofilter].
      Default is added.
    default: 'added'
  fail_on_error:
    description: |
      Exit code for reviewdog when errors are found [true,false]
      Default is `false`.
    default: 'false'
  reviewdog_flags:
    description: 'Additional reviewdog flags'
    default: ''
  ### Flags for EkLine Reviewer ###
  ek_token:
    description: 'Token for EkLine application'
    required: true
  content_dir:
    description: 'Content directory relative to the root directory.'
    default: '.'
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
      - uses: ekline-io/ekline-github-action@v2
        with:
          github_token: ${{ secrets.github_token }}
          # Change reporter if you need [github-pr-check,github-check,github-pr-review].
          reporter: github-pr-review
          level: error
          content_dir: ./src/content
          reviewdog_flags: -filter-mode=file
```
