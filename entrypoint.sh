#!/bin/sh
set -e

# Function to print all INPUT_ variables if debug mode is enabled.
# Caution: This will print all secrets as well. Use it cautiously.
print_debug_info() {
  if [ "$INPUT_DEBUG" = "true" ]; then
    echo "Debug Mode: Printing all INPUT_ variables"
    env | grep '^INPUT_' | while IFS= read -r var; do
      echo "$var"
    done
  fi
}

fetchBranchFromFork() {
  local fork_remote="$1"
  local source_branch="$2"
  local target_branch="$3"
  
  if [ "$INPUT_DEBUG" = "true" ]; then
    echo "Available branches in ${fork_remote} remote:"
    git ls-remote --heads "${fork_remote}"
  fi
  
  if git fetch "${fork_remote}" "${source_branch}:${target_branch}" 2>/dev/null; then
    echo "Successfully fetched branch from fork"
    return 0
  fi
  
  if git fetch "${fork_remote}" "refs/heads/${source_branch}:refs/heads/${target_branch}" 2>/dev/null; then
    echo "Successfully fetched branch using refs/heads prefix"
    return 0
  fi
  
  echo "Failed to fetch branch ${source_branch} from ${fork_remote}. Aborting."
  return 1
}

setupForkRemote() {
  local remote_name="$1"
  local remote_url="$2"
  
  echo "Setting up ${remote_name} remote with URL: ${remote_url}"
  
  if git remote | grep -q "^${remote_name}$"; then
    local current_url
    current_url=$(git remote get-url "${remote_name}" 2>/dev/null)
    
    if [ "$current_url" != "$remote_url" ]; then
      echo "Remote ${remote_name} exists with different URL, updating it"
      git remote remove "${remote_name}"
      git remote add "${remote_name}" "${remote_url}" || { echo "Failed to add ${remote_name} as remote"; return 1; }
    else
      echo "Remote ${remote_name} already exists with correct URL"
    fi
  else
    git remote add "${remote_name}" "${remote_url}" || { echo "Failed to add ${remote_name} as remote"; return 1; }
  fi
  
  return 0
}

handle_shallow_repository() {
  if [ -f "$(git rev-parse --git-dir)/shallow" ]; then
    if [ -n "${base_branch}" ] && [ -n "${head_branch}" ]; then
      echo "Repository is shallow, attempting to fetch history if necessary..."

      # Check if merge base exists
      if git merge-base "${base_branch}" "${head_branch}" > /dev/null 2>&1; then
        echo "Merge base found in current shallow history. Assuming sufficient history."
      else
        echo "Merge base not found. Attempting to fetch recent history..."
        
        # Function to unshallow the repository (used as fallback)
        unshallow_repo() {
          echo "Unshallowing the entire repository..."
          git fetch --unshallow || { echo "Failed to unshallow the repository"; return 1; } 
          echo "Repository fully unshallowed."
          return 0
        }
        
        # Try to fetch recent history first
        if ! months_ago=$(cd /code && npm run get:dateMonthsAgo --silent -- 3); then
          echo "Failed to get date, falling back to full unshallow"
          unshallow_repo || return 1 
        elif ! git fetch --shallow-since="$months_ago"; then
          echo "Failed to fetch commits for the last 3 months using --shallow-since."
          # Even if fetch failed partially, try merge-base again before full unshallow
          if ! git merge-base "${base_branch}" "${head_branch}" > /dev/null 2>&1; then
             echo "Merge base still not found after attempting --shallow-since fetch. Falling back to full unshallow."
             unshallow_repo || return 1 
          else
             echo "Merge base found after fetching recent history."
          fi
        # Check merge-base again after successful shallow-since fetch
        elif ! git merge-base "${base_branch}" "${head_branch}" > /dev/null 2>&1; then
          echo "Merge base still not found after fetching recent history. Falling back to full unshallow."
          unshallow_repo || return 1 
        else
          echo "Successfully fetched necessary history (found merge base)."
        fi
      fi
    else
      echo "Repository is shallow but branch info unavailable. Unshallowing the entire repository..."
      git fetch --unshallow || { echo "Failed to unshallow the repository"; return 1; } 
    fi
  fi
  return 0
}


setGithubPullRequestId() {
  is_pull_request="$(echo "$GITHUB_REF" | awk -F / '{print $2}')"
  if [ "${is_pull_request}" = "pull" ]; then
    pull_request_id="$(echo "$GITHUB_REF" | awk -F / '{print $3}')"
  else
    pull_request_id=""
  fi
}

