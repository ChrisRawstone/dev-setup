#!/bin/bash
# Premium jewel-toned statusline for Claude Code, no bars, no bold.
# Reads the statusLine JSON payload from stdin and renders a 2-line widget.
# Keep it nearly fork-free (one jq, builtins for the rest): at Claude/Codex startup
# every new process on this Mac takes up to seconds, and the bar waits for this script.

# ---- palette (24-bit truecolor) — a distinct jewel tone per category ------
RESET=$'\033[0m'
DIM=$'\033[2m'

C_DIM=$'\033[38;2;120;125;135m'      # labels / separators / parens
C_TEXT=$'\033[38;2;229;231;235m'     # plain values (token counts, eta, cost, duration)
C_MODEL=$'\033[38;2;167;139;250m'    # model name — violet
C_BRANCH=$'\033[38;2;45;212;191m'    # git branch — teal
C_EFFORT=$'\033[38;2;245;166;35m'    # thinking effort — amber
C_SESSION=$'\033[38;2;236;72;153m'   # session id — pink
C_COST=$'\033[38;2;250;204;21m'      # cost — gold
C_DUR=$'\033[38;2;96;165;250m'       # duration — blue
C_TURN=$'\033[38;2;56;189;248m'      # turn timer — sky
C_GOOD=$'\033[38;2;74;222;128m'      # usage in healthy range — green
C_WARN=$'\033[38;2;250;204;21m'      # 70-89% used — gold
C_CRIT=$'\033[38;2;248;113;113m'     # 90%+ used — red
C_ADD=$'\033[38;2;74;222;128m'       # lines added — green
C_DEL=$'\033[38;2;248;113;113m'      # lines removed — red

SEP="${C_DIM} · ${RESET}"

