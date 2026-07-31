#!/usr/bin/env bash
# ~/.claude/sidebar-split.sh — split the current iTerm2 pane and launch the
# sidebar companion pane (sidebar.py) in the new split.
#
# Uses iTerm2's documented AppleScript "split vertically" command (verified
# against the installed app's own scripting dictionary, sources/Keyboard/
# iTermKeyBindingAction.h upstream) with the "Claude Sidebar" dynamic profile
# (~/Library/Application Support/iTerm2/DynamicProfiles/claude-sidebar.json),
# whose Custom Command already launches sidebar.py.
osascript <<'APPLESCRIPT'
tell application "iTerm2"
  tell current session of current window
    split vertically with profile "Claude Sidebar"
  end tell
end tell
APPLESCRIPT
