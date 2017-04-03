#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p bash pandoc
set -eu

blogsite=$1
blogurl=$2
blogname=$3
output=$4

echo ---                                      > $output
echo blogsite: "$blogsite"                   >> $output
echo blogurl: "$blogurl"                     >> $output
echo blogname: "$blogname"                   >> $output
echo post:                                   >> $output
for f in $(grep '^:Date:' $(grep -l '^:Status: Published$' *.rst) | sed s/::Date:// | sort --reverse --key 2 | cut -d' ' -f1 | paste -sd ' ')
do
  if [[ "$f" != 'index.rst' ]]
  then
    filename=$(basename $f .rst).html
    abstract=$(grep -w $f -e '^:Abstract:' | sed 's/^:Abstract:\s*//')
    date=$(grep -w $f -e '^:Date:' | sed 's/^:Date:\s*//')
    rfcdate=$(date --rfc-822 --date="$date")

    # post content without the HTML template
    content=$(pandoc $f \
        --to html5)
    
    echo "- title: $(head -1 $f)"            >> $output
    echo "  filename: $filename"             >> $output
    echo "  description: $abstract"          >> $output
    echo "  date: $date"                     >> $output
    echo "  rfcdate: $rfcdate"               >> $output
    echo "  content: |"                      >> $output
    echo "$content" | sed -e 's/^/   /g'     >> $output
  fi
done
echo ...                                     >> $output
