#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p bash pandoc
set -eu

DIR="$(dirname "${BASH_SOURCE[0]}")"

metadata=$1
output=$2

# empty content since all data is in the metadata
pandoc "$DIR/empty.md" "$metadata" \
    --template "$DIR/rss.template" \
    --output "$output"