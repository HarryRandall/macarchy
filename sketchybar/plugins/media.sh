#!/bin/bash

set_media() {
  local media="$1"

  if [ -n "$media" ]; then
    sketchybar --set "$NAME" label="$media" drawing=on
  else
    sketchybar --set "$NAME" drawing=off
  fi
}

media_from_info() {
  [ -n "${INFO:-}" ] || return 1

  local state media
  state="$(printf '%s' "$INFO" | jq -r '.state // empty' 2>/dev/null)"
  [ "$state" = "playing" ] || return 1

  media="$(printf '%s' "$INFO" | jq -r '
    .title as $title
    | (
        if (.artist | type) == "array" then
          (.artist | join(", "))
        else
          (.artist // "")
        end
      ) as $artist
    | if ($title // "") == "" then
        ""
      else
        $title + (if $artist == "" then "" else " - " + $artist end)
      end
  ' 2>/dev/null)"

  [ -n "$media" ] || return 1
  printf '%s\n' "$media"
}

media_from_app() {
  local app_name="$1"

  osascript 2>/dev/null <<APPLESCRIPT
if application "$app_name" is running then
  tell application "$app_name"
    if player state is playing then
      return name of current track & " - " & artist of current track
    end if
  end tell
end if
APPLESCRIPT
}

MEDIA="$(media_from_info || true)"

if [ -z "$MEDIA" ]; then
  MEDIA="$(media_from_app "Spotify" || true)"
fi

if [ -z "$MEDIA" ]; then
  MEDIA="$(media_from_app "Music" || true)"
fi

set_media "$MEDIA"
