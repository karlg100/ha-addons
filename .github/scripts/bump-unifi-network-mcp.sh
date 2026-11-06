#!/bin/sh
# Bump the unifi_network_mcp add-on to the latest unifi-network-mcp on PyPI.
#
# Updates, together:
#   - the pinned version in the Dockerfile (what gets installed)
#   - version: in config.yaml (what Home Assistant watches for updates)
#   - CHANGELOG.md (what HA shows in the update dialog)
#
# Writes changed / current / latest / bump / requires_python to
# $GITHUB_OUTPUT when it is set. LATEST_VERSION overrides the PyPI lookup
# (for testing).
set -eu

ADDON_DIR="${ADDON_DIR:-unifi_network_mcp}"
PACKAGE=unifi-network-mcp
DOCKERFILE="$ADDON_DIR/Dockerfile"
CONFIG="$ADDON_DIR/config.yaml"
CHANGELOG="$ADDON_DIR/CHANGELOG.md"

out() {
  echo "$1=$2"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi
}

current="$(sed -n 's/^ARG UNIFI_NETWORK_MCP_VERSION=//p' "$DOCKERFILE")"
[ -n "$current" ] || { echo "Could not find the pinned version in $DOCKERFILE" >&2; exit 1; }

if [ -n "${LATEST_VERSION:-}" ]; then
  latest="$LATEST_VERSION"
  requires_python="${REQUIRES_PYTHON:->=3.13}"
else
  meta="$(curl -fsS "https://pypi.org/pypi/$PACKAGE/json")"
  # info.version is the newest non-prerelease
  latest="$(printf '%s' "$meta" | jq -r '.info.version')"
  requires_python="$(printf '%s' "$meta" | jq -r '.info.requires_python // ""')"
fi

out current "$current"
out latest "$latest"
out requires_python "$requires_python"

newest="$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)"
if [ "$latest" = "$current" ] || [ "$newest" = "$current" ]; then
  echo "Already on the latest release ($current)."
  out changed false
  exit 0
fi

cur_major="${current%%.*}"; rest="${current#*.}"; cur_minor="${rest%%.*}"
new_major="${latest%%.*}";  rest="${latest#*.}";  new_minor="${rest%%.*}"
if [ "$cur_major" != "$new_major" ]; then bump="major"
elif [ "$cur_minor" != "$new_minor" ]; then bump="minor"
else bump="patch"
fi
out bump "$bump"

sed -i "s/^ARG UNIFI_NETWORK_MCP_VERSION=.*/ARG UNIFI_NETWORK_MCP_VERSION=$latest/" "$DOCKERFILE"
sed -i "s/^version: .*/version: \"$latest\"/" "$CONFIG"

tmp="$(mktemp)"
{
  echo "# Changelog"
  echo
  echo "## $latest"
  echo
  echo "- Update \`$PACKAGE\` from $current to $latest."
  echo "  See the [upstream changelog](https://github.com/sirkirby/unifi-mcp/blob/main/CHANGELOG.md)."
  sed '1{/^# Changelog$/d}' "$CHANGELOG"
} > "$tmp"
mv "$tmp" "$CHANGELOG"

out changed true
echo "Bumped $current -> $latest ($bump)."
