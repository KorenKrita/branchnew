#!/usr/bin/env zsh
#
# ghostty/fork.sh — Ghostty hotkey fork script.
#
# Bind this to a global hotkey (Hammerspoon recommended) to fork the session
# in the currently focused Ghostty pane. Supports both OMP and Claude Code.
#
# Ghostty 1.3.2-tip+: uses `tty of terminal` for precise pane→session mapping.
# Ghostty 1.3.1 (stable): falls back to `working directory` matching (best-effort).
#
# Session backend auto-detected:
#   OMP: ~/.omp/agent/terminal-sessions/<tty> (line 2 = session jsonl path)
#   Claude: ~/.local/state/branchnew/ghostty/<tty> (line 1 = claude session id)
#
# - OMP: `omp --fork <jsonl>` + terminal-injected `/rename fork` (no --name flag)
# - Claude: `claude --resume <sid> --fork-session -n fork` (name via flag)
#
emulate -L zsh
setopt err_exit pipe_fail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/branchnew"
GHOSTTY_DIR="$STATE_DIR/ghostty"
OMP_SESSIONS="$HOME/.omp/agent/terminal-sessions"
OMP_DELAY="${BRANCHNEW_OMP_DELAY:-2}"
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

  # 1) OMP mapping: ~/.omp/agent/terminal-sessions/<tty> — line 2 is jsonl path
  local omp_map="$OMP_SESSIONS/$tty_key"
  if [[ -f "$omp_map" ]]; then
    omp_src="$(sed -n '2p' "$omp_map" 2>/dev/null)"
    if [[ -n "$omp_src" && -f "$omp_src" ]]; then
      backend="omp"
      cwd="$focus_cwd"
      log "fork (tty): tty=$tty_key -> OMP session=$omp_src cwd=$cwd"
      return 0
    fi
  fi

  # 2) Claude mapping: ~/.local/state/branchnew/ghostty/<tty> — line 1 is sid
  local claude_map="$GHOSTTY_DIR/$tty_key"
  if [[ -f "$claude_map" ]]; then
    sid="$(sed -n '1p' "$claude_map")"
    cwd="$(sed -n '2p' "$claude_map")"
    [[ -n "$cwd" ]] || cwd="$focus_cwd"
    if [[ -n "$sid" ]]; then
      backend="claude"
      log "fork (tty): tty=$tty_key -> Claude session=$sid cwd=$cwd"
      return 0
    fi
  fi

  return 1
}

# ── Strategy B: cwd matching fallback (Ghostty 1.3.1 stable) ──
# Only Claude uses branchnew's ghostty/ mapping dir; OMP's terminal-sessions
# is tty-keyed only, so the cwd fallback is Claude-only.
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
  backend="claude"
  sid="$best_sid"
  cwd="$best_cwd"
  log "fork (cwd fallback): cwd=$focus_cwd -> Claude session=$sid"
}

# ── Resolve session ──
backend="" sid="" omp_src="" cwd=""
if has_tty_prop; then
  lookup_by_tty || lookup_by_cwd
else
  lookup_by_cwd
fi

if [[ -z "$backend" ]]; then
  log "no mapping found — open an OMP or Claude session in this pane first"
  osascript -e 'display notification "No session in this pane" with title "branchnew"' 2>/dev/null
  exit 1
fi

# ── Parse direction flag ──
split_dir="right"
[[ "${1:-}" == "--down" ]] && split_dir="down"

# ── Build fork command per backend ──
q() { print -r -- "${(q)1}" }

if [[ "$backend" == "omp" ]]; then
  fork_cmd="cd $(q "$cwd") && omp --fork $(q "$omp_src")"
  rename_cmd="/rename fork"
else
  fork_cmd="cd $(q "$cwd") && claude --resume $(q "$sid") --fork-session -n fork"
  rename_cmd=""
fi

# ── Split and fork (single osascript keeps newTerm reference stable) ──
osascript - "$fork_cmd" "$split_dir" "${rename_cmd:+1}" "$rename_cmd" "$OMP_DELAY" <<'APPLESCRIPT'
on run argv
  set cmd to item 1 of argv
  set dir to item 2 of argv
  set hasRename to item 3 of argv
  set renameCmd to item 4 of argv
  set dly to item 5 of argv

  tell application "Ghostty"
    set currentTerm to focused terminal of selected tab of front window
    if dir is "down" then
      set newTerm to split currentTerm direction down
    else
      set newTerm to split currentTerm direction right
    end if
    delay 0.3
    -- fork command: raw pty write (no bracketed paste) + CR to execute
    perform action ("text:" & cmd & (ASCII character 13)) on newTerm
    if hasRename is "1" then
      delay dly
      -- /rename: just fill the input box (no CR) — user hits Enter manually.
      -- (TUI submit can't be reliably triggered via pty write due to bracketed
      -- paste / key-event translation limits; leaving it unsubmitted is robust.)
      input text renameCmd to newTerm
    end if
  end tell
end run
APPLESCRIPT
