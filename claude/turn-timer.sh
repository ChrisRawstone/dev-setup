#!/usr/bin/env bash
# Records turn start/stop times for the status line's turn timer.
# Usage: turn-timer.sh start|stop   (hook JSON payload on stdin)
# State file per session: "<start_epoch> <stop_epoch>" (stop=0 while running).
SID="$(jq -r '.session_id // empty' 2>/dev/null)"
[ -z "$SID" ] && exit 0
DIR="${HOME}/.claude/cache/turn-timer"
mkdir -p "$DIR" 2>/dev/null
F="${DIR}/${SID}"
NOW="$(date +%s)"
case "$1" in
  start) echo "$NOW 0" > "$F" ;;
  stop)  read -r START _ < "$F" 2>/dev/null; [ -n "$START" ] && echo "$START $NOW" > "$F" ;;
esac
# prune state files older than a week
find "$DIR" -type f -mtime +7 -delete 2>/dev/null
exit 0
