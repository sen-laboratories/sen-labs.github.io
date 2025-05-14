#!/bin/bash

# Configuration
YOUTUBE_CHANNEL_ID="UCRR013YJAj1i4qM_KYciNaw"
GITHUB_ORG="sen-laboratories"
BSKY_HANDLE="sen-labs.org"
HTML_FILE="index_new.html"
TEMP_FILE="index_new_temp.html"

# Preview ID placeholders
YOUTUBE_PREVIEW_ID="youtube-preview"
GITHUB_PREVIEW_ID="github-preview"
BSKY_PREVIEW_ID="bsky-preview"
BLOG_PREVIEW_ID="blog-preview"

# Check for required environment variables
REQUIRED_VARS=("YOUTUBE_API_KEY" "BSKY_APP_PASSWORD" "SUBSTACK_API_KEY")
for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR}" ]; then
    echo "Error: Required environment variable $VAR is not set."
    exit 1
  fi
done

# Ensure required tools are installed
REQUIRED_TOOLS=("jq" "curl" "python")
for TOOL in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "${TOOL}" &> /dev/null ; then
    echo "Error: Required command $TOOL is not installed."
    exit 1
  fi
done

# Initialize preview variables (content only, empty defaults)
YOUTUBE_PREVIEW=''
GITHUB_PREVIEW=''
BSKY_PREVIEW=''
BLOG_PREVIEW=''

# function to fetch latest post from Substack over RSS

