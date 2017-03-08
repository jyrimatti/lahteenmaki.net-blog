#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p bash file pandoc
set -eu

# check all tags (symbolic links) are valid
test $(find tags -type l -exec sh -c "file -b {} | grep -q ^broken" \; -print | wc -l) -eq 0 || (echo 'Invalid tag symlinks!'; exit 1)

for f in *.rst
do
  keywords=$(find tags/*/* | grep "$f" | sed 's/[^/]*\/\([^/]*\)\/.*/-M keywords:\1/' | paste -sd " " -)
  pandoc $f --css styles.css --section-divs --template base.template $keywords --to html5 --output $(basename $f .rst).html
done
