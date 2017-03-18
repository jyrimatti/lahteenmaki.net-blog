#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p bash pandoc
set -eu

DIR="$(dirname "${BASH_SOURCE[0]}")"

blogname=$1
extracss=$2

for tag in $(ls tags/)
do
  echo ---                           > .temp.yaml
  echo post:                        >> .temp.yaml
  for f in tags/$tag/*
  do
    filename=../../$(basename $f .rst).html
    abstract=$(grep -w $f -e '^:Abstract:' | sed 's/^:Abstract:\s*//')
    date=$(grep -w $f -e '^:Date:' | sed 's/^:Date:\s*//')
    echo "- title: $(head -1 $f)"   >> .temp.yaml
    echo "  filename: $filename"    >> .temp.yaml
    echo "  description: $abstract" >> .temp.yaml
    echo "  date: $date" >> .temp.yaml
  done
  echo ... >> .temp.yaml

  pandoc "$DIR/empty.md" .temp.yaml \
    --template "$DIR/posts.template" \
    --to html5 \
    --output ".temp.html"

  pandoc "$DIR/empty.md" \
    --template "$DIR/base.template" \
    --css "$extracss" \
    --css ../../styles.css \
    --section-divs \
    --metadata 'title-suffix':"$blogname" \
    --metadata 'title':"Tag: $tag" \
    --to html5 \
    --include-after-body .temp.html \
    --output "tags/$tag/index.html"
done
rm .temp.yaml
rm .temp.html