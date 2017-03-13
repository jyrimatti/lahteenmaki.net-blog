#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p bash file pandoc
set -eu

# check all tags (symbolic links) are valid
test $(find tags -type l -exec sh -c "file -b {} | grep -q ^broken" \; -print | wc -l) -eq 0 || (echo 'Invalid tag symlinks!'; exit 1)

echo ---                           > .posts.yaml
echo post:                        >> .posts.yaml
for f in $(grep ':Date:' *.rst | sed s/::Date:// | sort --reverse --key 2 | cut -d' ' -f1 | paste -sd ' ')
do
  if [[ "$f" != 'index.rst' ]]
  then
    filename=$(basename $f .rst).html
    abstract=$(grep -w $f -e '^:Abstract:' | sed 's/^:Abstract:\s*//')
    date=$(grep -w $f -e '^:Date:' | sed 's/^:Date:\s*//')
    echo "- title: $(head -1 $f)"   >> .posts.yaml
    echo "  filename: $filename"    >> .posts.yaml
    echo "  description: $abstract" >> .posts.yaml
    echo "  date: $date" >> .posts.yaml
  fi
done
echo ... >> .posts.yaml

pandoc rss.md .posts.yaml \
    --template rss.template \
    --output "rss.xml"

allkeywords=$(ls tags/ | sort | sed 's/\(.*\)/--metadata keywords:\1/' | paste -sd ' ' -)

pandoc rss.md .posts.yaml \
    --template rss.html.template \
    --to html5 \
    $allkeywords \
    --output "rss.html"

rm .posts.yaml

for f in *.rst
do
  draftprefix=$(echo $(grep -w $f -e '^:Status: Published$' || echo '.') | sed s/':Status: Published'//)
  filename=$(basename $f .rst).html
  keywords=$(find tags/*/* | grep "$f" | sed 's/[^/]*\/\([^/]*\)\/.*/--metadata keywords:\1/' | paste -sd " " -)
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
