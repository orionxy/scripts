#!/bin/sh
echo Launching WinMergeU.exe: $1 $2
"/c/Apps/WinMerge/WinMerge-2.14.0-exe/WinMergeU.exe" -e -u -dl "Local" -dr "Remote" "$1" "$2"
