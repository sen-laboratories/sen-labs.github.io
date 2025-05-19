#!/bin/sh -xe
ffmpeg -i "$1" -b:v 0 -crf 30 -pass 1 -an -f webp -y /dev/null
ffmpeg -i "$1" -b:v 0 -crf 30 -loop 0 -pass 2 "${1%.mpg}.webp"
