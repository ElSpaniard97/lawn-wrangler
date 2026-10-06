#!/usr/bin/env bash
# Installs the pinned Godot editor and its web export template.
# Every download is checked against the SHA-512 below (copied from the
# release's SHA512-SUMS.txt) before it is used, so a tampered file fails here.
set -euo pipefail

VERSION="4.7.2-stable"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${VERSION/-/.}"
BIN_DIR="$HOME/godot"
BASE="https://github.com/godotengine/godot/releases/download/$VERSION"
EDITOR_ZIP="Godot_v${VERSION}_linux.x86_64.zip"
EDITOR_SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
TEMPLATES_TPZ="Godot_v${VERSION}_export_templates.tpz"
TEMPLATES_SHA512="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"

if [[ ! -x "$BIN_DIR/godot" || ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" ]]; then
  work="$(mktemp -d)"
  curl -fsSL --retry 3 -o "$work/$EDITOR_ZIP" "$BASE/$EDITOR_ZIP"
  curl -fsSL --retry 3 -o "$work/$TEMPLATES_TPZ" "$BASE/$TEMPLATES_TPZ"
  echo "$EDITOR_SHA512  $work/$EDITOR_ZIP" | sha512sum -c -
  echo "$TEMPLATES_SHA512  $work/$TEMPLATES_TPZ" | sha512sum -c -
  mkdir -p "$BIN_DIR" "$TEMPLATE_DIR"
  unzip -q -o "$work/$EDITOR_ZIP" -d "$work"
  mv "$work/Godot_v${VERSION}_linux.x86_64" "$BIN_DIR/godot"
  chmod +x "$BIN_DIR/godot"
  # Only the single-threaded web template is needed; skip the other ~1.2 GB.
  unzip -q -j -o "$work/$TEMPLATES_TPZ" templates/web_nothreads_release.zip templates/web_nothreads_debug.zip -d "$TEMPLATE_DIR"
  rm -rf "$work"
fi

echo "$BIN_DIR" >> "${GITHUB_PATH:-/dev/null}"
"$BIN_DIR/godot" --version
