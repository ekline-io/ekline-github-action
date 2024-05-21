#!/bin/sh
set -e

setGithubPullRequestId() {
  is_pull_request="$(echo "$GITHUB_REF" | awk -F / '{print $2}')"
  if [ "${is_pull_request}" = "pull" ]; then
    pull_request_id="$(echo "$GITHUB_REF" | awk -F / '{print $3}')"
  else
    pull_request_id=""
  fi
}
if [ "$GITLAB_CI" = "true" ]; then
  input_workspace="$CI_PROJECT_DIR"
  rd_api_token="$INPUT_GITLAB_TOKEN"
  disable_suggestions="--no-suggestion"
  ci_platform="gitlab"
  git_repository_id="$CI_PROJECT_ID"
  pull_request_id="$CI_MERGE_REQUEST_IID"
  workflow_run_id="$CI_PIPELINE_ID"
  git_user_id="$GITLAB_USER_ID"
elif [ "$GITHUB_ACTIONS" = "true" ]; then
  input_workspace="$GITHUB_WORKSPACE"
  rd_api_token="$INPUT_GITHUB_TOKEN"
  disable_suggestions=""
  ci_platform="github"
  git_repository_id="$GITHUB_REPOSITORY_ID"
  setGithubPullRequestId
  workflow_run_id="$GITHUB_RUN_ID"
  git_user_id="$GITHUB_ACTOR_ID"
elif [ "$CI" = "true" ] && [ -n "$BITBUCKET_BUILD_NUMBER" ]; then
  input_workspace="$BITBUCKET_CLONE_DIR"
  disable_suggestions=""
  ci_platform="bitbucket"
  git_repository_id="$BITBUCKET_REPO_UUID"
  pull_request_id="$BITBUCKET_PR_ID"
  workflow_run_id="$BITBUCKET_PIPELINE_UUID"
  git_user_id="$BITBUCKET_STEP_TRIGGERER_UUID"
else
  echo "Not running in GitLab CI or GitHub Actions or Bitbucket"
  exit 1
fi

if [ -n "${input_workspace}" ] ; then
  cd "${input_workspace}/${INPUT_WORKDIR}" || exit
  git config --global --add safe.directory "${input_workspace}" || exit 1
fi

export REVIEWDOG_GITLAB_API_TOKEN="${rd_api_token}"
export REVIEWDOG_GITHUB_API_TOKEN="${rd_api_token}"
export CI_PLATFORM="${ci_platform}"
export GIT_REPOSITORY_ID="${git_repository_id}"
export PULL_REQUEST_ID="${pull_request_id}"
export WORKFLOW_RUN_ID="${workflow_run_id}"
export GIT_USER_ID="${git_user_id}"

output="ekOutput.jsonl"
ekline -cd "${INPUT_CONTENT_DIR}" -et "${INPUT_EK_TOKEN}"  -o "${output}" -i "${INPUT_IGNORE_RULE}" "${disable_suggestions}"

LEVEL=${INPUT_LEVEL:-info}

< "$output" reviewdog -f="rdjsonl" \
  -name="EkLine" \
  -reporter="${INPUT_REPORTER}" \
  -filter-mode="${INPUT_FILTER_MODE}" \
  -level="${LEVEL}" \
  ${INPUT_REVIEWDOG_FLAGS}
