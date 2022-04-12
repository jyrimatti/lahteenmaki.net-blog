#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p bash pandoc
set -eu

DIR="$(dirname "${BASH_SOURCE[0]}")"

blogname=$1
extracss=$2
postshtml=$3
tagshtml=$(mktemp)

echo "$4" > "$tagshtml"

for f in *.rst
do
  draftprefix=$(echo $(grep -w $f -e '^:Status: Published$' || echo '.') | sed s/':Status: Published'//)
  filename=$(basename $f .rst).html
  keywords=$(find tags/*/* | grep "$f" | sed 's/[^/]*\/\([^/]*\)\/.*/--metadata keywords:\1/' | paste -sd " " -)
  comments=$(test $f == 'index.rst' || echo --metadata comments:true)
  include=$(test $f != 'index.rst' || echo --include-after-body "$postshtml" --include-after-body "$tagshtml")

  # remove draft output in case the Status just changed to Published
  rm -f ".$filename"

  pandoc $f \
  	--template "$DIR/base.template" \
    --css "$extracss" \
    --css "styles.css" \
    --section-divs \
    $keywords \
    --metadata 'filename':"$filename" \
    --metadata 'title-suffix':"$blogname" \
    --shift-heading-level-by=1 \
    $comments \
    $include \
    --to html5 \
    --output "$draftprefix$filename"
done
