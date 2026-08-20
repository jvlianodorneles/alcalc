#!/usr/bin/env bash
# ==============================================================================
# Alcalc — Uninstaller Script for Omarchy
# (https://github.com/jvlianodorneles/alcalc)
# ==============================================================================

set -e

BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
OMARCHY_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/dorneles.alcalc"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"

UNINSTALL_APP=true
UNINSTALL_PLUGIN=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin-only|-p)
      UNINSTALL_APP=false
      UNINSTALL_PLUGIN=true
      shift
      ;;
    --app-only|-a)
      UNINSTALL_APP=true
      UNINSTALL_PLUGIN=false
      shift
      ;;
    --all)
      UNINSTALL_APP=true
      UNINSTALL_PLUGIN=true
      shift
      ;;
    -h|--help)
      echo "Usage: ./uninstall.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --all              Uninstall everything (default)"
      echo "  --plugin-only, -p  Uninstall ONLY the Omarchy plugin"
      echo "  --app-only, -a     Uninstall ONLY the Desktop App & CLI"
      echo "  -h, --help         Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run './uninstall.sh --help' for available options."
      exit 1
      ;;
  esac
done

echo "🗑️ Uninstalling Alcalc..."

if [ "$UNINSTALL_APP" = true ]; then
  rm -f "${BIN_DIR}/alcalc"
  echo "✓ Removed ${BIN_DIR}/alcalc"

  rm -f "${DESKTOP_DIR}/alcalc.desktop"
  echo "✓ Removed ${DESKTOP_DIR}/alcalc.desktop"

  rm -f "${ICON_DIR}/alcalc.svg"
  echo "✓ Removed ${ICON_DIR}/alcalc.svg"

  if command -v update-desktop-database >/dev/null 2>&1; then
      update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
  fi
fi

if [ "$UNINSTALL_PLUGIN" = true ]; then
  rm -rf "${OMARCHY_PLUGIN_DIR}"
  echo "✓ Removed Omarchy plugin (${OMARCHY_PLUGIN_DIR})"

  # Remove from Omarchy shell.json if present
  if [ -f "${SHELL_CONFIG}" ]; then
    python3 -c "
import json
config_path = '${SHELL_CONFIG}'
try:
    with open(config_path, 'r') as f:
        data = json.load(f)
    for section in ['left', 'center', 'right']:
        arr = data.get('bar', {}).get('layout', {}).get(section, [])
        data['bar']['layout'][section] = [item for item in arr if (item.get('id') if isinstance(item, dict) else item) != 'dorneles.alcalc']
    with open(config_path, 'w') as f:
        json.dump(data, f, indent=2)
    print('✓ Removed dorneles.alcalc from Omarchy bar layout')
except Exception as e:
    pass
"
  fi

  if command -v omarchy-restart-shell >/dev/null 2>&1; then
    omarchy-restart-shell >/dev/null 2>&1 || true
    echo "✓ Omarchy shell reloaded"
  fi
fi

echo "✨ Uninstallation finished."
