# EkLine GitHub action

[![Test](https://github.com/ekline-io/ekline-github-action/workflows/Test/badge.svg)](https://github.com/ekline-io/ekline-github-action/actions?query=workflow%3ATest)
[![reviewdog](https://github.com/ekline-io/ekline-github-action/workflows/reviewdog/badge.svg)](https://github.com/ekline-io/ekline-github-action/actions?query=workflow%3Areviewdog)
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
      Filtering mode for the reviewdog command [added,diff_context,file,nofilter].
      Default is added.
    default: 'added'
  github_token:
    description: 'GITHUB_TOKEN'
    default: '${{ secrets.github_token }}'
  reporter:
    description: 'Reporter of reviewdog command [github-pr-check,github-check,github-pr-review].'
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
