#!/bin/bash
set -e

LABEL="com.mocodesu.app.DailyForge"
APP_PATH="/Applications/DailyForge.app"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ $APP_PATH not found."
    echo "   Copy your built DailyForge.app to /Applications first."
    exit 1
fi

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
        <string>$APP_PATH/Contents/MacOS/DailyForge</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>LaunchOnlyOnce</key>
    <false/>
</dict>
</plist>
EOF

# Unload first if already loaded
launchctl unload "$PLIST_PATH" 2>/dev/null || true

launchctl load "$PLIST_PATH"
echo "✅ Installed and loaded $LABEL"
echo ""
echo "Verify with:    launchctl list | grep DailyForge"
echo "Uninstall with: launchctl unload $PLIST_PATH && rm $PLIST_PATH"
