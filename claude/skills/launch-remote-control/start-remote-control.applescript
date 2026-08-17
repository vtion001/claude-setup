-- Open a new Terminal window, run `claude`, wait for the TUI to load,
-- then type `/remote-control` + Return into that same window's tty.
-- Uses Terminal's `do script ... in <window>` so it injects into the
-- running claude process's stdin WITHOUT needing System Events / Accessibility.
--
-- Optional first arg = working directory to `cd` into before launching claude
-- (defaults to the ALTO repo). Pass via:  osascript start-remote-control.applescript /path/to/dir
on run argv
	set workDir to "/Users/archerterminez/Desktop/REPOSITORY/altoproperty-main"
	if (count of argv) > 0 then set workDir to item 1 of argv
	tell application "Terminal"
		activate
		-- cd first so the remote session starts in the right project
		set w to do script ("cd " & quoted form of workDir & " && claude")
		-- give claude time to fully start its TUI before we type into it
		delay 8
		do script "/remote-control" in w
	end tell
	return "launched"
end run
