#!/bin/zsh -f
# Records turn start/stop times for the status line's turn timer.
# Usage: turn-timer.sh start|stop   (hook JSON payload on stdin)
# State file per session: "<start_epoch> <stop_epoch>" (stop=0 while running).
# Builtins only (no jq/date/find): it runs on every prompt and stop, and on this
# Mac every process start costs a lot while Claude is busy.
zmodload zsh/datetime
IN=$(</dev/stdin)
[[ $IN =~ '"session_id" *: *"([A-Za-z0-9_-]+)"' ]] || exit 0
DIR=$HOME/.claude/cache/turn-timer
[[ -d $DIR ]] || mkdir -p $DIR
F=$DIR/$match[1]
case $1 in
  start) print "$EPOCHSECONDS 0" > $F ;;
  stop)
    [[ -r $F ]] && read -r START _ < $F && [[ -n $START ]] && print "$START $EPOCHSECONDS" > $F
    old=($DIR/*(N.mw+1)); (( $#old )) && rm -f $old ;;  # prune state files older than a week
esac
exit 0
