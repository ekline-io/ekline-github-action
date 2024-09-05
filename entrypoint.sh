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
  enable_ai_suggestions="$INPUT_ENABLE_AI_SUGGESTIONS"
  base_branch="${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}"
  head_branch="${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME}"
elif [ "$GITHUB_ACTIONS" = "true" ]; then
  input_workspace="$GITHUB_WORKSPACE"
  rd_api_token="$INPUT_GITHUB_TOKEN"
  disable_suggestions=""
  ci_platform="github"
  git_repository_id="$GITHUB_REPOSITORY_ID"
  setGithubPullRequestId
  workflow_run_id="$GITHUB_RUN_ID"
  git_user_id="$GITHUB_ACTOR_ID"
  enable_ai_suggestions="$INPUT_ENABLE_AI_SUGGESTIONS"
  base_branch="${GITHUB_BASE_REF}"
  head_branch="${GITHUB_HEAD_REF}"
elif [ "$CI" = "true" ] && [ -n "$BITBUCKET_BUILD_NUMBER" ]; then
  input_workspace="$BITBUCKET_CLONE_DIR"
  disable_suggestions=""
  ci_platform="bitbucket"
  git_repository_id="$BITBUCKET_REPO_UUID"
  pull_request_id="$BITBUCKET_PR_ID"
  workflow_run_id="$BITBUCKET_PIPELINE_UUID"
  git_user_id="$BITBUCKET_STEP_TRIGGERER_UUID"
  enable_ai_suggestions="$INPUT_ENABLE_AI_SUGGESTIONS"
  base_branch="${BITBUCKET_PR_DESTINATION_BRANCH}"
  head_branch="${BITBUCKET_BRANCH}"
  export INPUT_REPORTER='bitbucket-code-report'
  export INPUT_FILTER_MODE='nofilter'
else
  echo "Not running in GitLab CI or GitHub Actions or Bitbucket"
  exit 1
fi

if [ -n "${input_workspace}" ] ; then
  cd "${input_workspace}/${INPUT_WORKDIR}" || { echo "Failed to get ${input_workspace}/${INPUT_WORKDIR}"; exit 1; }
  git config --global --add safe.directory "${input_workspace}" || exit 1
fi

if [ "${pull_request_id}" ]; then
  if [ "$GITLAB_CI" = "true" ]; then
    if [ "$CI_MERGE_REQUEST_SOURCE_PROJECT_URL" = "$CI_PROJECT_URL" ]; then
      git fetch origin "${base_branch}:${base_branch}" "${head_branch}:${head_branch}" || { echo "Failed to fetch branches from the repository"; exit 1; }
    else
      git fetch origin "${base_branch}:${base_branch}" || { echo "Failed to fetch base branch ${base_branch} from upstream"; exit 1; }
      git remote add fork "${CI_MERGE_REQUEST_SOURCE_PROJECT_URL}" || { echo "Failed to add fork as remote"; exit 1; }
      git fetch fork "${head_branch}:${head_branch}" || { echo "Failed to fetch head branch ${head_branch} from fork"; exit 1; }
    fi
  elif [ "$GITHUB_ACTIONS" = "true" ]; then
    if [ -f "$GITHUB_EVENT_PATH" ]; then
      head_repo_url=$(cat "$GITHUB_EVENT_PATH" | grep '"clone_url"' | head -n 1 | awk -F '"clone_url":' '{print $2}' | tr -d '", ')
      base_repo_url=$(cat "$GITHUB_EVENT_PATH" | grep '"repo"' | head -n 1 | awk -F '"url":' '{print $2}' | tr -d '", ')

      if [ "$head_repo_url" != "$base_repo_url" ]; then
        echo "PR is from a forked repository: $head_repo_url"
        git fetch origin "${base_branch}:${base_branch}" || { echo "Failed to fetch base branch ${base_branch} from upstream"; exit 1; }

        git remote add fork "$head_repo_url" || { echo "Failed to add fork as remote"; exit 1; }
        git fetch fork "${head_branch}:${head_branch}" || { echo "Failed to fetch head branch ${head_branch} from fork"; exit 1; }
      fi
    fi
  elif [ "$CI" = "true" ] && [ -n "$BITBUCKET_BUILD_NUMBER" ]; then
    origin_url=$(git remote get-url origin)
    upstream_url=$(git remote get-url upstream 2>/dev/null || echo "")
    if [ "$origin_url" != "$upstream_url" ] && [ "$upstream_url" != "" ] ; then
      git fetch upstream "${base_branch}:${base_branch}" || { echo "Failed to fetch base branch ${base_branch} from upstream"; exit 1; }
      git fetch origin "${head_branch}:${head_branch}" || { echo "Failed to fetch head branch ${head_branch} from fork"; exit 1; }
    else
      git checkout --detach || { echo "Failed to detach HEAD"; exit 1; }
    fi
  fi
  git fetch origin "${base_branch}:${base_branch}" "${head_branch}:${head_branch}" || { echo "Failed to fetch branches"; exit 1; }
  if [ -f "$(git rev-parse --git-dir)/shallow" ]; then
    git fetch --unshallow || { echo "Failed to unshallow the repository"; exit 1; }
  fi
  if [ -n "${base_branch}" ] && [ -n "${head_branch}" ]; then
    changed_files=$(git diff --name-only "${base_branch}" "${head_branch}") || { echo "Failed to get changed files: ${base_branch}..${head_branch}"; exit 1; }
    echo "Changed files in this PR are:"
  else
    echo "Base branch or head branch is not specified."
    exit 1
  fi
else
  changed_files=""
fi

echo "${changed_files}"

set -- ${changed_files}


export REVIEWDOG_GITLAB_API_TOKEN="${rd_api_token}"
export REVIEWDOG_GITHUB_API_TOKEN="${rd_api_token}"
export CI_PLATFORM="${ci_platform}"
export GIT_REPOSITORY_ID="${git_repository_id}"
export PULL_REQUEST_ID="${pull_request_id}"
export WORKFLOW_RUN_ID="${workflow_run_id}"
export GIT_USER_ID="${git_user_id}"
export EKLINE_APP_URL="https://ekline.io"
export EXTERNAL_JOB_ID=$(uuidgen)
export EKLINE_APP_NAME="${ci_platform}"
export EKLINE_APP_VERSION=$(node -p -e "require('./package.json').version")

output="ekOutput.jsonl"
ai_suggestions=""
if [ -n "${pull_request_id}" ] || [ "$enable_ai_suggestions" = "true" ] ; then
  ai_suggestions="--ai-suggestions"
fi
cf_option=""
if [ -n "${changed_files}" ]; then
  cf_option="-cf $@"
fi


ekline -cd "${INPUT_CONTENT_DIR}" -et "${INPUT_EK_TOKEN}" ${cf_option} -o "${output}" -i "${INPUT_IGNORE_RULE}" "${disable_suggestions}" "${ai_suggestions}"

if [ -s "$output" ]; then
  if [ "$GITHUB_ACTIONS" = "true" ]; then
    export REPOSITORY_OWNER="$GITHUB_REPOSITORY_OWNER"
    export REPOSITORY="$GITHUB_REPOSITORY"
    (cd /code && npm run comment:github)
  fi

  LEVEL=${INPUT_LEVEL:-info}

  < "$output" reviewdog -f="rdjsonl" \
    -name="EkLine" \
    -reporter="${INPUT_REPORTER}" \
    -filter-mode="${INPUT_FILTER_MODE}" \
    -level="${LEVEL}" \
    ${INPUT_REVIEWDOG_FLAGS}
else
  echo "No issues found."
fi
