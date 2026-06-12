#!/usr/bin/env zsh
#
# ghostty/fork.sh — Ghostty hotkey fork script.
#
# Bind this to a global hotkey (Hammerspoon recommended) to fork the Claude
# session in the currently focused Ghostty pane.
#
# Ghostty 1.3.2-tip+: uses `tty of terminal` for precise pane→session mapping.
# Ghostty 1.3.1 (stable): falls back to `working directory` matching (best-effort).
#
# Mapping files live in ~/.local/state/branchnew/ghostty/<tty>, each containing:
#   line 1: Claude session id
#   line 2: working directory
#
emulate -L zsh
setopt err_exit pipe_fail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/branchnew"
GHOSTTY_DIR="$STATE_DIR/ghostty"
LOG="$STATE_DIR/ghostty-fork.log"

log() { printf '%s %s\n' "$(date '+%F %T')" "$1" >> "$LOG" 2>/dev/null; }

# Probe whether this Ghostty build exposes `tty of terminal`.
has_tty_prop() {
  osascript -e '
  tell application "Ghostty"
    return tty of focused terminal of selected tab of front window
  end tell' &>/dev/null
}

# ── Strategy A: precise TTY lookup (Ghostty tip / 1.4+) ──
lookup_by_tty() {
  local pane_info focus_tty focus_cwd tty_key
  pane_info="$(osascript -e '
  tell application "Ghostty"
    set t to focused terminal of selected tab of front window
    return (tty of t) & linefeed & (working directory of t)
  end tell' 2>/dev/null)"

  focus_tty="${pane_info%%$'\n'*}"
  focus_cwd="${pane_info#*$'\n'}"
  tty_key="${focus_tty##*/}"

  [[ -n "$tty_key" ]] || return 1

  local map_file="$GHOSTTY_DIR/$tty_key"
  [[ -f "$map_file" ]] || return 1

  sid="$(sed -n '1p' "$map_file")"
  cwd="$(sed -n '2p' "$map_file")"
  [[ -n "$cwd" ]] || cwd="$focus_cwd"
  [[ -n "$sid" ]] || return 1

  log "fork (tty): tty=$tty_key -> session=$sid cwd=$cwd"
}

# ── Strategy B: cwd matching fallback (Ghostty 1.3.1 stable) ──
lookup_by_cwd() {
  local focus_cwd
  focus_cwd="$(osascript -e '
  tell application "Ghostty"
    return working directory of focused terminal of selected tab of front window
  end tell' 2>/dev/null)"

  [[ -n "$focus_cwd" ]] || return 1

  local best_file="" best_sid="" best_cwd=""
  [[ -d "$GHOSTTY_DIR" ]] || return 1

  local f map_sid map_cwd
  for f in "$GHOSTTY_DIR"/*(N); do
    [[ -f "$f" ]] || continue
    map_sid="$(sed -n '1p' "$f")"
    map_cwd="$(sed -n '2p' "$f")"
    if [[ "$map_cwd" == "$focus_cwd" && -n "$map_sid" ]]; then
      if [[ -z "$best_file" || "$f" -nt "$best_file" ]]; then
        best_file="$f"
        best_sid="$map_sid"
        best_cwd="$map_cwd"
      fi
    fi
  done

  [[ -n "$best_sid" ]] || return 1
  sid="$best_sid"
  cwd="$best_cwd"

  log "fork (cwd fallback): cwd=$focus_cwd -> session=$sid"
}

# ── Resolve session ──
sid="" cwd=""
if has_tty_prop; then
  lookup_by_tty
else
  lookup_by_cwd
fi

if [[ -z "$sid" ]]; then
  log "no mapping found — open a Claude session in this pane first"
  osascript -e 'display notification "No Claude session in this pane" with title "branchnew"' 2>/dev/null
  exit 1
fi

# ── Parse direction flag ──
split_dir="right"
[[ "${1:-}" == "--down" ]] && split_dir="down"

# ── Split and fork ──
osascript - "$cwd" "$sid" "$split_dir" <<'APPLESCRIPT'
on run argv
  set cwd to item 1 of argv
  set sid to item 2 of argv
  set dir to item 3 of argv

  tell application "Ghostty"
    set currentTerm to focused terminal of selected tab of front window
    if dir is "down" then
      set newTerm to split currentTerm direction down
    else
      set newTerm to split currentTerm direction right
    end if
    delay 0.3
    set cmd to "cd " & quoted form of cwd & " && claude --resume " & quoted form of sid & " --fork-session -n fork"
    input text (cmd & linefeed) to newTerm
  end tell
end run
APPLESCRIPT
