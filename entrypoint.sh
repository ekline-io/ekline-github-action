#!/bin/sh
set -e

# Determine the CI environment
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


# Set workspace directory and safe.directory
if [ -n "${input_workspace}" ] ; then
  cd "${input_workspace}/${INPUT_WORKDIR}" || exit

  git config --global --add safe.directory "${input_workspace}" || exit 1
fi

# Set Review Dog API tokens for Gitlab and GitHub
export REVIEWDOG_GITLAB_API_TOKEN="${rd_api_token}"
export REVIEWDOG_GITHUB_API_TOKEN="${rd_api_token}"
export GITHUB_TOKEN="${rd_api_token}"

# Run Ekline to generate EkOutput
current_output="./EkOutput.jsonl"
ekline -cd "${INPUT_CONTENT_DIR}" -et "${INPUT_EK_TOKEN}"  -o "${current_output}" -i "${INPUT_IGNORE_RULE}" "${disable_suggestions}"

# Path to the historic reviewdog file
previous_feedback_file="./fetched-artifact/EkOutput.jsonl"
previous_feedback_directory="./fetched-artifact/"

if [ -e "$previous_feedback_file" ]; then
  echo "Previous feedback exists"
  # Temporary file for storing non-matching entries
  temp_file="ekoutput_filtered.jsonl"

  # Create a temporary directory for storing intermediate files
  temp_dir=$(mktemp -d)

  # Build a hash table of entries from the running feedback log
  while IFS= read -r other_entry; do
    # Extract line, location, and error type from the entry
    line=$(echo "$other_entry" | jq -r '.location.range.start.line')
    location=$(echo "$other_entry" | jq -r '.location.path')
    error_type=$(echo "$other_entry" | grep -oE '\[EK[0-9]{5}\]' | head -n1 | tr -d '[]')

    # Generate a hash key based on line, location, and error type
    hash_key="${line}_${location}_${error_type}"

    # Create a temporary file for the hash key if it doesn't exist
    hash_file="$temp_dir/$hash_key"
    mkdir -p "$(dirname "$hash_file")"
    touch "$hash_file"

    # Append the entry to the hash file
    echo "$other_entry" >> "$hash_file"
  done < "$previous_feedback_file"

  # Iterate through the entries in the new feedback
  while IFS= read -r entry; do
    # Extract line, location, and error type from the entry
    line=$(echo "$entry" | jq -r '.location.range.start.line')
    location=$(echo "$entry" | jq -r '.location.path')
    error_type=$(echo "$entry" | grep -oE '\[EK[0-9]{5}\]' | head -n1 | tr -d '[]')

    # Generate a hash key based on line, location, and error type
    hash_key="${line}_${location}_${error_type}"

    # Check if the hash file for the hash key exists
    hash_file="$temp_dir/$hash_key"
    if [ -f "$hash_file" ]; then
      # Match found, skip this entry
      continue
    fi

    # Append non-matching entries to the file that stores unique entries
    echo "$entry" >> "$temp_file"

    # Append non-matching entries to the file that will store a running feedback log
    echo "$entry" >> "$previous_feedback_file"
  done < "$current_output"

  if [ -f "$temp_file" ]; then
    # Replace current feedback with the unique feedback file
    mv "$temp_file" "$current_output"
  else
    # This means that we have no unique entries in this run, so blank out the feedback file
    > "$current_output"
  fi
  # Clean up temporary directory
  rm -rf "$temp_dir"
else
  echo "No previous feedback exists"
  # No historical data, so we make current output = historical output to be saved
    if [ -f "$current_output" ]; then
      # The file exists, so the copy is possible, else nothing to do
      mkdir -p "$previous_feedback_directory"
      cp "$current_output" "$previous_feedback_file"
    fi
fi

LEVEL=${INPUT_LEVEL:-info}
< "$current_output" reviewdog -f="rdjsonl" \
  -name="EkLine" \
  -reporter="${INPUT_REPORTER}" \
  -filter-mode="${INPUT_FILTER_MODE}" \
  -level="${LEVEL}" \
  ${INPUT_REVIEWDOG_FLAGS}