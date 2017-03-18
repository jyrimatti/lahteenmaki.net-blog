#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash file pandoc nix
set -eu

DIR="$(dirname "${BASH_SOURCE[0]}")"

blogname='Architecturally Elegant'

metadata=.temp.yaml

$DIR/create_post_metadata.sh 'lahteenmaki.net' 'https://blog.lahteenmaki.net' "$blogname" $metadata

$DIR/create_rss_xml.sh $metadata 'rss.xml'

postshtml=rss.html
tagshtml=.temp.html

pandoc "$DIR/empty.md" $metadata \
    --template "$DIR/posts.template" \
    --to html5 \
    --output $postshtml

alltags=$(ls tags/ | sort | sed 's/\(.*\)/--metadata keywords:\1/' | paste -sd ' ' -)
pandoc "$DIR/empty.md" $metadata \
    --template "$DIR/tags.template" \
    --to html5 \
    $alltags \
    --output $tagshtml

rm $metadata

$DIR/create_posts.sh "$blogname" 'https://lahteenmaki.net/style.css' $postshtml $tagshtml

$DIR/create_tag_pages.sh "$blogname" 'https://lahteenmaki.net/style.css'

$DIR/check_tags_valid.sh
