#!/usr/bin/env bash
# ==============================================================================
# Alcalc — Installer Script for Omarchy
# Apple Calculator Language (ACL) Calculator Desktop Application
# (https://github.com/jvlianodorneles/alcalc)
# ==============================================================================

set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
STATE_DIR="${HOME}/.local/state/omarchy/alcalc"
MENU_FILE="${HOME}/.config/omarchy/extensions/omarchy-menu.jsonc"

echo "🧮 Installing Alcalc (Apple Calculator Language for Omarchy)..."

# Ensure directories
mkdir -p "${BIN_DIR}"
mkdir -p "${DESKTOP_DIR}"
mkdir -p "${ICON_DIR}"
mkdir -p "${STATE_DIR}"

# Build application with qmake6 or cmake
echo "Building Alcalc executable with Qt 6..."
cd "${SOURCE_DIR}"

if command -v qmake6 >/dev/null 2>&1; then
    qmake6 alcalc.pro
    make -j"$(nproc)"
elif command -v qmake >/dev/null 2>&1; then
    qmake alcalc.pro
    make -j"$(nproc)"
elif command -v cmake >/dev/null 2>&1; then
    mkdir -p build && cd build
    cmake ..
    make -j"$(nproc)"
    cp alcalc "${SOURCE_DIR}/alcalc"
    cd "${SOURCE_DIR}"
else
    echo "❌ Error: Neither qmake6 nor cmake was found on PATH."
    exit 1
fi

# Copy binary to ~/.local/bin/alcalc
cp "${SOURCE_DIR}/alcalc" "${BIN_DIR}/alcalc"
chmod +x "${BIN_DIR}/alcalc"
echo "✓ Installed executable to ${BIN_DIR}/alcalc"

# Copy desktop file
cp "${SOURCE_DIR}/data/alcalc.desktop" "${DESKTOP_DIR}/alcalc.desktop"
echo "✓ Installed desktop file to ${DESKTOP_DIR}/alcalc.desktop"

# Copy icon
cp "${SOURCE_DIR}/icons/alcalc.svg" "${ICON_DIR}/alcalc.svg"
echo "✓ Installed application icon to ${ICON_DIR}/alcalc.svg"

# Update desktop database if available
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
fi

# Register in Omarchy Application Menu if present
if [ -f "${MENU_FILE}" ]; then
  python3 -c "
menu_path = '${MENU_FILE}'
try:
    with open(menu_path, 'r') as f:
        content = f.read()
    if 'tools.math.alcalc' not in content:
        entry = '''  \"tools.math.alcalc\": {\"icon\":\"🧮\",\"label\":\"Alcalc (Apple Calculator Language)\",\"action\":\"alcalc\",\"aliases\":[\"alcalc\",\"calc\",\"apple calc\",\"calculator\",\"math\",\"acl\"]},\n'''
        pos = content.rfind('}')
        if pos != -1:
            new_content = content[:pos] + entry + content[pos:]
            with open(menu_path, 'w') as f:
                f.write(new_content)
            print('✓ Registered Alcalc in Omarchy Application Menu')
except Exception as e:
    pass
"
fi

# Configure floating window rule in Hyprland if present
HYPR_CONF="${HOME}/.config/hypr/hyprland.lua"
if [ -f "${HYPR_CONF}" ]; then
  python3 -c "
hypr_path = '${HYPR_CONF}'
try:
    with open(hypr_path, 'r') as f:
        content = f.read()
    if '\"alcalc\"' not in content:
        with open(hypr_path, 'a') as f:
            f.write('\n-- Alcalc floating window rule\no.window(\"alcalc\", { float = true })\n')
        print('✓ Configured Alcalc floating window rule in Hyprland')
except Exception as e:
    pass
"
fi

echo ""
echo "✨ Alcalc installed successfully!"
echo ""
echo "🚀 How to launch:"
echo "  • Desktop GUI:  Launch 'Alcalc' via Super+Space or type 'alcalc' in terminal"
echo "  • CLI Eval:     alcalc \"1..100 INSERT +\""
echo "  • Explain Mode: alcalc --explain \"5 TOTHE 2 + 1\""
echo "  • JSON Output:  alcalc --json \"10 20 30 MEAN\""
echo ""
