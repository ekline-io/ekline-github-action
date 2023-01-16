#!/bin/sh
set -e -o xtrace

get_content_dir() {
  if [ -z "$1" ]; then
    echo "$2"
  else
    echo "$1"
  fi
}

run_language_checks() {
  vale sync
  vale "$content_dir" --output="$vale_template" >> "$vale_output"
}


if [ -n "${GITHUB_WORKSPACE}" ] ; then
  cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit
  git config --global --add safe.directory "${GITHUB_WORKSPACE}" || exit 1
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
echo "ek_token=${INPUT_EK_TOKEN}"
echo "content_dir=${INPUT_CONTENT_DIR}"
echo "work_dir=${INPUT_WORKDIR}"

vale_template="/files/vale/rdjsonl.tmpl"
vale_output="ek_vale_output.txt"

content_dir=$(get_content_dir "${INPUT_CONTENT_DIR}" "${INPUT_WORKDIR}")

pwd
run_language_checks

cat $vale_output | reviewdog -efm="%f:%l:%c: %m" \
      -name="EkLineReviewer" \
      -reporter="${INPUT_REPORTER:-github-pr-check}" \
      -filter-mode="${INPUT_FILTER_MODE}" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_FLAGS}
