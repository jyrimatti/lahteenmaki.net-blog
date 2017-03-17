#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p bash file pandoc
set -eu

echo ---                           > .temp.yaml
echo post:                        >> .temp.yaml
for f in $(grep ':Date:' *.rst | sed s/::Date:// | sort --reverse --key 2 | cut -d' ' -f1 | paste -sd ' ')
do
  if [[ "$f" != 'index.rst' ]]
  then
    filename=$(basename $f .rst).html
    abstract=$(grep -w $f -e '^:Abstract:' | sed 's/^:Abstract:\s*//')
    date=$(grep -w $f -e '^:Date:' | sed 's/^:Date:\s*//')
    echo "- title: $(head -1 $f)"   >> .temp.yaml
    echo "  filename: $filename"    >> .temp.yaml
    echo "  description: $abstract" >> .temp.yaml
    echo "  date: $date" >> .temp.yaml
  fi
done
echo ... >> .temp.yaml

pandoc empty.md .temp.yaml \
    --template rss.template \
    --output "rss.xml"

allkeywords=$(ls tags/ | sort | sed 's/\(.*\)/--metadata keywords:\1/' | paste -sd ' ' -)

pandoc empty.md .temp.yaml \
    --template rss.html.template \
    --to html5 \
    $allkeywords \
    --output "rss.html"

rm .temp.yaml

for f in *.rst
do
  draftprefix=$(echo $(grep -w $f -e '^:Status: Published$' || echo '.') | sed s/':Status: Published'//)
  filename=$(basename $f .rst).html
  keywords=$(find tags/*/* | grep "$filename" | sed 's/[^/]*\/\([^/]*\)\/.*/--metadata keywords:\1/' | paste -sd " " -)
  comments=$(test $f == 'index.rst' || echo --metadata comments:true)
  include=$(test $f != 'index.rst' || echo --include-after-body rss.html)

  pandoc $f \
  	--template base.template \
    --css 'https://lahteenmaki.net/style.css' \
    --css styles.css \
    --section-divs \
    $keywords \
    --metadata filename:"$filename" \
    --metadata 'title-suffix':'Architecturally Elegant' \
    $comments \
    $include \
    --to html5 \
    --output "$draftprefix$filename"
done

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

  pandoc empty.md .temp.yaml \
    --template rss.html.template \
    --to html5 \
    --output ".temp.html"

  pandoc empty.md \
    --template base.template \
    --css 'https://lahteenmaki.net/style.css' \
    --css ../../styles.css \
    --section-divs \
    --metadata 'title-suffix':'Architecturally Elegant' \
    --metadata 'title':"Tag: $tag" \
    --to html5 \
    --include-after-body .temp.html \
    --output "tags/$tag/index.html"
done
rm .temp.yaml

# check all tags (symbolic links) are valid
test $(find tags -type l -exec sh -c "file -b {} | grep -q ^broken" \; -print | wc -l) -eq 0 || (echo 'Invalid tag symlinks!'; exit 1)