# ---- pull everything out of the JSON in one jq call -----------------------
# NB: bash's `read` treats tab as IFS-whitespace and collapses/trims runs of
# it regardless of what IFS is set to, which silently eats empty fields. Use
# a non-whitespace delimiter (\x1f, unit separator) to avoid that.
JQ_ROW="$(jq -r '
    def tok: if . >= 1000000 then (. / 100000 | round / 10 | tostring) + "M"
             elif . >= 1000 then (. / 100 | round / 10 | tostring) + "k" else tostring end;
    def int: floor | tostring;
    (.context_window.current_usage // {}) as $u
    | [
      (.model.display_name // "Claude"),
      (.session_id // ""),
      (.effort.level // ""),
      (.workspace.current_dir // .cwd // "."),
      (.context_window.context_window_size // 0 | tostring),
      (.context_window.context_window_size // 0 | tok),
      (.context_window.used_percentage // 0 | int),
      (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0) | tok),
      (.cost.total_cost_usd // 0 | . * 100 | round | tostring | if length < 3 then ("00" + .)[-3:] else . end | .[:-2] + "." + .[-2:]),
      (.cost.total_duration_ms // 0 | int),
      (.cost.total_lines_added // 0 | tostring),
      (.cost.total_lines_removed // 0 | tostring),
      (.rate_limits.five_hour.used_percentage // -1 | int),
      (.rate_limits.five_hour.resets_at // 0 | int),
      (.rate_limits.seven_day.used_percentage // -1 | int),
      (.rate_limits.seven_day.resets_at // 0 | int),
      (.workspace.git_branch // ""),
      (now | int)
    ] | join("\u001f")
  ')"

IFS=$'\037' read -r MODEL SESSION_ID EFFORT CWD CTX_SIZE CTX_SIZE_FMT CTX_PCT_I CTX_USED_FMT \
  COST_FMT DUR_MS LINES_ADD LINES_DEL R5_PCT R5_RESET R7_PCT R7_RESET BRANCH NOW <<< "$JQ_ROW"

# Codex's footer runs this script too (cxstatusline/render.sh sets STATUSLINE_AGENT=codex):
# it has its own limits, no cost and no Fable.

# ---- helpers ---------------------------------------------------------------

# Each helper sets a variable rather than printing, so callers need no $(...) fork.
pct_color() {  # -> COLOR
  if   (( $1 >= 90 )); then COLOR="$C_CRIT"
  elif (( $1 >= 70 )); then COLOR="$C_WARN"
  else                      COLOR="$C_GOOD"
  fi
}

fmt_eta() {  # -> ETA
  local diff=$(( $1 - NOW ))
  if (( $1 <= 0 )); then ETA="—"; return; fi
  if (( diff <= 0 )); then ETA="now"; return; fi
  local d=$(( diff / 86400 )) h=$(( (diff % 86400) / 3600 )) m=$(( (diff % 3600) / 60 ))
  if   (( d > 0 )); then ETA="${d}d${h}h"
  elif (( h > 0 )); then ETA="${h}h${m}m"
  else                   ETA="${m}m"
  fi
}

fmt_duration() {  # -> DUR
  local sec=$(( $1 / 1000 ))
  local h=$(( sec / 3600 )) m=$(( (sec % 3600) / 60 )) s=$(( sec % 60 ))
  if   (( h > 0 )); then DUR="${h}h${m}m"
  elif (( m > 0 )); then DUR="${m}m${s}s"
  else                   DUR="${s}s"
  fi
}

# Branch from .git/HEAD (a worktree's .git file points at its gitdir), without running git.
git_branch() {  # -> BRANCH
  local d="$1" head="" line
  while [ -n "$d" ]; do
    if [ -d "$d/.git" ]; then head="$d/.git/HEAD"; break; fi
    if [ -f "$d/.git" ]; then
      read -r line < "$d/.git"; line="${line#gitdir: }"
      [ "${line#/}" = "$line" ] && line="$d/$line"
      head="$line/HEAD"; break
    fi
    [ "$d" = / ] && break
    d="${d%/*}"; [ -z "$d" ] && d=/
  done
  [ -r "$head" ] || return
  read -r line < "$head"
  case "$line" in
    "ref: refs/heads/"*) BRANCH="${line#ref: refs/heads/}" ;;
    ?*) BRANCH="detached:${line:0:7}" ;;
  esac
}

# ---- derived values ---------------------------------------------------

pct_color "$CTX_PCT_I"; CTX_COLOR="$COLOR"
fmt_duration "$DUR_MS"; DUR_FMT="$DUR"

SESSION_SHORT="${SESSION_ID:0:8}"

# Turn timer: written by ~/.claude/turn-timer.sh (UserPromptSubmit/Stop hooks)
# as "<start> <stop>"; stop=0 means the agent is still working on this turn.
TURN_FMT=""; TURN_RUNNING=0
TURN_FILE="${HOME}/.claude/cache/turn-timer/${SESSION_ID}"
if [ -n "$SESSION_ID" ] && [ -r "$TURN_FILE" ]; then
  read -r T_START T_STOP < "$TURN_FILE"
  if [ -n "$T_START" ] && (( T_START > 0 )); then
    if (( T_STOP == 0 )); then T_END="$NOW"; TURN_RUNNING=1; else T_END="$T_STOP"; fi
    fmt_duration $(( (T_END - T_START) * 1000 )); TURN_FMT="$DUR"
  fi
fi

[ -z "$BRANCH" ] && git_branch "$CWD"

# ---- line 1: identity (model / branch / effort / session) + context ------

L1_PARTS=()
L1_PARTS+=("${C_MODEL}${MODEL}${RESET}")
[ -n "$BRANCH" ] && L1_PARTS+=("${C_BRANCH}⎇ ${BRANCH}${RESET}")
[ -n "$EFFORT" ] && L1_PARTS+=("${C_EFFORT}eff ${EFFORT}${RESET}")
[ -n "$SESSION_SHORT" ] && L1_PARTS+=("${C_SESSION}${DIM}${SESSION_SHORT}${RESET}")
CTX_PART="${C_DIM}ctx${RESET} ${CTX_COLOR}${CTX_PCT_I}%${RESET}"
# Codex reports no window size until its first turn
[ "$CTX_SIZE" != 0 ] && CTX_PART+=" ${C_DIM}(${C_TEXT}${CTX_USED_FMT}${C_DIM}/${CTX_SIZE_FMT})${RESET}"
L1_PARTS+=("$CTX_PART")

LINE1=""
first=1
for part in "${L1_PARTS[@]}"; do
  if [ "$first" = 1 ]; then LINE1+="$part"; first=0; else LINE1+="${SEP}${part}"; fi
done

# ---- rate limits: reuse the last known values on a cold start -------------
# The payload carries no rate_limits until Claude Code's first API response
# lands (~10s in), which is why a fresh session used to read "usage limits
# unavailable". Cache the live numbers (they are account-wide, so one file is
# shared by every session) and fall back to them while the live ones are
# missing. A cached window is only trusted while its own resets_at is still in
# the future — past that the window has rolled over and its old percentage is
# meaningless. Cached values render with a dim "~" so they read as estimates.

CACHE_FILE="${HOME}/.claude/cache/statusline-rate-limits${STATUSLINE_AGENT:+-$STATUSLINE_AGENT}"
STALE=0

if [ "$R5_PCT" != "-1" ] || [ "$R7_PCT" != "-1" ]; then
  # Rewrite only on change: a run killed between printf and mv leaves its temp file behind.
  NEW_ROW="${R5_PCT}"$'\037'"${R5_RESET}"$'\037'"${R7_PCT}"$'\037'"${R7_RESET}"
  OLD_ROW=""; [ -r "$CACHE_FILE" ] && read -r OLD_ROW < "$CACHE_FILE"
  if [ "$NEW_ROW" != "$OLD_ROW" ]; then
    [ -d "${CACHE_FILE%/*}" ] || mkdir -p "${CACHE_FILE%/*}" 2>/dev/null
    TMP="${CACHE_FILE}.$$"
    if printf '%s\n' "$NEW_ROW" > "$TMP" 2>/dev/null; then
      mv -f "$TMP" "$CACHE_FILE" 2>/dev/null || rm -f "$TMP" 2>/dev/null
    else
      rm -f "$TMP" 2>/dev/null
    fi
  fi
elif [ -r "$CACHE_FILE" ]; then
  IFS=$'\037' read -r C5_PCT C5_RESET C7_PCT C7_RESET < "$CACHE_FILE"
  if [ -n "$C5_PCT" ] && [ "$C5_PCT" != "-1" ] && (( ${C5_RESET%.*} > NOW )); then
    R5_PCT="$C5_PCT"; R5_RESET="$C5_RESET"; STALE=1
  fi
  if [ -n "$C7_PCT" ] && [ "$C7_PCT" != "-1" ] && (( ${C7_RESET%.*} > NOW )); then
    R7_PCT="$C7_PCT"; R7_RESET="$C7_RESET"; STALE=1
  fi
fi

STALE_MARK=""
[ "$STALE" = 1 ] && STALE_MARK="${C_DIM}~${RESET}"

# ---- Fable weekly window ----------------------------------------------------
# Not in the statusLine payload, so read it from the usage endpoint /usage uses,
# in the background at most every 2 min; this render shows the last fetched value.
# The file is "<pct> <resets_at> <fetched_at>"; rewriting fetched_at before the
# fetch keeps parallel sessions from all fetching at once.
FB_PCT=-1
if [ -z "$STATUSLINE_AGENT" ]; then
  FABLE_FILE="${HOME}/.claude/cache/statusline-fable"
  F_PCT="" F_RESET=0 F_AT=0
  [ -r "$FABLE_FILE" ] && IFS=$'\037' read -r F_PCT F_RESET F_AT < "$FABLE_FILE"
  if (( NOW - ${F_AT:-0} > 120 )); then
    [ -d "${FABLE_FILE%/*}" ] || mkdir -p "${FABLE_FILE%/*}" 2>/dev/null
    printf '%s\037%s\037%s\n' "$F_PCT" "${F_RESET:-0}" "$NOW" > "$FABLE_FILE"
    (
      TOKEN="$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty')"
      [ -n "$TOKEN" ] || exit 0
      curl -sf -m 10 https://api.anthropic.com/api/oauth/usage \
          -H "Authorization: Bearer ${TOKEN}" -H 'anthropic-beta: oauth-2025-04-20' \
        | jq -r --arg at "$NOW" 'first(.limits[]? | select(.kind == "weekly_scoped" and .scope.model.display_name == "Fable"))
                 | "\(.percent)\u001f\(.resets_at[0:19] + "Z" | fromdateiso8601)\u001f\($at)"' > "${FABLE_FILE}.$$" \
        && [ -s "${FABLE_FILE}.$$" ] && mv -f "${FABLE_FILE}.$$" "$FABLE_FILE"
      rm -f "${FABLE_FILE}.$$"
    ) </dev/null >/dev/null 2>&1 &
  fi
  # A window whose reset has passed rolled over; its old percentage means nothing.
  [ -n "$F_PCT" ] && (( ${F_RESET%.*} > NOW )) && FB_PCT="$F_PCT" FB_RESET="$F_RESET"
fi

# ---- line 2: usage windows + cost / duration / lines changed --------------

L2_PARTS=()

if [ "$R5_PCT" = "-1" ] && [ "$R7_PCT" = "-1" ]; then
  L2_PARTS+=("${C_DIM}${DIM}usage limits unavailable${RESET}")
else
  if [ "$R5_PCT" != "-1" ]; then
    pct_color "${R5_PCT%.*}"; fmt_eta "${R5_RESET%.*}"
    L2_PARTS+=("${C_DIM}5h${RESET} ${STALE_MARK}${COLOR}${R5_PCT%.*}%${RESET} ${C_DIM}↺${C_TEXT}${ETA}${RESET}")
  fi

  if [ "$R7_PCT" != "-1" ]; then
    pct_color "${R7_PCT%.*}"; fmt_eta "${R7_RESET%.*}"
    L2_PARTS+=("${C_DIM}7d${RESET} ${STALE_MARK}${COLOR}${R7_PCT%.*}%${RESET} ${C_DIM}↺${C_TEXT}${ETA}${RESET}")
  fi
fi

if [ "$FB_PCT" != "-1" ]; then
  pct_color "${FB_PCT%.*}"; fmt_eta "${FB_RESET%.*}"
  L2_PARTS+=("${C_DIM}fable${RESET} ${COLOR}${FB_PCT%.*}%${RESET} ${C_DIM}↺${C_TEXT}${ETA}${RESET}")
fi

[ -z "$STATUSLINE_AGENT" ] && L2_PARTS+=("${C_COST}\$${COST_FMT}${RESET}")
L2_PARTS+=("${C_DIM}session${RESET} ${C_DUR}${DUR_FMT}${RESET}")
if [ -n "$TURN_FMT" ]; then
  if [ "$TURN_RUNNING" = 1 ]; then
    L2_PARTS+=("${C_DIM}turn${RESET} ${C_TURN}▸ ${TURN_FMT}${RESET}")
  else
    L2_PARTS+=("${C_DIM}turn${RESET} ${C_DIM}${TURN_FMT}${RESET}")
  fi
fi
L2_PARTS+=("${C_ADD}+${LINES_ADD}${RESET} ${C_DEL}-${LINES_DEL}${RESET}")

LINE2=""
first=1
for part in "${L2_PARTS[@]}"; do
  if [ "$first" = 1 ]; then LINE2+="$part"; first=0; else LINE2+="${SEP}${part}"; fi
done

printf '%s\n%s\n' "$LINE1" "$LINE2"
