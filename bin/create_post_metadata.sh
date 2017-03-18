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
for f in $(grep ':Date:' *.rst | sed s/::Date:// | sort --reverse --key 2 | cut -d' ' -f1 | paste -sd ' ')
do
  if [[ "$f" != 'index.rst' ]]
  then
    filename=$(basename $f .rst).html
    abstract=$(grep -w $f -e '^:Abstract:' | sed 's/^:Abstract:\s*//')
    date=$(grep -w $f -e '^:Date:' | sed 's/^:Date:\s*//')
    echo "- title: $(head -1 $f)"            >> $output
    echo "  filename: $filename"             >> $output
    echo "  description: $abstract"          >> $output
    echo "  date: $date"                     >> $output
  fi
done
echo ...                                     >> $output