main() {
  print_debug_info

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
  triggering_actor="$GITLAB_USER_NAME"
  if [ -n "$pull_request_id" ]; then
    pr_creator=$(curl -s --header "PRIVATE-TOKEN: $rd_api_token" \
      "https://gitlab.com/api/v4/projects/${git_repository_id}/merge_requests/${pull_request_id}" | jq -r '.author.id')
  else
    echo "Not a merge request; cannot fetch PR creator."
  fi
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
  triggering_actor="$GITHUB_TRIGGERING_ACTOR"
  if [ -n "$pull_request_id" ]; then
    pr_creator=$(curl -s -H "Authorization: token $rd_api_token" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${pull_request_id}" | jq -r '.user.id')
  else
    echo "Not a pull request; cannot fetch PR creator."
  fi
  cd /code
  triggering_actor=$(npm run get:userId --silent)

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
  triggering_actor="$BITBUCKET_STEP_TRIGGERER_UUID"
else
  echo "Not running in GitLab CI or GitHub Actions or Bitbucket"
  exit 1
fi

if [ -z "$pull_request_id" ]; then
  if [ "$ci_platform" = "github" ]; then
    resolved_branch="$(echo "$GITHUB_REF" | sed 's|refs/heads/||')"
    base_branch="$resolved_branch"
    head_branch="$resolved_branch"
  elif [ "$ci_platform" = "gitlab" ]; then
    resolved_branch="$CI_COMMIT_BRANCH"
    base_branch="$resolved_branch"
    head_branch="$resolved_branch"
  elif [ "$ci_platform" = "bitbucket" ]; then
    resolved_branch="$BITBUCKET_BRANCH"
    base_branch="$resolved_branch"
    head_branch="$resolved_branch"
  fi
fi

if [ -n "${input_workspace}" ] ; then
  cd "${input_workspace}/${INPUT_WORKDIR}" || { echo "Failed to get ${input_workspace}/${INPUT_WORKDIR}"; exit 1; }
  git config --global --add safe.directory "${input_workspace}" || exit 1
  
  # Disable quoting of non-ASCII characters (e.g. \342\200\257) so we get raw UTF-8 filenames.
  # Without this, git outputs octal escapes which causes "file not found" errors in downstream tools.
  git config --global core.quotePath false || exit 1
fi

if [ "${pull_request_id}" ]; then
  if [ "$GITLAB_CI" = "true" ]; then
    if [ "$CI_MERGE_REQUEST_SOURCE_PROJECT_URL" = "$CI_PROJECT_URL" ]; then
      echo "Same-project merge request"
      git fetch origin "${base_branch}:${base_branch}" "${head_branch}:${head_branch}" || { echo "Failed to fetch branches from the repository"; exit 1; }
    else
      echo "Processing cross-project merge request from fork"
      echo "Base branch: ${base_branch}, Head branch: ${head_branch}"
      echo "Source project URL: ${CI_MERGE_REQUEST_SOURCE_PROJECT_URL}"
      
      git fetch origin "${base_branch}:${base_branch}" || { echo "Failed to fetch base branch ${base_branch} from upstream"; exit 1; }
      
      if ! setupForkRemote "fork" "${CI_MERGE_REQUEST_SOURCE_PROJECT_URL}"; then
        exit 1
      fi
      
      if ! fetchBranchFromFork "fork" "${head_branch}" "${head_branch}"; then
        exit 1
      fi
    fi
  elif [ "$GITHUB_ACTIONS" = "true" ]; then
    if [ -f "$GITHUB_EVENT_PATH" ]; then
      head_repo_url=$(cat "$GITHUB_EVENT_PATH" | jq -r '.pull_request.head.repo.clone_url')
      base_repo_url=$(cat "$GITHUB_EVENT_PATH" | jq -r '.pull_request.base.repo.clone_url')

      if [ "$INPUT_DEBUG" = "true" ]; then
        echo "head_repo_url: $head_repo_url"
        echo "base_repo_url: $base_repo_url"
        cat "$GITHUB_EVENT_PATH"
      fi
      
      if [ "$head_repo_url" != "$base_repo_url" ]; then
        echo "PR is from a forked repository: $head_repo_url"
        
        git fetch origin "${base_branch}:${base_branch}" || { echo "Failed to fetch base branch ${base_branch} from upstream"; exit 1; }

        if ! setupForkRemote "fork" "$head_repo_url"; then
          exit 1
        fi
        
        if ! fetchBranchFromFork "fork" "${head_branch}" "${head_branch}"; then
          exit 1
        fi
      else
        git fetch origin "${base_branch}:${base_branch}" "${head_branch}:${head_branch}" || { echo "Failed to fetch branches from origin"; exit 1; }
      fi
    else
      git fetch origin "${base_branch}:${base_branch}" "${head_branch}:${head_branch}" || { echo "Failed to fetch branches from origin"; exit 1; }
    fi
  elif [ "$CI" = "true" ] && [ -n "$BITBUCKET_BUILD_NUMBER" ]; then
    origin_url=$(git remote get-url origin)
    upstream_url=$(git remote get-url upstream 2>/dev/null || echo "")
    if [ "$origin_url" != "$upstream_url" ] && [ "$upstream_url" != "" ] ; then
      echo "Processing Bitbucket cross-repository PR"
      
      git fetch upstream "${base_branch}:${base_branch}" || { echo "Failed to fetch base branch ${base_branch} from upstream"; exit 1; }
      
      # Bitbucket Pipelines automatically configures origin to point to the fork
      echo "Using existing origin as fork remote"
      
      if ! fetchBranchFromFork "origin" "${head_branch}" "${head_branch}"; then
        exit 1
      fi
    else
      git checkout --detach || { echo "Failed to detach HEAD"; exit 1; }
      git fetch origin "${base_branch}:${base_branch}" "${head_branch}:${head_branch}" || { echo "Failed to fetch branches from origin"; exit 1; }
    fi
  fi
  
  handle_shallow_repository || exit 1

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
export EKLINE_TRIGGERING_ACTOR="${triggering_actor}"
export EKLINE_PR_CREATOR="${pr_creator}"
export EKLINE_GIT_SOURCE_BRANCH="${head_branch}"
export EKLINE_GIT_TARGET_BRANCH="${base_branch}"

output="ekOutput.jsonl"
ai_suggestions=""
if [ -n "${pull_request_id}" ] || [ "$enable_ai_suggestions" = "true" ] ; then
  ai_suggestions="--ai-suggestions"
fi

cf_option=""
if [ -n "${changed_files}" ]; then
    cf_option=$(cd /code && npm run build:cfOption --silent -- "${changed_files}")
fi

ekline_args=""
while IFS= read -r dir; do
  if [ -n "$dir" ]; then
    ekline_args="$ekline_args -cd \"$dir\""
  fi
done <<EOF
$INPUT_CONTENT_DIR
EOF

if [ -n "$INPUT_OPENAPI_SPEC" ]; then
    ekline_args="$ekline_args -oas \"$INPUT_OPENAPI_SPEC\""
fi

exclude_dirs=""
if [ -n "$INPUT_EXCLUDE_DIRECTORIES" ]; then
    while IFS= read -r dir; do
        dir=$(echo "$dir" | xargs)  
        if [ -n "$dir" ]; then
            if [ -z "$exclude_dirs" ]; then
                exclude_dirs="-ed"
            fi
            exclude_dirs="$exclude_dirs '$dir'"
        fi
    done <<EOF
$INPUT_EXCLUDE_DIRECTORIES
EOF
fi

exclude_files=""
if [ -n "$INPUT_EXCLUDE_FILES" ]; then
    while IFS= read -r file; do
        file=$(echo "$file" | xargs)  
        if [ -n "$file" ]; then
            if [ -z "$exclude_files" ]; then
                exclude_files="-ef"
            fi
            exclude_files="$exclude_files '$file'"
        fi
    done <<EOF
$INPUT_EXCLUDE_FILES
EOF
fi

debug_flag=""
if [ "$INPUT_DEBUG" = "true" ]; then
    debug_flag="--debug"
fi

ekline_command="ekline $ekline_args -et \"${INPUT_EK_TOKEN}\" ${cf_option} ${exclude_dirs} ${exclude_files} -o \"${output}\" -i \"${INPUT_IGNORE_RULE}\" ${disable_suggestions} ${ai_suggestions} ${debug_flag}"
eval "$ekline_command"


if [ -s "$output" ]; then
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

# Always post GitHub comment for PRs (positive or with issues)
if [ "$GITHUB_ACTIONS" = "true" ] && [ -n "$pull_request_id" ]; then
  export REPOSITORY_OWNER="$GITHUB_REPOSITORY_OWNER"
  export REPOSITORY="$GITHUB_REPOSITORY"
  (cd /code && npm run comment:github)
fi
}

if [ -z "$SOURCED_FOR_TEST" ]; then
  main "$@"
fi