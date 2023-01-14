#!/bin/sh
set -e

if [ -n "${GITHUB_WORKSPACE}" ] ; then
  cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit
  git config --global --add safe.directory "${GITHUB_WORKSPACE}" || exit 1
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

# TODO: Here we should access the token for a company, and download their documentation checks
# We could also download their configuration of working directory and others.


# TODO: Here we should run different package for all the different kind of checks

vale src/content/ --output=rdjsonl.tmpl . \
  | reviewdog -efm="%f:%l:%c: %m" \
      -name="EkLineReviewer" \
      -reporter="${INPUT_REPORTER:-github-pr-check}" \
      -filter-mode="${INPUT_FILTER_MODE}" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_FLAGS}
