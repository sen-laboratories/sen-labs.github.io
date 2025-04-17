#!/bin/bash

# Configuration

# Public environment variables

# YouTube channel ID for SEN Labs (e.g., UC_sen-labs)
YOUTUBE_CHANNEL_ID="UCRR013YJAj1i4qM_KYciNaw"

# GITHUB_ORG: GitHub organization name (e.g., sen-laboratories)
GITHUB_ORG="sen-laboratories"

# X_USER_ID: Static user ID for the X account to fetch tweets from
X_USER_ID="1384973683287105536"

# File paths (local to the script):
HTML_FILE="index_new.html"      # Path to the HTML file to update
TEMP_FILE="index_new_temp.html" # Temporary file for HTML updates

# Private environment variables - need to be provided by environment (or Github secrets for workflow)

# GITHUB_TOKEN: Optional GitHub personal access token for authenticated API access
# YOUTUBE_API_KEY: API key for YouTube Data API v3
# X_BEARER_TOKEN: Bearer token for X API v2 authentication

# Check for required environment variables
REQUIRED_VARS=("YOUTUBE_API_KEY" "X_BEARER_TOKEN")
for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR}" ]; then
    echo "Error: Required environment variable $VAR is not set."
    exit 1
  fi
done

# Parse command-line flag
EXCLUDE_WEB_REPO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --exclude-web-repo)
      EXCLUDE_WEB_REPO=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Ensure required tools are installed
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed. Please install jq."
  exit 1
fi
if ! command -v curl &> /dev/null; then
  echo "Error: curl is required but not installed. Please install curl."
  exit 1
fi

# Initialize preview variables with fallback content
YOUTUBE_PREVIEW='<span>No video loaded</span>'
GITHUB_PREVIEW='<span>No commit loaded</span>'
X_PREVIEW='<span>No post loaded</span>'

# Function to fetch the latest YouTube video
fetch_youtube_video() {
  echo "Fetching latest YouTube video..."
  CHANNEL_RESPONSE=$(curl -s "https://youtube.googleapis.com/youtube/v3/channels?part=contentDetails&id=${YOUTUBE_CHANNEL_ID}&key=${YOUTUBE_API_KEY}")
  UPLOADS_PLAYLIST_ID=$(echo "$CHANNEL_RESPONSE" | jq -r '.items[0].contentDetails.relatedPlaylists.uploads')

  if [ -z "$UPLOADS_PLAYLIST_ID" ]; then
    echo "Failed to fetch uploads playlist ID."
    return 1
  fi

  VIDEO_RESPONSE=$(curl -s "https://youtube.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=${UPLOADS_PLAYLIST_ID}&maxResults=1&key=${YOUTUBE_API_KEY}")
  VIDEO_ID=$(echo "$VIDEO_RESPONSE" | jq -r '.items[0].snippet.resourceId.videoId')
  VIDEO_TITLE=$(echo "$VIDEO_RESPONSE" | jq -r '.items[0].snippet.title')

  if [ -z "$VIDEO_ID" ]; then
    echo "Failed to fetch latest video."
    return 1
  fi

  echo "Latest YouTube video: $VIDEO_TITLE (ID: $VIDEO_ID)"
  YOUTUBE_PREVIEW="<img src=\"https://img.youtube.com/vi/${VIDEO_ID}/0.jpg\" alt=\"${VIDEO_TITLE}\">"
  return 0
}

