#!/bin/bash

set -u

BUNDLE_ID="com.mocodesu.app.DailyForge"
PREFS="$HOME/Library/Preferences/$BUNDLE_ID.plist"

LOG="$HOME/Library/Logs/DailyForge-launcher.log"


log() {
    echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
}


log "============================================================"
log "DailyForge launcher started"


# ============================================================
# 1. Is DailyForge already running?
# ============================================================

if /usr/bin/pgrep -x "DailyForge" >/dev/null 2>&1; then
    log "DailyForge is already running. App-side enforcement evaluation is active."
    exit 0
fi


if [ ! -f "$PREFS" ]; then
    log "Local preferences not found. Exiting."
    exit 0
fi

REMINDER_ENABLED=$(
    /usr/bin/plutil -extract reminderEnabled raw "$PREFS" 2>/dev/null || echo "false"
)
if [ "$REMINDER_ENABLED" = "true" ] || [ "$REMINDER_ENABLED" = "1" ]; then
    REMINDER_ENABLED=1
else
    REMINDER_ENABLED=0
fi

REMINDER_SECS=$(
    /usr/bin/plutil -extract reminderTimeSeconds raw "$PREFS" 2>/dev/null || echo "68400"
)

log "reminderEnabled=$REMINDER_ENABLED"
log "reminderTimeSeconds=$REMINDER_SECS"

if [ "$REMINDER_ENABLED" != "1" ]; then
    log "Reminder is disabled. Exiting."
    exit 0
fi

if ! [[ "$REMINDER_SECS" =~ ^[0-9]+$ ]]; then
    log "Invalid reminderTimeSeconds: $REMINDER_SECS"
    exit 1
fi

H=$(/bin/date +%H)
M=$(/bin/date +%M)
S=$(/bin/date +%S)
NOW_SECS=$((10#$H * 3600 + 10#$M * 60 + 10#$S))
LAUNCH_THRESHOLD=$((REMINDER_SECS - 300))

if [ "$NOW_SECS" -lt "$LAUNCH_THRESHOLD" ]; then
    REM_H=$((REMINDER_SECS / 3600))
    REM_M=$(((REMINDER_SECS % 3600) / 60))
    log "Reminder at ${REM_H}:$(printf '%02d' "$REM_M"); outside launch window. Exiting."
    exit 0
fi

log "Reminder window reached; launching regardless of enforceKiosk."

if /usr/bin/open -b "$BUNDLE_ID"; then
    log "LaunchServices accepted the launch request."
else
    log "ERROR: LaunchServices failed to launch DailyForge."
    exit 1
fi


# Give macOS a moment to start the app.
sleep 3


if /usr/bin/pgrep -x "DailyForge" >/dev/null 2>&1; then
    log "SUCCESS: DailyForge is running."
else
    log "WARNING: LaunchServices accepted the request but DailyForge is not running yet."
fi

exit 0
