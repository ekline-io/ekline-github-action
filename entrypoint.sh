#!/bin/sh
set -e

if [ -n "${GITHUB_WORKSPACE}" ] ; then
  cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit
  git config --global --add safe.directory "${GITHUB_WORKSPACE}" || exit 1
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
echo "${INPUT_EK_TOKEN}"
echo "${INPUT_CONTENT_DIR}"
echo "${INPUT_WORKDIR}"


get_content_dir() {
  if [ -z "$1" ]; then
    echo "$2"
  else
    echo "$1"
  fi
}

vale_template="/files/vale/rdjsonl.tmpl"
vale_output="ek_vale_output.txt"
work_dir="${INPUT_WORKDIR}"
ek_token="${INPUT_EK_TOKEN}"

content_dir=$(get_content_dir "${INPUT_CONTENT_DIR}" "${INPUT_WORKDIR}")


# TODO: Here we should access the token for a company, and download their documentation checks
# We could also download their configuration of working directory and others.

ls -lR /files
# TODO: Here we should run different package for all the different kind of checks

## Executing vale
vale sync
vale "$content_dir" --output="$vale_template" >> "$vale_output"

< ekline_vale_output.txt reviewdog -efm="%f:%l:%c: %m" \
      -name="EkLineReviewer" \
      -reporter="${INPUT_REPORTER:-github-pr-check}" \
      -filter-mode="${INPUT_FILTER_MODE}" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_FLAGS}
