#!/usr/bin/env bash
set -euo pipefail

manifest='.chezmoidata/fonts.json'
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

while IFS= read -r encoded_font; do
  encoded_font=${encoded_font%$'\r'}
  font="$(printf '%s' "$encoded_font" | base64 --decode)"
  id="$(jq -r '.id' <<< "$font" | tr -d '\r')"
  repository="$(jq -r '.repository' <<< "$font" | tr -d '\r')"
  asset_pattern="$(jq -r '.assetPattern' <<< "$font" | tr -d '\r')"
  file_pattern="$(jq -r '.filePattern' <<< "$font" | tr -d '\r')"
  release="$work_dir/$id-release.json"
  gh api "repos/$repository/releases/latest" > "$release"

  if [[ "$(jq -r '.draft or .prerelease' "$release")" != false ]]; then
    echo "$repository: latest release is not stable" >&2
    exit 1
  fi

  mapfile -t assets < <(
    jq -r --arg pattern "$asset_pattern" \
      '.assets[] | select(.name | test($pattern)) | [.name, .browser_download_url] | @tsv' \
      "$release"
  )
  if [[ ${#assets[@]} -ne 1 ]]; then
    echo "$repository: expected one asset matching $asset_pattern, found ${#assets[@]}" >&2
    exit 1
  fi

  IFS=$'\t' read -r asset url <<< "${assets[0]}"
  url=${url%$'\r'}
  tag="$(jq -r '.tag_name' "$release" | tr -d '\r')"
  archive="$work_dir/$id.zip"
  curl \
    --proto '=https' \
    --tlsv1.2 \
    --fail \
    --silent \
    --show-error \
    --location \
    --output "$archive" \
    "$url"

  checksum="$(sha256sum "$archive" | awk '{print $1}')"
  matched_names="$work_dir/$id-files.txt"
  unzip -Z1 "$archive" \
    | awk -F/ '{print $NF}' \
    | grep -E "$file_pattern" \
    | sort > "$matched_names"
  if [[ ! -s "$matched_names" ]]; then
    echo "$id: managed TTFs were not found" >&2
    exit 1
  fi
  if [[ "$(wc -l < "$matched_names")" -ne "$(sort -u "$matched_names" | wc -l)" ]]; then
    echo "$id: duplicate managed TTF names" >&2
    exit 1
  fi

  updated="$work_dir/manifest.json"
  jq \
    --arg id "$id" \
    --arg tag "$tag" \
    --arg asset "$asset" \
    --arg checksum "$checksum" \
    '(.fonts[] | select(.id == $id)) |=
      (.tag = $tag | .asset = $asset | .sha256 = $checksum)' \
    "$manifest" > "$updated"
  tr -d '\r' < "$updated" > "$updated.lf"
  mv "$updated.lf" "$manifest"

  echo "$id: $tag $asset sha256:$checksum"
done < <(
  jq -r '.fonts[] | @base64' "$manifest"
)

if git diff --quiet -- "$manifest"; then
  echo 'Font lock is current'
fi
