#!/bin/bash
# ============================================================
# DailyForge Login Item Installer
# ============================================================
#
# Installs:
#   1. A launcher script at
#        ~/Library/Application Support/DailyForge/dailyforge-launcher.sh
#      which decides whether DailyForge should actually be running.
#
#   2. A LaunchAgent at
#        ~/Library/LaunchAgents/com.mocodesu.app.DailyForge.plist
#      that runs the launcher:
#        - once at login (RunAtLoad)
#        - every 15 minutes (:00, :15, :30, :45)
#
# The launcher only opens the app when:
#   - the reminder is enabled
#   - enforcement is enabled
#   - the reminder time has already passed today
#   - there are daily exercises
#   - at least one daily exercise is still incomplete for today
#
# Otherwise it exits silently. If the app is already running, it does
# nothing — the pgrep guard at the top of the launcher handles that.
# ============================================================

set -e

LABEL="com.mocodesu.app.DailyForge"
BUNDLE_ID="com.mocodesu.app.DailyForge"
APP_PATH="/Applications/DailyForge.app"
SUPPORT_DIR="$HOME/Library/Application Support/DailyForge"
LAUNCHER="$SUPPORT_DIR/dailyforge-launcher.sh"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"

# ---------- Sanity checks ----------

if [ ! -d "$APP_PATH" ]; then
    echo "❌ $APP_PATH not found."
    echo "   Copy your built DailyForge.app to /Applications first."
    exit 1
fi

if [ ! -x "$APP_PATH/Contents/MacOS/DailyForge" ]; then
    echo "❌ $APP_PATH/Contents/MacOS/DailyForge is missing or not executable."
    exit 1
fi

# ---------- Write the launcher script ----------

mkdir -p "$SUPPORT_DIR"
mkdir -p "$HOME/Library/Logs"

cat > "$LAUNCHER" <<'LAUNCHER_SCRIPT'
#!/bin/bash
# ============================================================
# DailyForge launcher — decides whether to start the app based
# on today's reminder state. Safe to run repeatedly.
# ============================================================

BUNDLE_ID="com.mocodesu.app.DailyForge"
APP_PATH="/Applications/DailyForge.app"
STORE="$HOME/Library/Application Support/default.store"
LOG="$HOME/Library/Logs/DailyForge-launcher.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
}

# Rotate log if it grows past 200KB
if [ -f "$LOG" ] && [ "$(stat -f%z "$LOG" 2>/dev/null || echo 0)" -gt 204800 ]; then
    tail -n 400 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

# 1. Already running? Nothing to do.
if pgrep -x DailyForge > /dev/null; then
    exit 0
fi

# 2. Preferences present?
if ! defaults read "$BUNDLE_ID" > /dev/null 2>&1; then
    exit 0
fi

# 3. Reminder enabled?
REMINDER_ENABLED=$(defaults read "$BUNDLE_ID" reminderEnabled 2>/dev/null || echo "0")
if [ "$REMINDER_ENABLED" != "1" ]; then
    exit 0
fi

# 4. Enforcement enabled?
ENFORCE=$(defaults read "$BUNDLE_ID" enforceKiosk 2>/dev/null || echo "0")
if [ "$ENFORCE" != "1" ]; then
    exit 0
fi

# 5. Current time in seconds since midnight
H=$(date +%H); M=$(date +%M); S=$(date +%S)
NOW_SECS=$(( 10#$H * 3600 + 10#$M * 60 + 10#$S ))

# 6. Reminder time in seconds since midnight
REMINDER_SECS=$(defaults read "$BUNDLE_ID" reminderTimeSeconds 2>/dev/null || echo "68400")

if [ "$NOW_SECS" -lt "$REMINDER_SECS" ]; then
    REM_H=$(( REMINDER_SECS / 3600 ))
    REM_M=$(( (REMINDER_SECS % 3600) / 60 ))
    log "Reminder not yet fired (set for ${REM_H}:$(printf %02d $REM_M))."
    exit 0
fi

# 7. Store present?
if [ ! -f "$STORE" ]; then
    log "Store not found at $STORE. Skipping."
    exit 0
fi

# 8. Query the store
TODAY=$(date +%Y-%m-%d)

DAILY_COUNT=$(sqlite3 "$STORE" \
    "SELECT COUNT(*) FROM ZEXERCISE WHERE ZISDAILY = 1;" 2>/dev/null || echo "0")

if [ -z "$DAILY_COUNT" ] || [ "$DAILY_COUNT" -eq 0 ]; then
    log "No daily exercises configured. Skipping."
    exit 0
fi

DONE_COUNT=$(sqlite3 "$STORE" \
    "SELECT COUNT(*) FROM ZCOMPLETIONRECORD WHERE ZDAYKEY = '$TODAY';" 2>/dev/null || echo "0")

if [ -z "$DONE_COUNT" ]; then DONE_COUNT=0; fi

# 9. All done today?
if [ "$DONE_COUNT" -ge "$DAILY_COUNT" ]; then
    log "All done today ($DONE_COUNT/$DAILY_COUNT). Skipping."
    exit 0
fi

# 10. Missed tasks detected — launch
log "Missed tasks ($DONE_COUNT/$DAILY_COUNT done). Launching DailyForge."
open -a "$APP_PATH"
LAUNCHER_SCRIPT

chmod +x "$LAUNCHER"
echo "✅ Wrote launcher: $LAUNCHER"

# ---------- Write the LaunchAgent plist ----------

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$LAUNCHER</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StartCalendarInterval</key>
    <array>
        <dict><key>Minute</key><integer>0</integer></dict>
        <dict><key>Minute</key><integer>15</integer></dict>
        <dict><key>Minute</key><integer>30</integer></dict>
        <dict><key>Minute</key><integer>45</integer></dict>
    </array>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/DailyForge-launcher.out</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/DailyForge-launcher.err</string>
</dict>
</plist>
EOF

echo "✅ Wrote plist: $PLIST_PATH"

# ---------- Reload the LaunchAgent ----------

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo ""
echo "✅ Installed and loaded $LABEL"
echo ""
echo "The launcher runs:"
echo "  • once immediately at every login (RunAtLoad)"
echo "  • every 15 minutes at :00, :15, :30, :45 (StartCalendarInterval)"
echo ""
echo "It opens DailyForge only when:"
echo "  • reminder is enabled and enforcement is on"
echo "  • the reminder time has already passed today"
echo "  • at least one daily exercise is still incomplete"
echo ""
echo "Logs:        tail -f ~/Library/Logs/DailyForge-launcher.log"
echo "Run now:     bash '$LAUNCHER'"
echo "Next fire:   launchctl print gui/\$(id -u)/$LABEL | grep -A1 'next fire'"
echo "Uninstall:   launchctl unload '$PLIST_PATH' && rm '$PLIST_PATH' '$LAUNCHER'"
