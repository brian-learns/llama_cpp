#!/usr/bin/env bash
[[ -n "$DEBUG" ]] && set -x
set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # http://stackoverflow.com/questions/59895

cd "$DIR"/src/
git fetch --tags

# Check out the single most recent tag automatically
LATEST_REV=$(git rev-list --tags --max-count=1)
LATEST_TAG=$(git describe --tags "$LATEST_REV")

git checkout "$LATEST_TAG"

cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DCMAKE_INSTALL_PREFIX=~/llama_cpp/local
cmake --build build --config Release -j 4
# cmake --install build --config Release
