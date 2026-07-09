#!/usr/bin/env bash
# List all available Lucide icon names that can be used with AppIcon.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Locate lucide_icons.dart via package_config.json
PKG_CONFIG="$PROJECT_DIR/.dart_tool/package_config.json"
if [ -f "$PKG_CONFIG" ]; then
  LUCIDE_DIR=$(python3 -c "
import json, sys
with open('$PKG_CONFIG') as f:
    cfg = json.load(f)
for p in cfg.get('packages', []):
    if p['name'] == 'lucide_icons_flutter':
        print(p['rootUri'].replace('file://', ''))
        sys.exit(0)
print('', end='')
" 2>/dev/null)
fi

if [ -z "${LUCIDE_DIR:-}" ]; then
  # Fallback: try pub cache
  LUCIDE_DIR="$HOME/.pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.14+2"
fi

ICONS_FILE="$LUCIDE_DIR/lib/lucide_icons.dart"

if [ ! -f "$ICONS_FILE" ]; then
  echo "Error: cannot find lucide_icons.dart" >&2
  echo "Tried: $ICONS_FILE" >&2
  exit 1
fi

echo "# Available Lucide icon names for AppIcon (thickness 0, i.e. stroke-width 2)"
echo ""

# Extract icon names from:  static const IconData <name> = const IconData(
# Then filter out:
#   - names ending with digits (thickness variants like xxx100..xxx600)
#   - names ending with 'Dir' (direction variants)
awk '
  /static const IconData [a-zA-Z]+ = const IconData\(/ {
    name = $4
    if (name !~ /[0-9]$/ && name !~ /Dir$/)
      print name
  }
' "$ICONS_FILE" | sort -u | awk '{print NR")", $0}'

echo ""
echo "# Total: $(awk '
  /static const IconData [a-zA-Z]+ = const IconData\(/ {
    name = $4
    if (name !~ /[0-9]$/ && name !~ /Dir$/)
      print name
  }
' "$ICONS_FILE" | sort -u | wc -l | tr -d " ")"
