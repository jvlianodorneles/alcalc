#!/usr/bin/env bash
# ==============================================================================
# Alcalc — Uninstaller Script for Omarchy
# (https://github.com/jvlianodorneles/alcalc)
# ==============================================================================

set -e

BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
MENU_FILE="${HOME}/.config/omarchy/extensions/omarchy-menu.jsonc"

echo "🗑️ Uninstalling Alcalc..."

rm -f "${BIN_DIR}/alcalc"
echo "✓ Removed ${BIN_DIR}/alcalc"

rm -f "${DESKTOP_DIR}/alcalc.desktop"
echo "✓ Removed ${DESKTOP_DIR}/alcalc.desktop"

rm -f "${ICON_DIR}/alcalc.svg"
echo "✓ Removed ${ICON_DIR}/alcalc.svg"

# Remove from Omarchy menu if present
if [ -f "${MENU_FILE}" ]; then
  python3 -c "
menu_path = '${MENU_FILE}'
try:
    with open(menu_path, 'r') as f:
        lines = f.readlines()
    new_lines = [l for l in lines if 'tools.math.alcalc' not in l]
    with open(menu_path, 'w') as f:
        f.writelines(new_lines)
    print('✓ Removed Alcalc from Omarchy Application Menu')
except Exception as e:
    pass
"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
fi

echo "✨ Alcalc uninstalled successfully."
