#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash file pandoc nix
set -eu

DIR="$(dirname "${BASH_SOURCE[0]}")"

blogsite="lahteenmaki.net"
blogurl="https://blog.$blogsite"
blogname="Architecturally Elegant"

# site-relative path to feed
rsspath="rss.xml"

# site-relative path to an HTML-fragment listing the posts
fragmentpath="rss.html"

metadata=$(mktemp)

echo Create blog content metadata file to be used in subsequent steps
$DIR/create_post_metadata.sh "$blogsite" "$blogurl" "$blogname" "$metadata"

echo Create feed file
$DIR/create_rss_xml.sh "$metadata" "$rsspath"

echo Create a HTML fragment to
echo ' 1) list posts on the blog frontpage'
echo ' 2) list posts as HTML in an external site'
# Empty content since all data is within metadata
pandoc "$DIR/empty.md" "$metadata" \
    --template "$DIR/fragment.template" \
    --to html5 \
    --output "$fragmentpath"

alltags=$(ls tags/ | sort | sed 's/\(.*\)/--metadata keywords:\1/' | paste -sd ' ' -)
tagslist=$(pandoc "$DIR/empty.md" "$metadata" \
    --template "$DIR/tags.template" \
    --to html5 \
    $alltags)

echo Create the individual post pages
$DIR/create_posts.sh "$blogname" "https://$blogsite/style.css" "$fragmentpath" "$tagslist"

echo Create a page for each tag, listing all posts having that tag
$DIR/create_tag_pages.sh "$blogname" "https://$blogsite/style.css"

echo Check tag symlinks are valid
$DIR/check_tags_valid.sh

echo Done!
