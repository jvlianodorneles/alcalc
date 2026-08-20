#!/usr/bin/env bash
# ==============================================================================
# Alcalc — Installer Script for Omarchy
# Apple Calculator Language (ACL) Calculator & Quickshell Plugin
# (https://github.com/jvlianodorneles/alcalc)
# ==============================================================================

set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
STATE_DIR="${HOME}/.local/state/omarchy/alcalc"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"
OMARCHY_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/dorneles.alcalc"
HYPR_CONF="${HOME}/.config/hypr/hyprland.lua"

INSTALL_APP=true
INSTALL_PLUGIN=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin-only|-p)
      INSTALL_APP=false
      INSTALL_PLUGIN=true
      shift
      ;;
    --app-only|-a)
      INSTALL_APP=true
      INSTALL_PLUGIN=false
      shift
      ;;
    --all)
      INSTALL_APP=true
      INSTALL_PLUGIN=true
      shift
      ;;
    -h|--help)
      echo "Usage: ./install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --all              Install full Desktop App, CLI and Omarchy Plugin (default)"
      echo "  --plugin-only, -p  Install ONLY the Omarchy Quickshell Plugin (no Qt6 build needed)"
      echo "  --app-only, -a     Install ONLY the Desktop Application & CLI"
      echo "  -h, --help         Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run './install.sh --help' for available options."
      exit 1
      ;;
  esac
done

echo "🧮 Installing Alcalc (Apple Calculator Language)..."

# Ensure common state directory
mkdir -p "${STATE_DIR}"

# ------------------------------------------------------------------------------
# 1. Build and Install Standalone App & CLI
# ------------------------------------------------------------------------------
if [ "$INSTALL_APP" = true ]; then
  echo ""
  echo "📦 [1/2] Building and Installing Desktop App & CLI..."
  mkdir -p "${BIN_DIR}"
  mkdir -p "${DESKTOP_DIR}"
  mkdir -p "${ICON_DIR}"

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

  install -Dm755 "${SOURCE_DIR}/alcalc" "${BIN_DIR}/alcalc"
  echo "✓ Installed executable to ${BIN_DIR}/alcalc"

  cp "${SOURCE_DIR}/data/alcalc.desktop" "${DESKTOP_DIR}/alcalc.desktop"
  echo "✓ Installed desktop file to ${DESKTOP_DIR}/alcalc.desktop"

  cp "${SOURCE_DIR}/icons/alcalc.svg" "${ICON_DIR}/alcalc.svg"
  echo "✓ Installed application icon to ${ICON_DIR}/alcalc.svg"

  if command -v update-desktop-database >/dev/null 2>&1; then
      update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
  fi

  # Configure floating window rule in Hyprland if present
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
fi

# ------------------------------------------------------------------------------
# 2. Install Omarchy Quickshell Plugin
# ------------------------------------------------------------------------------
if [ "$INSTALL_PLUGIN" = true ]; then
  echo ""
  echo "🔌 [2/2] Installing Omarchy Quickshell Plugin..."
  mkdir -p "${OMARCHY_PLUGIN_DIR}"
  cp "${SOURCE_DIR}/manifest.json" "${SOURCE_DIR}/BarWidget.qml" "${SOURCE_DIR}/Panel.qml" "${SOURCE_DIR}/Engine.js" "${OMARCHY_PLUGIN_DIR}/"
  echo "✓ Installed status bar plugin to ${OMARCHY_PLUGIN_DIR}"

  # Register in Omarchy shell.json bar layout if present
  if [ -f "${SHELL_CONFIG}" ]; then
    python3 -c "
import json
config_path = '${SHELL_CONFIG}'
try:
    with open(config_path, 'r') as f:
        data = json.load(f)
    bar_layout = data.setdefault('bar', {}).setdefault('layout', {})
    right_list = bar_layout.setdefault('right', [])
    ids = [item.get('id') if isinstance(item, dict) else item for item in right_list]
    if 'dorneles.alcalc' not in ids:
        right_list.insert(0, {'id': 'dorneles.alcalc'})
        with open(config_path, 'w') as f:
            json.dump(data, f, indent=2)
        print('✓ Registered dorneles.alcalc in Omarchy bar layout (shell.json)')
except Exception as e:
    pass
"
  fi

  # Restart shell if running to apply changes immediately
  if command -v omarchy-restart-shell >/dev/null 2>&1; then
    omarchy-restart-shell >/dev/null 2>&1 || true
    echo "✓ Omarchy shell reloaded"
  fi
fi

echo ""
echo "✨ Installation complete!"
if [ "$INSTALL_APP" = true ] && [ "$INSTALL_PLUGIN" = true ]; then
  echo "• Desktop App: Launch with 'alcalc' or via Application Menu"
  echo "• Status Bar Plugin: Active on your Omarchy top bar"
  echo "• CLI: Try 'alcalc \"2 * PI * 10\"' or 'alcalc --explain \"2^8 + 1\"'"
elif [ "$INSTALL_PLUGIN" = true ]; then
  echo "• Status Bar Plugin: Active on your Omarchy top bar"
elif [ "$INSTALL_APP" = true ]; then
  echo "• Desktop App: Launch with 'alcalc' or via Application Menu"
  echo "• CLI: Try 'alcalc \"2 * PI * 10\"'"
fi
