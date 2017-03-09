#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p bash file pandoc
set -eu

# check all tags (symbolic links) are valid
test $(find tags -type l -exec sh -c "file -b {} | grep -q ^broken" \; -print | wc -l) -eq 0 || (echo 'Invalid tag symlinks!'; exit 1)

for f in *.rst
do
  draftprefix=$(echo $(grep -w $f -e '^:Status: Published$' || echo '.') | sed s/':Status: Published'//)
  filename=$(basename $f .rst).html
  keywords=$(find tags/*/* | grep "$f" | sed 's/[^/]*\/\([^/]*\)\/.*/--metadata keywords:\1/' | paste -sd " " -)

  pandoc $f \
  	--template base.template \
    --css 'https://lahteenmaki.net/style.css' \
    --css styles.css \
    --section-divs \
    $keywords \
    --metadata filename:"$filename" \
    --metadata 'title-suffix':'Architecturally Elegant' \
    --to html5 \
    --output "$draftprefix$filename"
done
