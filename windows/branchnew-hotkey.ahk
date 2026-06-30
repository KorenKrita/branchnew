#Requires AutoHotkey v2.0
#SingleInstance Force
;
; branchnew-hotkey.ahk — system-wide hotkey fork for Windows Terminal (WSL).
;
; Binds Ctrl+Shift+F (right) / Ctrl+Shift+Alt+F (down) to send `/branchnew\r`
; (or `/branchnew --down\r`) to the focused Windows Terminal pane. Both Claude
; Code and OMP register `/branchnew` as a slash command, so the TUI's input
; controller recognizes it and expands it (it is NOT swallowed as a raw prompt).
;
; This is the Windows/WSL equivalent of iTerm2's ⌘F (claude_fork.py) and
; Ghostty's Hammerspoon binding — a system-level hotkey that triggers the fork.
;
; Requirements:
;   - AutoHotkey v2 (https://www.autohotkey.com/)
;   - Windows Terminal running WSL, with `branchnew` on PATH
;   - Claude Code: /branchnew slash command (auto-installed to ~/.claude/commands/)
;   - OMP:        /branchnew slash command (auto-installed to ~/.omp/agent/commands/)
;
; Install: save this file, double-click to run (or put in Startup folder).
; The hotkey only fires when a WindowsTerminal.exe window is focused, so it
; won't interfere with Ctrl+Shift+F in other apps (e.g. browser Find).

#HotIf WinActive("ahk_exe WindowsTerminal.exe") || WinActive("ahk_exe WindowsTerminalPreview.exe")

; Fork right
^+f:: {
    SendText "/branchnew"
    Send "{Enter}"
}

; Fork down
^+!f:: {
    SendText "/branchnew --down"
    Send "{Enter}"
}

#HotIf
