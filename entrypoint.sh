#!/bin/sh
set -e

if [ -n "${GITHUB_WORKSPACE}" ] ; then
  cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit
  git config --global --add safe.directory "${GITHUB_WORKSPACE}" || exit 1
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

output="ekOutput.jsonl"
ekline -cd "${INPUT_CONTENT_DIR}" -et "${INPUT_EK_TOKEN}"  -o "${output}"

< "$output" reviewdog -f="rdjsonl" \
      -name="EkLine" \
      -reporter="${INPUT_REPORTER}" \
      -filter-mode="${INPUT_FILTER_MODE}" \
      ${INPUT_REVIEWDOG_FLAGS}
