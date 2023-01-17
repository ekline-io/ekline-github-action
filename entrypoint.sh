#!/bin/sh
set -e

if [ -n "${GITHUB_WORKSPACE}" ] ; then
  cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit
  git config --global --add safe.directory "${GITHUB_WORKSPACE}" || exit 1
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
echo "input_ek_token=${INPUT_EK_TOKEN}"
echo "input_work_dir=${INPUT_WORKDIR}"
echo "input_content_dir=${INPUT_CONTENT_DIR}"

get_content_dir() {
  if [ -z "$1" ]; then
    echo "$2"
  else
    echo "$1"
  fi
}

content_dir=$(get_content_dir "${INPUT_CONTENT_DIR}" "${INPUT_WORKDIR}")
echo "content_dir=${content_dir}"

setup_vale_files(){
  ek_check_zip="ek_check.zip"
  unzip $ek_check_zip
}

vale_template="/files/vale/rdjsonl.tmpl"
vale_output="${INPUT_WORKDIR}/ek_vale_output.txt"

run_language_checks() {
  touch "$vale_output"
  setup_vale_files
  vale sync
  vale "$1" --output="$vale_template" --no-exit >> "$vale_output"
}

run_language_checks "$content_dir"

< "$vale_output" reviewdog -f="rdjsonl" \
      -name="EkLine Reviewer" \
      -reporter="${INPUT_REPORTER:-github-pr-check}" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
      -filter-mode="${INPUT_FILTER_MODE}" \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_FLAGS}
