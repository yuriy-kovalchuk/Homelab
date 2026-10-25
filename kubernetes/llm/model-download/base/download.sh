#!/bin/sh
# Downloads every file in the list given as $1 onto the volume at /models.
# Each line is "<url> <path under the volume> [<sha256>]"; blank lines and
# lines starting with # are skipped.
#
# A finished file gets a <file>.done marker and is skipped on later runs.
# A file that is already there without a .part next to it was finished by an
# older downloader that wrote no markers: it is marked done, not fetched again.
# A partial download stays as <file>.part and is resumed on the next try.
set -eu

grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$1" | while read -r url path sha; do
  f="/models/$path"
  if [ -f "$f.done" ]; then
    echo "[SKIP] $path"
    continue
  fi
  if [ -f "$f" ] && [ ! -f "$f.part" ]; then
    date '+%Y-%m-%d %H:%M' > "$f.done"
    echo "[SKIP] $path (already present, marked done)"
    continue
  fi
  mkdir -p "$(dirname "$f")"
  echo "[DL] $url -> $path"
  wget -c -O "$f.part" "$url"
  if [ -n "${sha:-}" ]; then
    # a corrupt file must not be resumed: start over on the next try
    echo "$sha  $f.part" | sha256sum -c - || { rm -f "$f.part"; exit 1; }
  fi
  mv -f "$f.part" "$f"
  date '+%Y-%m-%d %H:%M' > "$f.done"
  # Strata's setup reads "sha256 <hash>" in a marker as already verified and
  # skips hashing the file again (minutes for a 38 GB GGUF)
  if [ -n "${sha:-}" ]; then echo "sha256 $sha" >> "$f.done"; fi
  echo "[OK] $path"
done
echo "all files present"
