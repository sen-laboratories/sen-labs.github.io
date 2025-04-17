#!/bin/bash

# Configuration
YOUTUBE_CHANNEL_ID="CRR013YJAj1i4qM_KYciNaw"
GITHUB_REPO="sen-laboratories/sen-inference"
X_USER_ID="1384973683287105536"
HTML_FILE="index_new.html"              # Path to HTML file
TEMP_FILE="index_new_temp.html"         # Temporary file for updates

# Ensure required tools are installed
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed. Please install jq."
  exit 1
fi
if ! command -v curl &> /dev/null; then
  echo "Error: curl is required but not installed. Please install curl."
  exit 1
fi

# Function to fetch the latest YouTube video
fetch_youtube_video() {
  echo "Fetching latest YouTube video..."
  # First, get the uploads playlist ID for the channel
  CHANNEL_RESPONSE=$(curl -s "https://youtube.googleapis.com/youtube/v3/channels?part=contentDetails&id=${YOUTUBE_CHANNEL_ID}&key=${YOUTUBE_API_KEY}")
  UPLOADS_PLAYLIST_ID=$(echo "$CHANNEL_RESPONSE" | jq -r '.items[0].contentDetails.relatedPlaylists.uploads')

  if [ -z "$UPLOADS_PLAYLIST_ID" ]; then
    echo "Failed to fetch uploads playlist ID."
    YOUTUBE_PREVIEW='<span>Failed to load latest video</span>'
    return
  fi

  # Fetch the latest video from the uploads playlist
  VIDEO_RESPONSE=$(curl -s "https://youtube.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=${UPLOADS_PLAYLIST_ID}&maxResults=1&key=${YOUTUBE_API_KEY}")
  VIDEO_ID=$(echo "$VIDEO_RESPONSE" | jq -r '.items[0].snippet.resourceId.videoId')
  VIDEO_TITLE=$(echo "$VIDEO_RESPONSE" | jq -r '.items[0].snippet.title')

  if [ -z "$VIDEO_ID" ]; then
    echo "Failed to fetch latest video."
    YOUTUBE_PREVIEW='<span>Failed to load latest video</span>'
  else
    echo "Latest YouTube video: $VIDEO_TITLE (ID: $VIDEO_ID)"
    YOUTUBE_PREVIEW="<img src=\"https://img.youtube.com/vi/${VIDEO_ID}/0.jpg\" alt=\"${VIDEO_TITLE}\">"
  fi
}

# Function to fetch the latest GitHub commit or stats
fetch_github_data() {
  echo "Fetching latest GitHub data..."
  # Add Authorization header if token is provided
  AUTH_HEADER=""
  if [ -n "$GITHUB_TOKEN" ]; then
    AUTH_HEADER="Authorization: Bearer $GITHUB_TOKEN"
  fi

  # Fetch the latest commit
  COMMIT_RESPONSE=$(curl -s -H "$AUTH_HEADER" "https://api.github.com/repos/${GITHUB_REPO}/commits?per_page=1")
  COMMIT_MESSAGE=$(echo "$COMMIT_RESPONSE" | jq -r '.[0].commit.message')
  COMMIT_SHA=$(echo "$COMMIT_RESPONSE" | jq -r '.[0].sha' | cut -c 1-7)

  if [ -z "$COMMIT_MESSAGE" ]; then
    echo "Failed to fetch latest commit."
    GITHUB_PREVIEW='<span>Failed to load latest commit</span>'
  else
    echo "Latest GitHub commit: $COMMIT_MESSAGE (SHA: $COMMIT_SHA)"
    GITHUB_PREVIEW="<span>Latest Commit: \"${COMMIT_MESSAGE}\" (${COMMIT_SHA})</span>"
  fi
}

# Function to fetch the latest X post
fetch_x_post() {
  echo "Fetching latest X post..."

  # Fetch the latest post
  TWEET_RESPONSE=$(curl -s -H "Authorization: Bearer ${X_BEARER_TOKEN}" "https://api.twitter.com/2/users/${X_USER_ID}/tweets?max_results=1&exclude=replies&exclude=retweets")
  TWEET_TEXT=$(echo "$TWEET_RESPONSE" | jq -r '.data[0].text')

  if [ -z "$TWEET_TEXT" ]; then
    echo "Failed to fetch latest X post."
    X_PREVIEW='<span>Failed to load latest post</span>'
  else
    # Truncate the tweet text to fit the preview (e.g., first 50 characters)
    TWEET_TEXT_TRUNCATED=$(echo "$TWEET_TEXT" | cut -c 1-50)
    if [ ${#TWEET_TEXT} -gt 50 ]; then
      TWEET_TEXT_TRUNCATED="${TWEET_TEXT_TRUNCATED}..."
    fi
    echo "Latest X post: $TWEET_TEXT_TRUNCATED"
    X_PREVIEW="<span>Latest Post: \"${TWEET_TEXT_TRUNCATED}\"</span>"
  fi
}

# Fetch all data
fetch_youtube_video
fetch_github_data
fetch_x_post

# Update the HTML file
echo "Updating $HTML_FILE..."
cp "$HTML_FILE" "$TEMP_FILE"

# Replace placeholders with fetched data
sed -i "s|<!-- YOUTUBE_PREVIEW -->|$YOUTUBE_PREVIEW|g" "$TEMP_FILE"
sed -i "s|<!-- GITHUB_PREVIEW -->|$GITHUB_PREVIEW|g" "$TEMP_FILE"
sed -i "s|<!-- X_PREVIEW -->|$X_PREVIEW|g" "$TEMP_FILE"
# Note: BLOG_PREVIEW is not updated since there's no blog API; you can update it manually

# Overwrite the original file
mv "$TEMP_FILE" "$HTML_FILE"
echo "Update complete! Check $HTML_FILE for changes."
