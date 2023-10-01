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

iconPath="./Splash.appiconset"

mkdir -p "$iconPath"

# Splash
convert $sourceIconName -resize 896x896 -bordercolor transparent -fill transparent \( -clone 0 -colorize 100 -shave 40x40 -border 40x40 -blur 0x10 \) -compose copyopacity -composite $iconPath/splash@1x.png
convert $sourceIconName -resize 1792x1792 -bordercolor transparent -fill transparent \( -clone 0 -colorize 100 -shave 80x80 -border 80x80 -blur 0x20 \) -compose copyopacity -composite $iconPath/splash@2x.png
convert $sourceIconName -resize 2688x2688 -bordercolor transparent -fill transparent \( -clone 0 -colorize 100 -shave 120x120 -border 120x120 -blur 0x30 \) -compose copyopacity -composite $iconPath/splash@3x.png


cat > "$iconPath/Contents.json" << EOF
{
  "images": [
    {
      "size": "896x896",
      "idiom": "iphone",
      "filename": "splash@1x.png",
      "scale": "1x"
    },
    {
      "size": "1792x1792",
      "idiom": "iphone",
      "filename": "splash@2x.png",
      "scale": "2x"
    },
    {
      "size": "2688x2688",
      "idiom": "iphone",
      "filename": "splash@3x.png",
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
