#!/bin/bash

# Configuration
YOUTUBE_CHANNEL_ID="UCRR013YJAj1i4qM_KYciNaw"
GITHUB_ORG="sen-laboratories"
X_USER_ID="1384973683287105536"

HTML_FILE="index_new.html"
TEMP_FILE="index_new_temp.html"

# Preview ID placeholders
YOUTUBE_PREVIEW_ID="youtube-preview"
GITHUB_PREVIEW_ID="github-preview"
X_PREVIEW_ID="x-preview"

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
  echo "Error: jq is required but not installed."
  exit 1
fi
if ! command -v curl &> /dev/null; then
  echo "Error: curl is required but not installed."
  exit 1
fi
if ! command -v python &> /dev/null; then
  echo "Error: python is required for HTML entity unescaping."
  exit 1
fi

# Initialize preview variables (content only, empty defaults)
YOUTUBE_PREVIEW=''
GITHUB_PREVIEW=''
X_PREVIEW=''

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
  echo "Before YouTube sed: $(sha256sum "$TEMP_FILE" || echo 'no file')"
  grep -q "<span id=[\"']${YOUTUBE_PREVIEW_ID}[\"']>" "$TEMP_FILE" || { echo "Error: ${YOUTUBE_PREVIEW_ID} span not found in $TEMP_FILE"; return 1; }
  BEFORE_HASH=$(sha256sum "$TEMP_FILE" | cut -d' ' -f1)
  # Replace content, preserve outer span
  sed -i.bak "s|\(<span id=[\"']${YOUTUBE_PREVIEW_ID}[\"'][^>]*>\).*\(</span>\)|\1${YOUTUBE_PREVIEW}\2|g" "$TEMP_FILE"
  SED_STATUS=$?
  AFTER_HASH=$(sha256sum "$TEMP_FILE" | cut -d' ' -f1)
  rm -f "$TEMP_FILE.bak"
  echo "After YouTube sed: $(sha256sum "$TEMP_FILE" || echo 'no file')"
  if [ $SED_STATUS -ne 0 ]; then
    echo "Error: Failed to update YouTube section (sed error)."
    return 1
  fi
  if [ "$BEFORE_HASH" = "$AFTER_HASH" ]; then
    echo "No update needed for YouTube section (content unchanged)."
    return 0
  fi
  echo "YouTube section updated."
  return 2  # Indicate update made
}

# Function to fetch the latest commit across all public repos
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
  GITHUB_PREVIEW="${COMMIT_REPO}: ${COMMIT_MESSAGE}"
  echo "Before GitHub sed: $(sha256sum "$TEMP_FILE" || echo 'no file')"
  grep -q "<span id=[\"']${GITHUB_PREVIEW_ID}[\"']>" "$TEMP_FILE" || { echo "Error: ${GITHUB_PREVIEW_ID} span not found in $TEMP_FILE"; return 1; }
  BEFORE_HASH=$(sha256sum "$TEMP_FILE" | cut -d' ' -f1)
  # Replace content, preserve outer span
  sed -i.bak "s|\(<span id=[\"']${GITHUB_PREVIEW_ID}[\"'][^>]*>\).*\(</span>\)|\1${GITHUB_PREVIEW}\2|g" "$TEMP_FILE"
  SED_STATUS=$?
  AFTER_HASH=$(sha256sum "$TEMP_FILE" | cut -d' ' -f1)
  rm -f "$TEMP_FILE.bak"
  echo "After GitHub sed: $(sha256sum "$TEMP_FILE" || echo 'no file')"
  if [ $SED_STATUS -ne 0 ]; then
    echo "Error: Failed to update GitHub section (sed error)."
    return 1
  fi
  if [ "$BEFORE_HASH" = "$AFTER_HASH" ]; then
    echo "No update needed for GitHub section (content unchanged)."
    return 0
  fi
  echo "GitHub section updated."
  return 2  # Indicate update made
}

