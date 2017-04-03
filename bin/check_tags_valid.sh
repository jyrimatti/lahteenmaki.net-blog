#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -p bash file
set -eu

echo check all tags, i.e. symbolic links, are valid
test $(find tags -type l -exec sh -c "file -b {} | grep -q ^broken" \; -print | wc -l) -eq 0 || (echo 'Invalid tag symlinks!'; exit 1)