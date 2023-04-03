#!/bin/sh
set -e

if [ "$GITLAB_CI" = "true" ]; then
  input_workspace="$CI_PROJECT_DIR"
  rd_api_token="$INPUT_GITLAB_TOKEN"
  disable_suggestions="--no-suggestion"
elif [ "$GITHUB_ACTIONS" = "true" ]; then
  input_workspace="$GITHUB_WORKSPACE"
  rd_api_token="$INPUT_GITHUB_TOKEN"
  disable_suggestions=""
else
  echo "Not running in GitLab CI or GitHub Actions"
  exit 1
fi

if [ -n "${input_workspace}" ] ; then
  cd "${input_workspace}/${INPUT_WORKDIR}" || exit
  git config --global --add safe.directory "${input_workspace}" || exit 1
fi

export REVIEWDOG_GITLAB_API_TOKEN="${rd_api_token}"
export REVIEWDOG_GITHUB_API_TOKEN="${rd_api_token}"

output="ekOutput.jsonl"
ekline -cd "${INPUT_CONTENT_DIR}" -et "${INPUT_EK_TOKEN}"  -o "${output}" "${disable_suggestions}"

< "$output" reviewdog -f="rdjsonl" \
  -name="EkLine" \
  -reporter="${INPUT_REPORTER}" \
  -filter-mode="${INPUT_FILTER_MODE}" \
  ${INPUT_REVIEWDOG_FLAGS}