#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p bash pandoc
set -eu

DIR="$(dirname "${BASH_SOURCE[0]}")"

blogname=$1
extracss=$2

metadata=$(mktemp)

for tag in $(ls tags/)
do
  echo ---                             > "$metadata"
  echo post:                          >> "$metadata"
  for f in tags/$tag/*.rst
  do
    filename=../../$(basename $f .rst).html
    abstract=$(grep -w $f -e '^:Abstract:' | sed 's/^:Abstract:\s*//')
    date=$(grep -w $f -e '^:Date:' | sed 's/^:Date:\s*//')
    echo "- title: $(head -1 $f)"     >> "$metadata"
    echo "  filename: $filename"      >> "$metadata"
    echo "  description: $abstract"   >> "$metadata"
    echo "  date: $date"              >> "$metadata"
  done
  echo ...                            >> "$metadata"

  # empty content since all data is in the metadata
  posts=$(mktemp)
  pandoc "$DIR/empty.md" "$metadata" \
    --template "$DIR/fragment.template" \
    --to html5 \
    --output "$posts"

  # empty content since all the content is generated in the previous step
  pandoc "$DIR/empty.md" \
    --template "$DIR/base.template" \
    --css "$extracss" \
    --css "../../styles.css" \
    --section-divs \
    --metadata 'title-suffix':"$blogname" \
    --metadata 'title':"Tag: $tag" \
    --metadata 'lang':"en" \
    --to html5 \
    --include-after-body "$posts" \
    --output "tags/$tag/index.html"
done
