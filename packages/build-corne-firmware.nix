# Simple script to build Corne firmware with KeyPeek support.
# Uses the already-installed qmk CLI.
{
  writeShellScriptBin,
  git,
  qmk,
}: writeShellScriptBin "build-corne-firmware" ''
  set -euo pipefail

  QMK_HOME="$HOME/qmk_firmware"
  KEYMAP="$1"
  if [ -z "$KEYMAP" ]; then
    KEYMAP="default"
  fi

  # 1. Clone QMK firmware if missing
  if [ ! -d "$QMK_HOME/.git" ]; then
    echo "[+] Cloning QMK firmware (one-time, ~2-3 GB)..."
    git clone --recursive https://github.com/qmk/qmk_firmware.git "$QMK_HOME"
  fi

  export QMK_HOME
  qmk config user.qmk_home="$QMK_HOME"

  # 2. Add KeyPeek module
  if [ ! -d "$QMK_HOME/modules/srwi/.git" ]; then
    echo "[+] Adding KeyPeek module..."
    mkdir -p "$QMK_HOME/modules"
    git clone https://github.com/srwi/qmk-modules.git "$QMK_HOME/modules/srwi"
  fi

  # 3. Check if keymap exists
  KEYMAP_DIR="$QMK_HOME/keyboards/crkbd/keymaps/$KEYMAP"
  if [ ! -d "$KEYMAP_DIR" ]; then
    echo "[!] Keymap '$KEYMAP' not found."
    echo "    Creating from 'default' keymap..."
    cp -r "$QMK_HOME/keyboards/crkbd/keymaps/default" "$KEYMAP_DIR"
    echo "    Edit $KEYMAP_DIR/keymap.c to customize, then re-run."
  fi

  # 4. Inject KeyPeek module into keymap.json if present
  if [ -f "$KEYMAP_DIR/keymap.json" ]; then
    if ! grep -q '"srwi/keypeek_layer_notify"' "$KEYMAP_DIR/keymap.json" 2>/dev/null; then
      echo "[!] Please add 'srwi/keypeek_layer_notify' to the 'modules' array in:"
      echo "    $KEYMAP_DIR/keymap.json"
      echo "    (Or I can do this automatically if you want.)"
    fi
  fi

  # 5. Ensure rules.mk has RAW_ENABLE
  RULES_FILE="$KEYMAP_DIR/rules.mk"
  if [ -f "$RULES_FILE" ]; then
    if ! grep -q "^RAW_ENABLE = yes" "$RULES_FILE" 2>/dev/null; then
      echo "[!] Please add 'RAW_ENABLE = yes' to $RULES_FILE"
    fi
  fi

  # 6. Build
  echo "[+] Building Corne firmware with keymap '$KEYMAP'..."
  qmk compile -kb crkbd/rev1 -km "$KEYMAP"

  # 7. Export keyboard_info.json for KeyPeek
  echo "[+] Exporting keyboard_info.json..."
  qmk info -kb crkbd/rev1 -m -f json > "$HOME/keyboard_info.json"

  # 8. Report
  BUILT=$(find "$QMK_HOME/.build" -maxdepth 1 -name '*.uf2' -o -name '*.hex' | head -1)
  if [ -n "$BUILT" ]; then
    echo "[✓] Firmware built: $BUILT"
    echo "    Flash with: qmk flash -kb crkbd/rev1 -km $KEYMAP"
  fi
''