fetch_blog_post() {
    substack_rss=$(curl -s --fail-with-body -H "X-API-Key: $SUBSTACK_API_KEY" "https://api.substackapi.dev/posts/latest?limit=1&publication_url=https%3A%2F%2Fsenlabs.substack.com%2F")
    # Check if the response was fetched successfully
    if [ $? -eq 22 ]; then
      echo "failed to retrieve response from Substack."
      return 1
    fi
    # Extract the title of the latest post
    latest_post=$(echo "$substack_rss" | jq -r ".data[].title")

    if [ -z "$latest_post" ]; then
      echo "Error: Failed to parse latest Substack post title."
      return 1
    fi

    latest_post_url=$(echo "$substack_rss" | jq -r ".data[].url")
    latest_post_desc=$(echo "$substack_rss" | jq -r ".data[].description")
    latest_post_img=$(echo "$substack_rss" | jq -r ".data[].cover_image.small")

    # Update Substack section
    sed -i.bak "s|<span id=\"$BLOG_PREVIEW_ID\".*</span>|<span id=\"$BLOG_PREVIEW_ID\"><a href=\"$latest_post_url\"><img src=\"$latest_post_img\" alt=\"$latest_post_desc\" title=\"$latest_post\"/></a></span>|g" "$TEMP_FILE"
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

    VIDEO_RESPONSE=$(curl -s --fail-with-body "https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=${YOUTUBE_CHANNEL_ID}&maxResults=1&order=date&type=video&key=${YOUTUBE_API_KEY}")
    if [ $? -eq 22 ]; then
        echo "failed to retrieve response from Youtube."
        return 1
    fi
    VIDEO_ID=$(echo "$VIDEO_RESPONSE" | jq -r '.items[0].id.videoId')
    VIDEO_TITLE=$(echo "$VIDEO_RESPONSE" | jq -r '.items[0].snippet.title')

    if [ -z "$VIDEO_ID" ]; then
      echo "Failed to fetch latest video."
      return 1
    fi

    echo "Latest YouTube video: $VIDEO_TITLE (ID: $VIDEO_ID)"
    YOUTUBE_PREVIEW="<a href=\"https://www.youtube.com/watch?v=${VIDEO_ID}\"><img src=\"https://img.youtube.com/vi/${VIDEO_ID}/0.jpg\" alt=\"${VIDEO_TITLE}\" title=\"${VIDEO_TITLE}\"/></a>"
    if ! grep -q "<span id=[\"']${YOUTUBE_PREVIEW_ID}[\"'][^>]*>" "$TEMP_FILE"; then
      echo "Error: ${YOUTUBE_PREVIEW_ID} span not found in $TEMP_FILE"
      return 1
    fi
    # Replace content,\
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
    repos_response=$(curl -s --fail-with-body -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/orgs/sen-laboratories/repos")
    if [ $? -eq 22 ]; then
      echo "failed to retrieve response from Github."
      return 1
    fi
    # Simplify jq expression and handle potential issues
    commit_info=$(echo "$repos_response" | jq -r '[.[] | select(.name!="sen-labs.github.io") | {name: .name, pushed_at: .pushed_at, default_branch: .default_branch}] | sort_by(.pushed_at) | last | "\(.name): \(.default_branch)"')
    if [ -z "$commit_info" ]; then
      echo "Error: Failed to fetch latest commit info."
      return 1
    fi

    COMMIT_REPO=$(echo "$commit_info" | cut -d':' -f1)
    branch=$(echo "$commit_info" | cut -d':' -f2 | tr -d ' ')
    commit_response=$(curl -s --fail-with-body -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/sen-laboratories/$COMMIT_REPO/commits/$branch")
    if [ $? -eq 22 ]; then
      echo "failed to retrieve response for latet commit from Github."
      return 1
    fi
    # Check the type of the response and extract the commit message accordingly
    commit=$(echo "$commit_response" | jq -r ".commit.message")
    if [ -z "$commit" ]; then
      echo "Error: Failed to fetch commit message."
      return 1
    fi

    # Update GitHub section: commit text
    sed -i "s|<span id=\"$GITHUB_PREVIEW_ID\".*</span>|<span id=\"$GITHUB_PREVIEW_ID\">$COMMIT_REPO: $commit</span>|g" "$TEMP_FILE"

    # Update the link to point to the specific repo
    sed -i "s|href=\"https://github.com/sen-laboratories\"|href=\"https://github.com/sen-laboratories/$COMMIT_REPO\"|g" "$TEMP_FILE"

    echo "GitHub section updated with dynamic repo stats and link."
    return 2  # Indicate update made
}

# Function to fetch the latest Bluesky post
fetch_bluesky_post() {
    echo "Fetching latest Bluesky post..."
    # Get API key with the app password
    API_KEY_URL='https://bsky.social/xrpc/com.atproto.server.createSession'
    POST_DATA="{ \"identifier\": \"${BSKY_HANDLE}\", \"password\": \"${BSKY_APP_PASSWORD}\" }"
    API_KEY=$(curl -s --fail-with-body -X POST \
        -H 'Content-Type: application/json' \
        -d "$POST_DATA" \
        "$API_KEY_URL" | jq -r .accessJwt)

    if [ $? -eq 22 ]; then
      echo "failed to retrieve API key from Bluesky"
      return 1
    fi

    # Get a user's feed
    LIMIT=15
    FEED_URL="https://bsky.social/xrpc/app.bsky.feed.getAuthorFeed"
    TWEET_RESPONSE=$(curl -s --fail-with-body -G \
        -H "Authorization: Bearer ${API_KEY}" \
        --data-urlencode "actor=${BSKY_HANDLE}" \
        --data-urlencode "limit=${LIMIT}" \
        "$FEED_URL" | jq '.feed | .[] | select((.post.record."$type" == "app.bsky.feed.post") and (.post.record.reply.parent? | not) and (.reason? | not)) | {text: .post.record.text, createdAt: .post.record.createdAt, replyCount: .post.replyCount, repostCount: .post.repostCount, likeCount: .post.likeCount, author: {handle: .post.author.handle, displayName: .post.author.displayName, avatar: .post.author.avatar}}')

    if [ $? -eq 22 ]; then
        echo "failed to retrieve response for latet post from Bluesky"
        return 1
    fi

    TWEET_TEXT=$(echo "$TWEET_RESPONSE" | jq -r '.text // ""')

    if [ -z "$TWEET_TEXT" ]; then
      echo "Failed to fetch latest Bluesky post (no text found)."
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
    # shorten to fit into social card
    POST_MAX_LEN=186
    TWEET_TEXT_TRUNCATED=$(echo "$TWEET_TEXT_CLEAN" | cut -c 1-$POST_MAX_LEN)
    if [ ${#TWEET_TEXT_CLEAN} -gt $POST_MAX_LEN ]; then
      TWEET_TEXT_TRUNCATED="${TWEET_TEXT_TRUNCATED}…"
    fi
    BSKY_PREVIEW="Latest: \"${TWEET_TEXT_TRUNCATED}\""
    if ! grep -q "<span id=[\"']${BSKY_PREVIEW_ID}[\"'][^>]*>" "$TEMP_FILE"; then
      echo "Error: ${BSKY_PREVIEW_ID} span not found in $TEMP_FILE"
      return 1
    fi
    # Replace content, preserve outer span
    sed -i.bak "s|\(<span id=[\"']${BSKY_PREVIEW_ID}[\"'][^>]*>\).*\(</span>\)|\1${BSKY_PREVIEW}\2|g" "$TEMP_FILE"
    SED_STATUS=$?
    rm -f "$TEMP_FILE.bak"
    if [ $SED_STATUS -ne 0 ]; then
      echo "Error: Failed to update Bluesky section (sed error)."
      return 1
    fi
    echo "Bluesky section updated."
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

fetch_bluesky_post
STATUS=$?
if [ $STATUS -eq 2 ]; then
  UPDATE_NEEDED=1
elif [ $STATUS -eq 1 ]; then
  echo "Bluesky update skipped due to API failure or missing span."
fi

fetch_blog_post
STATUS=$?
if [ $STATUS -eq 2 ]; then
  UPDATE_NEEDED=1
elif [ $STATUS -eq 1 ]; then
  echo "Blog update skipped due to API failure or missing span."
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
