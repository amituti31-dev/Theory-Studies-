#!/usr/bin/env bash
# ==========================================================
#  לימודי תיאוריה — בניית גרסת לינוקס (Ubuntu / Linux Mint)
#  הרצה:  chmod +x build_linux.sh  &&  ./build_linux.sh
# ==========================================================
set -e
cd "$(dirname "$0")"

echo "==> [1/5] מתקין תלויות מערכת (יבקש סיסמת sudo)..."
sudo apt-get update
sudo apt-get install -y \
  curl git unzip xz-utils zip libglu1-mesa \
  clang cmake ninja-build pkg-config libgtk-3-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav \
  libasound2-dev wget file libfuse2 \
  python3 python3-pip

echo "==> [2/5] מתקין את מנוע ההקראה (edge-tts)..."
pip3 install --user --break-system-packages edge-tts aiohttp \
  || pip3 install --user edge-tts aiohttp

echo "==> [3/5] בודק ש-Flutter מותקן..."
if ! command -v flutter >/dev/null 2>&1 && [ ! -d "$HOME/flutter/bin" ]; then
  echo "    Flutter לא נמצא — מתקין דרך git (~1GB, כמה דקות)..."
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
fi
# ensure flutter is on PATH for this script even if freshly cloned
[ -d "$HOME/flutter/bin" ] && export PATH="$HOME/flutter/bin:$PATH"
flutter config --enable-linux-desktop

echo "==> [4/5] מוריד תלויות ובונה (עשוי לקחת כמה דקות)..."
flutter pub get
flutter build linux --release

echo "==> [5/5] אורז לקובץ AppImage יחיד (לוחצים פעמיים -> רץ)..."
APP_DIR="$(pwd)/build/linux/x64/release/bundle"
APPDIR="$(pwd)/AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR"
cp -r "$APP_DIR/." "$APPDIR/"
cp "$(pwd)/linux_icon.png" "$APPDIR/limudei_teoria.png"
cat > "$APPDIR/limudei_teoria.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Theory Studies
Comment=לימוד למבחן התיאוריה
Exec=theory_desktop
Icon=limudei_teoria
Terminal=false
Categories=Education;
EOF
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="/usr/bin:/bin:$PATH"
exec "${HERE}/theory_desktop" "$@"
EOF
chmod +x "$APPDIR/AppRun"

TOOL="$(pwd)/appimagetool-x86_64.AppImage"
if [ ! -f "$TOOL" ]; then
  echo "    מוריד את כלי האריזה (appimagetool)..."
  wget -q -O "$TOOL" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "$TOOL"
fi
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
OUT="$(pwd)/LimudeiTeoria-x86_64.AppImage"
"$TOOL" "$APPDIR" "$OUT"
chmod +x "$OUT"

echo ""
echo "=================================================="
echo "  ✅ סיום! נוצר קובץ אחד:"
echo "     $OUT"
echo ""
echo "  לוחצים עליו פעמיים -> התוכנה רצה."
echo "  אפשר להעביר אותו לכל מחשב לינוקס אחר."
echo "=================================================="
