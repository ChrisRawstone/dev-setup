#!/usr/bin/env bash
# Premium jewel-toned statusline for Claude Code, no bars, no bold.
# Reads the statusLine JSON payload from stdin and renders a 2-line widget.

INPUT="$(cat)"

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
    [
      (.model.display_name // "Claude"),
      (.session_id // ""),
      (.effort.level // ""),
      (.workspace.current_dir // .cwd // "."),
      (.context_window.context_window_size // 0),
      (.context_window.used_percentage // 0),
      (.context_window.current_usage.input_tokens // 0),
      (.context_window.current_usage.cache_creation_input_tokens // 0),
      (.context_window.current_usage.cache_read_input_tokens // 0),
      (.cost.total_cost_usd // 0),
      (.cost.total_duration_ms // 0),
      (.cost.total_lines_added // 0),
      (.cost.total_lines_removed // 0),
      (.rate_limits.five_hour.used_percentage // -1),
      (.rate_limits.five_hour.resets_at // 0),
      (.rate_limits.seven_day.used_percentage // -1),
      (.rate_limits.seven_day.resets_at // 0)
    ] | @tsv
  ' <<< "$INPUT" | tr '\t' '\037')"

IFS=$'\037' read -r MODEL SESSION_ID EFFORT CWD \
  CTX_SIZE CTX_PCT CTX_IN CTX_CC CTX_CR \
  COST DUR_MS LINES_ADD LINES_DEL \
  R5_PCT R5_RESET R7_PCT R7_RESET <<< "$JQ_ROW"

NOW="$(date +%s)"

# ---- helpers ---------------------------------------------------------------

# integer part of a possibly-decimal string, e.g. "8.5" -> "8"
int_part() { local v="${1%.*}"; [ -z "$v" ] && v=0; echo "$v"; }

pct_color() {
  local p="$1"
  if   (( p >= 90 )); then echo "$C_CRIT"
  elif (( p >= 70 )); then echo "$C_WARN"
  else                     echo "$C_GOOD"
  fi
}

fmt_tokens() {
  local n="$1"
  if [ "$n" -ge 1000000 ] 2>/dev/null; then
    awk -v n="$n" 'BEGIN{v=n/1000000; if (v==int(v)) printf "%dM", v; else printf "%.1fM", v}'
  elif [ "$n" -ge 1000 ] 2>/dev/null; then
    awk -v n="$n" 'BEGIN{v=n/1000; if (v==int(v)) printf "%dk", v; else printf "%.1fk", v}'
  else
    printf '%d' "$n"
  fi
}

fmt_eta() {
  local target="$1"
  (( target <= 0 )) && { echo "—"; return; }
  local diff=$(( target - NOW ))
  if (( diff <= 0 )); then echo "now"; return; fi
  local d=$(( diff / 86400 )) h=$(( (diff % 86400) / 3600 )) m=$(( (diff % 3600) / 60 ))
  if   (( d > 0 )); then echo "${d}d${h}h"
  elif (( h > 0 )); then echo "${h}h${m}m"
  else                   echo "${m}m"
  fi
}

fmt_duration() {
  local ms="$1"
  local sec=$(( ms / 1000 ))
  local h=$(( sec / 3600 )) m=$(( (sec % 3600) / 60 )) s=$(( sec % 60 ))
  if   (( h > 0 )); then echo "${h}h${m}m"
  elif (( m > 0 )); then echo "${m}m${s}s"
  else                   echo "${s}s"
  fi
}

# ---- derived values ---------------------------------------------------

CTX_PCT_I="$(int_part "$CTX_PCT")"
CTX_USED=$(( CTX_IN + CTX_CC + CTX_CR ))
CTX_USED_FMT="$(fmt_tokens "$CTX_USED")"
CTX_SIZE_FMT="$(fmt_tokens "$CTX_SIZE")"
CTX_COLOR="$(pct_color "$CTX_PCT_I")"

COST_FMT="$(printf '%.2f' "$COST" 2>/dev/null || echo "0.00")"
DUR_FMT="$(fmt_duration "$DUR_MS")"

SESSION_SHORT="${SESSION_ID:0:8}"

# Turn timer: written by ~/.claude/turn-timer.sh (UserPromptSubmit/Stop hooks)
# as "<start> <stop>"; stop=0 means the agent is still working on this turn.
TURN_FMT=""; TURN_RUNNING=0
TURN_FILE="${HOME}/.claude/cache/turn-timer/${SESSION_ID}"
if [ -n "$SESSION_ID" ] && [ -r "$TURN_FILE" ]; then
  read -r T_START T_STOP < "$TURN_FILE"
  if [ -n "$T_START" ] && (( T_START > 0 )); then
    if (( T_STOP == 0 )); then T_END="$NOW"; TURN_RUNNING=1; else T_END="$T_STOP"; fi
    TURN_FMT="$(fmt_duration $(( (T_END - T_START) * 1000 )))"
  fi
fi

BRANCH=""
if command -v git >/dev/null 2>&1; then
  BRANCH="$(git -C "$CWD" branch --show-current 2>/dev/null)"
  if [ -z "$BRANCH" ]; then
    SHORTHASH="$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null)"
    [ -n "$SHORTHASH" ] && BRANCH="detached:${SHORTHASH}"
  fi
fi

# ---- line 1: identity (model / branch / effort / session) + context ------

L1_PARTS=()
L1_PARTS+=("${C_MODEL}${MODEL}${RESET}")
[ -n "$BRANCH" ] && L1_PARTS+=("${C_BRANCH}⎇ ${BRANCH}${RESET}")
[ -n "$EFFORT" ] && L1_PARTS+=("${C_EFFORT}eff ${EFFORT}${RESET}")
[ -n "$SESSION_SHORT" ] && L1_PARTS+=("${C_SESSION}${DIM}${SESSION_SHORT}${RESET}")
L1_PARTS+=("${C_DIM}ctx${RESET} ${CTX_COLOR}${CTX_PCT_I}%${RESET} ${C_DIM}(${C_TEXT}${CTX_USED_FMT}${C_DIM}/${CTX_SIZE_FMT})${RESET}")

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

CACHE_FILE="${HOME}/.claude/cache/statusline-rate-limits"
STALE=0

if [ "$R5_PCT" != "-1" ]; then
  mkdir -p "${CACHE_FILE%/*}" 2>/dev/null
  TMP="${CACHE_FILE}.$$"
  if printf '%s\037%s\037%s\037%s\n' \
       "$R5_PCT" "$R5_RESET" "$R7_PCT" "$R7_RESET" > "$TMP" 2>/dev/null; then
    mv -f "$TMP" "$CACHE_FILE" 2>/dev/null || rm -f "$TMP" 2>/dev/null
  else
    rm -f "$TMP" 2>/dev/null
  fi
elif [ -r "$CACHE_FILE" ]; then
  IFS=$'\037' read -r C5_PCT C5_RESET C7_PCT C7_RESET < "$CACHE_FILE"
  if [ -n "$C5_PCT" ] && [ "$C5_PCT" != "-1" ] && (( $(int_part "$C5_RESET") > NOW )); then
    R5_PCT="$C5_PCT"; R5_RESET="$C5_RESET"; STALE=1
  fi
  if [ -n "$C7_PCT" ] && [ "$C7_PCT" != "-1" ] && (( $(int_part "$C7_RESET") > NOW )); then
    R7_PCT="$C7_PCT"; R7_RESET="$C7_RESET"; STALE=1
  fi
fi

STALE_MARK=""
[ "$STALE" = 1 ] && STALE_MARK="${C_DIM}~${RESET}"

# ---- line 2: usage windows + cost / duration / lines changed --------------

L2_PARTS=()

if [ "$R5_PCT" = "-1" ] && [ "$R7_PCT" = "-1" ]; then
  L2_PARTS+=("${C_DIM}${DIM}usage limits unavailable${RESET}")
else
  if [ "$R5_PCT" != "-1" ]; then
    R5_PCT_I="$(int_part "$R5_PCT")"
    R5_COLOR="$(pct_color "$R5_PCT_I")"
    R5_ETA="$(fmt_eta "$R5_RESET")"
    L2_PARTS+=("${C_DIM}5h${RESET} ${STALE_MARK}${R5_COLOR}${R5_PCT_I}%${RESET} ${C_DIM}↺${C_TEXT}${R5_ETA}${RESET}")
  fi

  if [ "$R7_PCT" != "-1" ]; then
    R7_PCT_I="$(int_part "$R7_PCT")"
    R7_COLOR="$(pct_color "$R7_PCT_I")"
    R7_ETA="$(fmt_eta "$R7_RESET")"
    L2_PARTS+=("${C_DIM}7d${RESET} ${STALE_MARK}${R7_COLOR}${R7_PCT_I}%${RESET} ${C_DIM}↺${C_TEXT}${R7_ETA}${RESET}")
  fi
fi

L2_PARTS+=("${C_COST}\$${COST_FMT}${RESET}")
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
