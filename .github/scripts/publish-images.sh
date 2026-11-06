#!/bin/sh
# Build and push the add-on image for every architecture in config.yaml,
# tagged with the add-on version, to the image name config.yaml points at.
#
# Version tags are immutable: a tag that already exists is never rebuilt or
# overwritten, so every published version stays exactly as it was released
# and remains available for rollback.
set -eu

ADDON_DIR="${ADDON_DIR:-unifi_network_mcp}"
CONFIG="$ADDON_DIR/config.yaml"

version="$(sed -n 's/^version: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$CONFIG")"
image_tpl="$(sed -n 's/^image: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$CONFIG")"
archs="$(sed -n '/^arch:/,/^[^ -]/s/^ *- *//p' "$CONFIG")"

[ -n "$version" ] || { echo "No version in $CONFIG" >&2; exit 1; }
[ -n "$image_tpl" ] || { echo "No image: in $CONFIG; nothing to publish" >&2; exit 1; }
[ -n "$archs" ] || { echo "No arch list in $CONFIG" >&2; exit 1; }

source_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-karlg100/ha-addons}"

for arch in $archs; do
  case "$arch" in
    amd64)   platform=linux/amd64 ;;
    aarch64) platform=linux/arm64 ;;
    armv7)   platform=linux/arm/v7 ;;
    *) echo "Unsupported arch: $arch" >&2; exit 1 ;;
  esac
  image="$(printf '%s' "$image_tpl" | sed "s/{arch}/$arch/")"
  ref="$image:$version"

  if docker manifest inspect "$ref" >/dev/null 2>&1; then
    echo "$ref already published; leaving it untouched."
    continue
  fi

  echo "Building and pushing $ref ($platform)"
  docker buildx build \
    --platform "$platform" \
    --label "io.hass.type=addon" \
    --label "io.hass.version=$version" \
    --label "io.hass.arch=$arch" \
    --label "org.opencontainers.image.source=$source_url" \
    --label "org.opencontainers.image.version=$version" \
    --tag "$ref" \
    --push \
    "$ADDON_DIR"
done

if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "version=$version" >> "$GITHUB_OUTPUT"; fi
