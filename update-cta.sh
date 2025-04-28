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
BLOG_PREVIEW_ID="blog-preview"

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
REQUIRED_TOOLS=("jq" "xmllint" "curl" "python")
for TOOL in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "${TOOL}" &> /dev/null ; then
    echo "Error: Required command $TOOL is not installed."
    exit 1
  fi
done

# Initialize preview variables (content only, empty defaults)
YOUTUBE_PREVIEW=''
GITHUB_PREVIEW=''
X_PREVIEW=''
BLOG_PREVIEW=''

# function to fetch latest post from Substack over RSS

fetch_blog_post() {
substack_rss=$(curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
  -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
  -H "Accept-Language: en-US,en;q=0.5" \
  "https://senlabs.substack.com/feed")
 	# Log the RSS feed for debugging
	echo "Substack RSS Response: $substack_rss"
	# Check if the RSS feed was fetched successfully
	if [ -z "$substack_rss" ]; then
	  echo "Error: Failed to fetch Substack RSS feed. Check debug.log for details."
	  return 1
	fi
	# Extract the title of the latest post
	latest_post=$(echo "$substack_rss" | xmllint --xpath "//item[1]/title/text()" - 2>/dev/null | sed 's/<!\[CDATA\[//g' | sed 's/\]\]>//g')

	if [ -z "$latest_post" ]; then
	  echo "Error: Failed to parse latest Substack post title."
	  return 1
	fi
	
	# Update Substack section
	sed -i.bak "s|<span id=\"$BLOG_PREVIEW_ID\".*</span>|<span id=\"$BLOG_PREVIEW_ID\">Latest Post: \"$latest_post\"</span>|g" "$TEMP_FILE"
	SED_STATUS=$?
  rm -f "$TEMP_FILE.bak"
  if [ $SED_STATUS -ne 0 ]; then
    echo "Error: Failed to update blog section (sed error $SED_STATUS)."
    return 1
  fi
	echo "Substack section updated with latest post preview."
	return 2
}

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
  if ! grep -q "<span id=[\"']${YOUTUBE_PREVIEW_ID}[\"'][^>]*>" "$TEMP_FILE"; then
    echo "Error: ${YOUTUBE_PREVIEW_ID} span not found in $TEMP_FILE"
    return 1
  fi
  # Replace content, preserve outer span
  sed -i.bak "s|\(<span id=[\"']${YOUTUBE_PREVIEW_ID}[\"'][^>]*>\).*\(</span>\)|\1${YOUTUBE_PREVIEW}\2|g" "$TEMP_FILE"
  SED_STATUS=$?
  rm -f "$TEMP_FILE.bak"
  if [ $SED_STATUS -ne 0 ]; then
    echo "Error: Failed to update YouTube section (sed error)."
    return 1
  fi
  echo "YouTube section updated."
  return 2  # Indicate update made
}

# Function to fetch the latest commit across all public repos
fetch_github_data() {
	# Fetching latest GitHub commit
	echo "Fetching latest GitHub commit..."
	repos_response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/orgs/sen-laboratories/repos")
	# Check if the response is OK
	HTTP_STATUS=$(echo "$repos_response" | tail -n 1)
	if [ "$HTTP_STATUS" -ne 200 ]; then
	  echo "Error: got GitHub API response: $repos_response"
	  return 1
	fi
	# Simplify jq expression and handle potential issues
  commit_info=$(echo "$repos_response" | jq -r '[.[] | {name: .name, pushed_at: .pushed_at, default_branch: .default_branch}] | sort_by(.pushed_at) | last | "\(.name): \(.default_branch)"')  
	if [ -z "$commit_info" ]; then
	  echo "Error: Failed to fetch latest commit info."
	  return 1
	fi
	
	COMMIT_REPO=$(echo "$commit_info" | cut -d':' -f1)
	branch=$(echo "$commit_info" | cut -d':' -f2 | tr -d ' ')
	commit_response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
	  "https://api.github.com/repos/sen-laboratories/$COMMIT_REPO/commits/$branch")
	# Log the commit response for debugging
	echo "Commit Response: $commit_response"
	# Check the type of the response and extract the commit message accordingly
	commit=$(echo "$commit_response" | jq -r 'if type == "array" then .[0] else . end | "\(.commit.message) (\(.sha | .[0:7]))"')
	if [ -z "$commit" ]; then
	  echo "Error: Failed to fetch commit message."
	  return 1
	fi

	# Update GitHub section: commit text
	sed -i "s|<span id=\"$GITHUB_PREVIEW_ID\".*</span>|<span id=\"$GITHUB_PREVIEW_ID\" style=\"font-family: 'IBM Plex Mono', monospace;\">$COMMIT_REPO: $commit</span>|g" "$TEMP_FILE"

	# Update the link to point to the specific repo
	sed -i "s|href=\"https://github.com/sen-laboratories\"|href=\"https://github.com/sen-laboratories/$COMMIT_REPO\"|g" "$TEMP_FILE"
	
	echo "GitHub section updated with dynamic repo stats and link."
  return 2  # Indicate update made
}

