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

export REVIEWDOG_GITLAB_API_TOKEN="${rd_api_token}"
export REVIEWDOG_GITHUB_API_TOKEN="${rd_api_token}"
export GITHUB_TOKEN="${rd_api_token}"

output="ekOutput.jsonl"
ekline -cd "${INPUT_CONTENT_DIR}" -et "${INPUT_EK_TOKEN}"  -o "${output}" -i "${INPUT_IGNORE_RULE}" "${disable_suggestions}"

# Path to the fresh comment file
ekoutput_file="./EkOutput.jsonl"

# Path to the historic reviewdog file
other_file="./fetched-artifact/EkOutput.jsonl"

# Temporary file for storing non-matching entries
temp_file="./ekoutput_filtered.jsonl"

# Create a temporary directory for storing intermediate files
temp_dir=$(mktemp -d)

 # Build a hash table of entries from the second file
 while IFS= read -r other_entry; do
   echo "Processing entry: $other_entry"

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
 done < "$other_file"

 # Iterate through the entries in the first file
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

   # Append non-matching entries to the temporary file
   echo "$entry" >> "$temp_file"
 done < "$ekoutput_file"

 # Replace the original file with the filtered entries if it exists
 if [ -e "$temp_file" ]; then
   mv "$temp_file" "$ekoutput_file"
 fi

 # Clean up temporary directory
 rm -rf "$temp_dir"

 LEVEL=${INPUT_LEVEL:-info}


< "$output" reviewdog -f="rdjsonl" \
  -name="EkLine" \
  -reporter="${INPUT_REPORTER}" \
  -filter-mode="${INPUT_FILTER_MODE}" \
  -level="${LEVEL}" \
  ${INPUT_REVIEWDOG_FLAGS}