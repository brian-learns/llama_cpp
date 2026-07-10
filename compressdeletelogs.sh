#!/usr/bin/env bash
[[ -n "$DEBUG" ]] && set -x
set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # http://stackoverflow.com/questions/59895
cd "$DIR"

# compress files older than a day
find ./prompt_logs/ -type f -mtime +0  -regextype posix-extended -regex ".*/[0-9]{12}\.txt" -exec zstd --rm -9 {} +

# delete files older than a month
find ./prompt_logs/ -type f -mtime +30 -regextype posix-extended -regex ".*/[0-9]{12}\.txt\.zst" -delete