# Function to fetch the latest commit across all public repos in the organization
fetch_github_data() {
  echo "Fetching latest GitHub commit..."
  AUTH_HEADER=""
  if [ -n "$GITHUB_TOKEN" ]; then
    AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
  fi

  REPOS_RESPONSE=$(curl -s -H "$AUTH_HEADER" "https://api.github.com/orgs/${GITHUB_ORG}/repos?type=public&sort=updated&per_page=100")
  REPO_NAMES=($(echo "$REPOS_RESPONSE" | jq -r '.[].name'))

  if [ ${#REPO_NAMES[@]} -eq 0 ]; then
    echo "Failed to fetch repositories."
    return 1
  fi

  LATEST_COMMIT_DATE=""
  COMMIT_MESSAGE=""
  COMMIT_SHA=""
  COMMIT_REPO=""

  for REPO in "${REPO_NAMES[@]}"; do
    # Skip sen-labs.github.io if --exclude-web-repo is set
    if [ "$EXCLUDE_WEB_REPO" -eq 1 ] && [ "$REPO" = "sen-labs.github.io" ]; then
      continue
    fi
    COMMIT_RESPONSE=$(curl -s -H "$AUTH_HEADER" "https://api.github.com/repos/${GITHUB_ORG}/${REPO}/commits?per_page=1")
    COMMIT_DATE=$(echo "$COMMIT_RESPONSE" | jq -r '.[0].commit.committer.date')
    if [ -n "$COMMIT_DATE" ] && { [ -z "$LATEST_COMMIT_DATE" ] || [ "$COMMIT_DATE" \> "$LATEST_COMMIT_DATE" ]; }; then
      LATEST_COMMIT_DATE="$COMMIT_DATE"
      COMMIT_MESSAGE=$(echo "$COMMIT_RESPONSE" | jq -r '.[0].commit.message')
      COMMIT_SHA=$(echo "$COMMIT_RESPONSE" | jq -r '.[0].sha' | cut -c 1-7)
      COMMIT_REPO="$REPO"
    fi
  done

  if [ -z "$COMMIT_MESSAGE" ]; then
    echo "Failed to fetch latest commit."
    return 1
  fi

  echo "Latest GitHub commit: $COMMIT_MESSAGE (SHA: $COMMIT_SHA, Repo: $COMMIT_REPO)"
  GITHUB_PREVIEW="<span style=\"font-family: 'IBM Plex Mono', monospace;\">${COMMIT_REPO}: ${COMMIT_MESSAGE}</span>"
  return 0
}

# Function to fetch the latest X post
fetch_x_post() {
  echo "Fetching latest X post..."
  RESPONSE=$(curl -v -s -w "\n%{http_code}" -H "Authorization: Bearer ${X_BEARER_TOKEN}" "https://api.twitter.com/2/users/${X_USER_ID}/tweets?max_results=10&exclude=retweets&tweet.fields=text")
  HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
  TWEET_RESPONSE=$(echo "$RESPONSE" | sed -e '$d')  # Remove status line to get JSON

  # Check for non-200 status or invalid JSON
  if [ "$HTTP_STATUS" -ne 200 ]; then
    ERROR_TITLE=$(echo "$TWEET_RESPONSE" | jq -r '.title // .errors[0].title // "Unknown Error"')
    ERROR_DETAIL=$(echo "$TWEET_RESPONSE" | jq -r '.detail // .errors[0].detail // "No details provided"')
    echo "Could not get latest post from X, got HTTP status $HTTP_STATUS: $ERROR_TITLE, detail: $ERROR_DETAIL"
    return 1
  fi

  # Check if response is empty or invalid JSON
  if [ -z "$TWEET_RESPONSE" ] || ! echo "$TWEET_RESPONSE" | jq -e . >/dev/null 2>&1; then
    echo "Could not get latest post from X, got invalid or empty response (possible curl error)"
    return 1
  fi

  TWEET_TEXT=$(echo "$TWEET_RESPONSE" | jq -r '.data[0].text // ""')

  if [ -z "$TWEET_TEXT" ]; then
    echo "Failed to fetch latest X post (no text found)."
    return 1
  fi

  TWEET_TEXT_TRUNCATED=$(echo "$TWEET_TEXT" | cut -c 1-50)
  if [ ${#TWEET_TEXT} -gt 50 ]; then
    TWEET_TEXT_TRUNCATED="${TWEET_TEXT_TRUNCATED}..."
  fi
  echo "Latest X post: $TWEET_TEXT_TRUNCATED"
  X_PREVIEW="<span>Latest Post: \"${TWEET_TEXT_TRUNCATED}\"</span>"
  return 0
}

# Fetch all data and update HTML sections independently
echo "Starting CTA update..."
UPDATE_NEEDED=0
cp "$HTML_FILE" "$TEMP_FILE"

if fetch_youtube_video; then
  echo "Updating YouTube section in $HTML_FILE..."
  sed "s|<span id=\"youtube-preview\">[^<]*</span>|<span id=\"youtube-preview\">${YOUTUBE_PREVIEW}</span>|g" "$TEMP_FILE" > "$TEMP_FILE.1"
  mv "$TEMP_FILE.1" "$TEMP_FILE"
  UPDATE_NEEDED=1
else
  echo "YouTube update skipped due to API failure."
fi

if fetch_github_data; then
  echo "Updating GitHub section in $HTML_FILE..."
  sed "s|<span id=\"github-preview\">[^<]*</span>|<span id=\"github-preview\">${GITHUB_PREVIEW}</span>|g" "$TEMP_FILE" > "$TEMP_FILE.1"
  mv "$TEMP_FILE.1" "$TEMP_FILE"
  UPDATE_NEEDED=1
else
  echo "GitHub update skipped due to API failure."
fi

if fetch_x_post; then
  echo "Updating X section in $HTML_FILE..."
  sed "s|<span id=\"x-preview\">[^<]*</span>|<span id=\"x-preview\">${X_PREVIEW}</span>|g" "$TEMP_FILE" > "$TEMP_FILE.1"
  mv "$TEMP_FILE.1" "$TEMP_FILE"
  UPDATE_NEEDED=1
else
  echo "X update skipped due to API failure."
fi

# Apply changes if at least one update was successful
if [ "$UPDATE_NEEDED" -eq 1 ]; then
  mv "$TEMP_FILE" "$HTML_FILE"
  echo "Update complete! Check $HTML_FILE for changes."
else
  echo "No API calls succeeded. HTML file not updated."
  rm -f "$TEMP_FILE"
fi
