#!/usr/bin/env bash
# מוריד ובונה את הגרסה החדשה של Theory Studies (מופעל מכפתור "הורד עדכון" בלינוקס)
set -e
REPO="$HOME/Theory-Studies-"
echo "=================================================="
echo "   מעדכן את Theory Studies לגרסה החדשה..."
echo "=================================================="
if [ -d "$REPO/.git" ]; then
  echo "==> מושך את הקוד החדש (git pull)..."
  cd "$REPO"
  git remote set-url origin https://github.com/amituti31-dev/Theory-Studies.git 2>/dev/null || true
  git config core.fileMode false          # ignore chmod +x differences
  git checkout -- . 2>/dev/null || true    # drop any local changes
  git pull
else
  echo "==> מוריד לראשונה (git clone)..."
  git clone https://github.com/amituti31-dev/Theory-Studies.git "$REPO"
  cd "$REPO"
fi
cd theory_linux
chmod +x build_linux.sh
# GROQ_API_KEY (אופציונלי, למענה קולי) עובר הלאה אם הוגדר
./build_linux.sh
echo ""
echo "=================================================="
echo "  ✅ העדכון הושלם! מפעיל את הגרסה החדשה..."
echo "=================================================="
APP="$REPO/theory_linux/LimudeiTeoria-x86_64.AppImage"
if [ -f "$APP" ]; then
  chmod +x "$APP"
  setsid "$APP" >/dev/null 2>&1 &
fi
echo "אפשר לסגור את החלון הזה."
