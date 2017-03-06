#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p bash pandoc
set -eu

for f in *.rst
do 
  keywords=$(find tags/*/* | grep "$f" | sed 's/[^/]*\/\([^/]*\)\/.*/\1/' | paste -sd "," -)
  pandoc $f --css styles.css --section-divs --template base.template -M keywords:"$keywords" --to html5 --output $(basename $f .rst).html
done
