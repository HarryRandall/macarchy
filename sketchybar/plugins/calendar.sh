#!/usr/bin/env bash

calendar_label="$(LC_ALL=C date +'%a %d %b %I:%M %p')"
sketchybar --set "${NAME:-calendar}" label="$calendar_label"
