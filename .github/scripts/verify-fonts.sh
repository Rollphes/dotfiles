#!/usr/bin/env bash
set -euo pipefail

manifest='.chezmoidata/fonts.json'
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-fonts"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

case "$(uname -s)" in
  Darwin)
    font_dir="$HOME/Library/Fonts"
    verify_family=false
    ;;
  Linux)
    font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
    verify_family=true
    ;;
  *)
    echo 'Unsupported platform' >&2
    exit 1
    ;;
esac

while IFS= read -r id; do
  checksum="$(jq -r --arg id "$id" '.fonts[] | select(.id == $id) | .sha256' "$manifest")"
  managed_glob="$(jq -r --arg id "$id" '.fonts[] | select(.id == $id) | .managedGlob' "$manifest")"
  family="$(jq -r --arg id "$id" '.fonts[] | select(.id == $id) | .family' "$manifest")"
  names_file="$state_dir/$id.files"

  [[ "$(< "$state_dir/$id.sha256")" == "$checksum" ]]
  [[ -s "$names_file" ]]

  while IFS= read -r name; do
    [[ -f "$font_dir/$name" ]]
    if $verify_family; then
      [[ "$(fc-scan --format '%{family[0]}' "$font_dir/$name")" == "$family" ]]
    fi
  done < "$names_file"

  sort "$names_file" > "$work_dir/$id-expected.txt"
  find "$font_dir" -maxdepth 1 -type f -name "$managed_glob" -exec basename {} \; \
    | sort > "$work_dir/$id-actual.txt"
  diff -u "$work_dir/$id-expected.txt" "$work_dir/$id-actual.txt"
done < <(jq -r '.fonts[].id' "$manifest")
