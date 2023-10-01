#!/bin/bash -e

# --------------------------------------------------------
# Generate app icons and xcassets file from a single image
# Ben Clayton, Calvium Ltd.
#  https://gist.github.com/benvium/2be6d673aa9ac284bb8a
# --------------------------------------------------------
#
# Usage with an input of 1024x1024 PNG file
#   generateAppIcon.sh AppIcon.png
#
# Updated in October 2017 for RobLabs.com
# https://gist.github.com/roblabs/527458cbe46b0483cd2d594c7b9e583f
# Based on Xcode Version 9.0 (9A235)
# requires imagemagick
  # `brew install imagemagick`

sourceIconName=$1

# Ensure we're running in location of script.
#cd "`dirname $0`"

# Check imagemagick is installed
# http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
command -v convert >/dev/null 2>&1 || { echo >&2 "I require imagemagick but it's not installed.  Aborting."; exit 1; }

iconPath="./preview.appiconset"

mkdir -p "$iconPath"

# Splash
convert $sourceIconName -resize 60x60 $iconPath/preview@1x.png
convert $sourceIconName -resize 120x120 $iconPath/preview@2x.png
convert $sourceIconName -resize 180x180 $iconPath/preview@3x.png


cat > "$iconPath/Contents.json" << EOF
{
  "images": [
    {
      "size": "60x60",
      "idiom": "universal",
      "filename": "preview@1x.png",
      "scale": "1x"
    },
    {
      "size": "120x120",
      "idiom": "universal",
      "filename": "preview@2x.png",
      "scale": "2x"
    },
    {
      "size": "180x180",
      "idiom": "universal",
      "filename": "preview@3x.png",
      "scale": "3x"
    },
  ],
  "info": {
    "version": 1,
    "author": "xcode"
  },
  "properties": {
    "pre-rendered": true
  }
}
EOF