# Function to fetch the latest X post
fetch_x_post() {
  echo "Fetching latest X post..."
  RESPONSE=$(curl -v -s -w "\n%{http_code}" -H "Authorization: Bearer ${X_BEARER_TOKEN}" "https://api.twitter.com/2/users/${X_USER_ID}/tweets?max_results=10&exclude=retweets&tweet.fields=text" 2> curl_debug.log)
  HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
  TWEET_RESPONSE=$(echo "$RESPONSE" | sed -e '$d')

  if [ "$HTTP_STATUS" -ne 0 ]; then
    ERROR_TITLE=$(echo "$TWEET_RESPONSE" | jq -r '.title // .errors[0].title // "Unknown Error"')
    ERROR_DETAIL=$(echo "$TWEET_RESPONSE" | jq -r '.detail // .errors[0].detail // "No details provided"')
    echo "Could not get latest post from X, got HTTP status $HTTP_STATUS: $ERROR_TITLE, detail: $ERROR_DETAIL"
    echo "Raw response: $TWEET_RESPONSE"
    echo "Curl debug log written to curl_debug.log"
    return 1
  fi

  if [ -z "$TWEET_RESPONSE" ] || ! echo "$TWEET_RESPONSE" | jq -e . >/dev/null 2>&1; then
    echo "Could not get latest post from X, got invalid or empty response"
    echo "Raw response: $TWEET_RESPONSE"
    echo "Curl debug log written to curl_debug.log"
    return 1
  fi

  TWEET_TEXT=$(echo "$TWEET_RESPONSE" | jq -r '.data[0].text // ""')

  if [ -z "$TWEET_TEXT" ]; then
    echo "Failed to fetch latest X post (no text found)."
    echo "Raw response: $TWEET_RESPONSE"
    return 1
  fi

  # Replace newlines with spaces to prevent Python syntax errors
  TWEET_TEXT_ESCAPED=$(echo "$TWEET_TEXT" | tr '\n' ' ')
  # Debug: Log escaped text
  echo "Escaped tweet text: '$TWEET_TEXT_ESCAPED'"
  # Escape single quotes for Python
  TWEET_TEXT_QUOTED=$(echo "$TWEET_TEXT_ESCAPED" | sed "s/'/\\\'/g")
  # Unescape HTML entities, treat warnings as errors
  TWEET_TEXT_UNESCAPED=$(python -W error -c "import html; print(html.unescape('$TWEET_TEXT_QUOTED'.replace('\0', '')))")
  if [ $? -ne 0 ]; then
    echo "Failed to unescape HTML entities in tweet: '$TWEET_TEXT_QUOTED'"
    return 1
  fi
  # Sanitize for sed, including new delimiter
  TWEET_TEXT_CLEAN=$(echo "$TWEET_TEXT_UNESCAPED" | tr -d '\n\r\t' | sed 's/[\\/&|]/\\&/g; s/"/\\"/g')
  TWEET_TEXT_TRUNCATED=$(echo "$TWEET_TEXT_CLEAN" | cut -c 1-50)
  if [ ${#TWEET_TEXT_CLEAN} -gt 50 ]; then
    TWEET_TEXT_TRUNCATED="${TWEET_TEXT_TRUNCATED}..."
  fi
  echo "Latest X post: $TWEET_TEXT_TRUNCATED"
  X_PREVIEW="Latest Post: \"${TWEET_TEXT_TRUNCATED}\""

  echo "Before X sed: $(sha256sum "$TEMP_FILE" || echo 'no file')"
  grep -q "<span id=[\"']${X_PREVIEW_ID}[\"']>" "$TEMP_FILE" || { echo "Error: ${X_PREVIEW_ID} span not found in $TEMP_FILE"; return 1; }
  BEFORE_HASH=$(sha256sum "$TEMP_FILE" | cut -d' ' -f1)
  # Replace content, preserve outer span
  sed -i.bak "s|\(<span id=[\"']${X_PREVIEW_ID}[\"'][^>]*>\).*\(</span>\)|\1${X_PREVIEW}\2|g" "$TEMP_FILE"
  SED_STATUS=$?
  AFTER_HASH=$(sha256sum "$TEMP_FILE" | cut -d' ' -f1)
  rm -f "$TEMP_FILE.bak" && rm -f curl_debug.log
  echo "After X sed: $(sha256sum "$TEMP_FILE" || echo 'no file')"
  if [ $SED_STATUS -ne 0 ]; then
    echo "Error: Failed to update X section (sed error)."
    return 1
  fi
  if [ "$BEFORE_HASH" = "$AFTER_HASH" ]; then
    echo "No update needed for X section (content unchanged)."
    return 0
  fi
  echo "X section updated."
  return 2  # Indicate update made
}

# Fetch all data and update HTML sections
echo "Starting CTA update..."
UPDATE_NEEDED=0
cp "$HTML_FILE" "$TEMP_FILE" || { echo "Error: Failed to copy $HTML_FILE to $TEMP_FILE"; exit 1; }
echo "Initial TEMP_FILE content (${X_PREVIEW_ID}):"
grep "${X_PREVIEW_ID}" "$TEMP_FILE" || echo "No ${X_PREVIEW_ID} found"

fetch_youtube_video
YOUTUBE_STATUS=$?
if [ $YOUTUBE_STATUS -eq 2 ]; then
  UPDATE_NEEDED=1
elif [ $YOUTUBE_STATUS -eq 1 ]; then
  echo "YouTube update skipped due to API failure."
fi

fetch_github_data
GITHUB_STATUS=$?
if [ $GITHUB_STATUS -eq 2 ]; then
  UPDATE_NEEDED=1
elif [ $GITHUB_STATUS -eq 1 ]; then
  echo "GitHub update skipped due to API failure."
fi

fetch_x_post
X_STATUS=$?
if [ $X_STATUS -eq 2 ]; then
  UPDATE_NEEDED=1
elif [ $X_STATUS -eq 1 ]; then
  echo "X update skipped due to API failure."
fi

# Apply changes if at least one update was successful
if [ "$UPDATE_NEEDED" -eq 1 ]; then
  echo "Before mv: $(sha256sum "$TEMP_FILE" || echo 'no file')"
  mv -f "$TEMP_FILE" "$HTML_FILE" || { echo "Error: Failed to move $TEMP_FILE to $HTML_FILE"; exit 1; }
  sync
  echo "After mv: $(sha256sum "$HTML_FILE" || echo 'no file')"
  echo "Update complete! Check $HTML_FILE for changes."
else
  echo "No updates needed for $HTML_FILE (content already up-to-date)."
  rm -f "$TEMP_FILE"
fi
