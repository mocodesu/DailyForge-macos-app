#!/bin/bash

set -u

BUNDLE_ID="com.mocodesu.app.DailyForge"
PREFS="$HOME/Library/Preferences/$BUNDLE_ID.plist"
STORE="$HOME/Library/Application Support/default.store"

LOG="$HOME/Library/Logs/DailyForge-launcher.log"


log() {
    echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
}


log "============================================================"
log "DailyForge launcher started"


# ============================================================
# 0. Rest days — read from user preferences
# ============================================================
#
# Swift's Gregorian `weekday` is: Sunday=1, Monday=2, …, Saturday=7.
# `date +%w` is: Sunday=0, Monday=1, …, Saturday=6.
# So we add 1 to `date +%w` to match Swift.
#
# The `restDaysRaw` preference is a comma-separated list of these
# Swift weekday numbers, e.g. "5,6" for Thursday + Friday.

if [ -f "$PREFS" ]; then
    REST_DAYS_RAW=$(
        /usr/bin/plutil -extract restDaysRaw raw "$PREFS" 2>/dev/null \
        || echo "5,6"
    )
else
    REST_DAYS_RAW="5,6"
fi

# Defensive: strip any surrounding whitespace, strip any "Optional(...)"
# wrapper plutil sometimes emits, and drop brackets if it came back as
# an array-style string.
REST_DAYS_RAW=$(echo "$REST_DAYS_RAW" | /usr/bin/tr -d '[]' | /usr/bin/xargs)

SWIFT_DOW=$(( $(/bin/date +%w) + 1 ))

IS_REST=0
IFS=',' read -ra REST_ARRAY <<< "$REST_DAYS_RAW"
for day in "${REST_ARRAY[@]}"; do
    trimmed=$(echo "$day" | /usr/bin/xargs)
    if [ "$trimmed" = "$SWIFT_DOW" ]; then
        IS_REST=1
        break
    fi
done

if [ "$IS_REST" = "1" ]; then
    log "Rest day (weekday=$SWIFT_DOW, configured: $REST_DAYS_RAW). Nothing to enforce."
    exit 0
fi


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

TODAY=$(/bin/date +%Y-%m-%d)

if [ ! -f "$STORE" ]; then
    log "DailyForge store not found. Exiting."
    exit 0
fi

LOCKED=$(
    /usr/bin/sqlite3 "$STORE" \
    "SELECT COUNT(*) FROM ZDAYLOCK WHERE ZDAYKEY = '$TODAY';" \
    2>/dev/null || echo "0"
)
if [ "$LOCKED" = "1" ]; then
    log "Today is sealed. Nothing to launch."
    exit 0
fi

DAILY_COUNT=$(
    /usr/bin/sqlite3 "$STORE" \
    "SELECT COUNT(*) FROM ZEXERCISE WHERE ZISDAILY = 1;" \
    2>/dev/null || echo "0"
)
DONE_COUNT=$(
    /usr/bin/sqlite3 "$STORE" \
    "SELECT COUNT(DISTINCT e.Z_PK) FROM ZEXERCISE e JOIN ZCOMPLETIONRECORD r ON r.ZEXERCISEID = e.ZID WHERE e.ZISDAILY = 1 AND r.ZDAYKEY = '$TODAY';" \
    2>/dev/null || echo "0"
)

if [ "$DAILY_COUNT" -eq 0 ]; then
    log "No daily exercises configured. Nothing to launch."
    exit 0
fi

log "Daily exercises: $DONE_COUNT/$DAILY_COUNT completed."
if [ "$DONE_COUNT" -ge "$DAILY_COUNT" ]; then
    log "All daily exercises are complete. Nothing to launch."
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
