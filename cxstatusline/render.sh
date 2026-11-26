#!/bin/bash
# Codex footer: map cxstatusline's payload onto Claude Code's statusLine JSON and draw it
# with the same ~/.claude/statusline.sh, so both bars look the same. Bash + jq, because
# patched Codex drops any render slower than 1s and the node renderer often was.
OUT="$(jq -c '
  def epoch: if . then (.[0:19] + "Z" | fromdateiso8601) else null end;
  def window: if . then {used_percentage: (.used * 100), resets_at: (.resets_at | epoch)} else null end;
  (.session.run_state // "" | ascii_downcase) as $rs
  | (.session.id // ""),
  {
    model: {display_name: .model.name},
    session_id: .session.id,
    effort: {level: .model.reasoning},
    workspace: {current_dir: .session.cwd, git_branch: .git.branch},
    context_window: {
      context_window_size: (.usage.context_window // 0),
      used_percentage: ((.usage.context_used // 0) * 100),
      current_usage: {input_tokens: (.usage.context_tokens // 0)}
    },
    cost: {
      total_duration_ms: ((.session.started_at | epoch) as $s | if $s then ((now - $s) * 1000 | floor) else 0 end),
      total_lines_added: (.git.changes.additions // 0),
      total_lines_removed: (.git.changes.deletions // 0)
    },
    rate_limits: ({five_hour: (.usage.five_hour | window), seven_day: (.usage.weekly | window)}
                  | with_entries(select(.value != null)))
  },
  ($rs | IN("working", "thinking", "running", "compacting", "compacting context")),
  (now | floor)
')" || exit 2
{ read -r ID; read -r JSON; read -r RUNNING; read -r NOW; } <<< "$OUT"
ID="${ID//\"/}"

# Turn timer in the file format of ~/.claude/turn-timer.sh: "<start> <stop>", stop=0 while working.
if [ -n "$ID" ]; then
  F="${HOME}/.claude/cache/turn-timer/${ID}"
  START=0 STOP=1
  [ -r "$F" ] && read -r START STOP < "$F"
  if [ "$RUNNING" = true ] && [ "$STOP" != 0 ]; then
    [ -d "${F%/*}" ] || mkdir -p "${F%/*}"; echo "$NOW 0" > "$F"
  elif [ "$RUNNING" != true ] && [ "$STOP" = 0 ]; then
    echo "$START $NOW" > "$F"
  fi
fi

STATUSLINE_AGENT=codex exec "${HOME}/.claude/statusline.sh" <<< "$JSON"
