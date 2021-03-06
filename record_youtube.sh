#!/bin/bash
# YouTube Live Stream Recorder

if [[ ! -n "$1" ]]; then
  echo "usage: $0 youtube_channel_id|live_url [format] [loop|once]"
  exit 1
fi

# Construct full URL if only channel id given
LIVE_URL=$1
[[ "$1" == "http"* ]] || LIVE_URL="https://www.youtube.com/channel/$1/live"

# Record the best format available but not better that 720p by default
FORMAT="${2:-best[height<=720]}"

while true; do
  # Monitor live streams of specific channel
  while true; do
    LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
    echo "$LOG_PREFIX Checking \"$LIVE_URL\"..."

    # Try to get m3u8 url of current live stream.
    # Add parameters about playlist to avoid downloading
    # the full video playlist uploaded by channel accidently.
    M3U8_URL=$(youtube-dl -g -f "$FORMAT" \
      --no-playlist --playlist-items 1 \
      --match-filter is_live "$LIVE_URL" 2>/dev/null)
    [[ -n "$M3U8_URL" ]] && break

    echo "$LOG_PREFIX The stream is not available now."
    echo "$LOG_PREFIX Retry after 30 seconds..."
    sleep 30
  done

  # Get the metadata of live stream
  METADATA=$(youtube-dl -j "$LIVE_URL")
  ID=$(echo "$METADATA" | grep -Eoi '"id": "([^"]{5,})"' | cut -d '"' -f 4)

  # Record using MPEG-2 TS format to avoid broken file caused by interruption
  FNAME="youtube_${ID}_$(date +"%Y%m%d_%H%M%S").ts"
  # Also save the metadate to file
  echo "$METADATA" > "$FNAME.info.json"

  # Print logs
  echo "$LOG_PREFIX Start recording, metadata saved to \"$FNAME.info.json\"."
  echo "$LOG_PREFIX Use command \"tail -f $FNAME.log\" to track recording progress."

  # Start recording
  ffmpeg -i "$M3U8_URL" -codec copy -f mpegts "$FNAME" > "$FNAME.log" 2>&1

  # Exit if we just need to record current stream
  LOG_PREFIX=$(date +"[%Y-%m-%d %H:%M:%S]")
  echo "$LOG_PREFIX Live stream recording stopped."
  [[ "$3" == "once" ]] && break
done