# Function to fetch the latest X post
fetch_x_post() {
  echo "Fetching latest X post..."
  RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer ${X_BEARER_TOKEN}" "https://api.twitter.com/2/users/${X_USER_ID}/tweets?max_results=10&exclude=retweets&tweet.fields=text")
  HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
  TWEET_RESPONSE=$(echo "$RESPONSE" | sed -e '$d')

  if [ "$HTTP_STATUS" -ne 200 ]; then
    ERROR_TITLE=$(echo "$TWEET_RESPONSE" | jq -r '.title // .errors[0].title // "Unknown Error"')
    ERROR_DETAIL=$(echo "$TWEET_RESPONSE" | jq -r '.detail // .errors[0].detail // "No details provided"')
    echo "Could not get latest post from X, got HTTP status $HTTP_STATUS: $ERROR_TITLE, detail: $ERROR_DETAIL"
    echo "Raw response: $TWEET_RESPONSE"
    return 1
  fi

  if [ -z "$TWEET_RESPONSE" ] || ! echo "$TWEET_RESPONSE" | jq -e . >/dev/null 2>&1; then
    echo "Could not get latest post from X, got invalid or empty response"
    echo "Raw response: $TWEET_RESPONSE"
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
  # Escape single quotes for Python
  TWEET_TEXT_QUOTED=$(echo "$TWEET_TEXT_ESCAPED" | sed "s/'/\\\'/g")
  # Unescape HTML entities, treat warnings as errors
  TWEET_TEXT_UNESCAPED=$(python -W error -c "import html; print(html.unescape('$TWEET_TEXT_QUOTED'.replace('\0', '')))" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "Failed to unescape HTML entities in tweet: '$TWEET_TEXT_QUOTED'"
    return 1
  fi
  # Sanitize for sed
  TWEET_TEXT_CLEAN=$(echo "$TWEET_TEXT_UNESCAPED" | tr -d '\n\r\t' | sed 's/[\\/&]/\\&/g; s/"/\\"/g')
  TWEET_TEXT_TRUNCATED=$(echo "$TWEET_TEXT_CLEAN" | cut -c 1-50)
  if [ ${#TWEET_TEXT_CLEAN} -gt 50 ]; then
    TWEET_TEXT_TRUNCATED="${TWEET_TEXT_TRUNCATED}..."
  fi
  echo "Latest X post: $TWEET_TEXT_TRUNCATED"
  X_PREVIEW="Latest: \"${TWEET_TEXT_TRUNCATED}\""
  if ! grep -q "<span id=[\"']${X_PREVIEW_ID}[\"'][^>]*>" "$TEMP_FILE"; then
    echo "Error: ${X_PREVIEW_ID} span not found in $TEMP_FILE"
    return 1
  fi
  # Replace content, preserve outer span
  sed -i.bak "s|\(<span id=[\"']${X_PREVIEW_ID}[\"'][^>]*>\).*\(</span>\)|\1${X_PREVIEW}\2|g" "$TEMP_FILE"
  SED_STATUS=$?
  rm -f "$TEMP_FILE.bak"
  if [ $SED_STATUS -ne 0 ]; then
    echo "Error: Failed to update X section (sed error)."
    return 1
  fi
  echo "X section updated."
  return 2  # Indicate update made
}

# Fetch all data and update HTML sections
echo "Starting CTA update..."
UPDATE_NEEDED=0
cp "$HTML_FILE" "$TEMP_FILE" || { echo "Error: Failed to copy $HTML_FILE to $TEMP_FILE"; exit 1; }

fetch_youtube_video
STATUS=$?
if [ $STATUS -eq 2 ]; then
  UPDATE_NEEDED=1
elif [ $STATUS -eq 1 ]; then
  echo "YouTube update skipped due to API failure or missing span."
fi

fetch_github_data
STATUS=$?
if [ $STATUS -eq 2 ]; then
  UPDATE_NEEDED=1
elif [ $STATUS -eq 1 ]; then
  echo "GitHub update skipped due to API failure or missing span."
fi

# quota for April exceeded! fetch_x_post
STATUS=$?
if [ $STATUS -eq 2 ]; then
  UPDATE_NEEDED=1
elif [ $STATUS -eq 1 ]; then
  echo "X update skipped due to API failure or missing span."
fi

fetch_blog_post
STATUS=$?
if [ $STATUS -eq 2 ]; then
  UPDATE_NEEDED=1
elif [ $STATUS -eq 1 ]; then
  echo "X update skipped due to API failure or missing span."
fi

# Apply changes if at least one update was successful
if [ "$UPDATE_NEEDED" -eq 1 ]; then
  mv -f "$TEMP_FILE" "$HTML_FILE" || { echo "Error: Failed to move $TEMP_FILE to $HTML_FILE"; exit 1; }
  sync
  echo "Update complete! Check $HTML_FILE for changes."
else
  echo "No updates needed for $HTML_FILE (content already up-to-date)."
  rm -f "$TEMP_FILE"
fi
