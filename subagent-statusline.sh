#!/usr/bin/env -S jq-jit -rf
# Subagent status line for Claude Code (single jq-jit program).
# stdin:  {columns, tasks: [{id, label, description, status, tokenCount, startTime, ...}]}
# stdout: JSON Lines — one {"id": "...", "content": "..."} per row.

# --- ANSI helpers ---
def green: "[32m";
def cyan:  "[36m";
def red:   "[31m";
def gray:  "[90m";
def reset: "[0m";

# --- Status → {color, icon} ---
# `name` from the docs isn't populated by real payloads; treat `label` as primary.
def status_style:
  if   . == "running"   then {color: green, icon: "…"}
  elif . == "completed" then {color: cyan,  icon: "✓"}
  elif . == "failed"    then {color: red,   icon: "✗"}
  else                       {color: gray,  icon: "○"}
  end;

# --- Tokens: 234 / 61.4k / 234k / 1.2M ---
def fmt_tokens:
  . as $t
  | if   $t < 1000    then "\($t)"
    elif $t < 1000000 then
      ($t / 1000 | floor) as $k_int
      | if $k_int >= 100
        then "\($k_int)k"
        else "\($k_int).\(($t % 1000) / 100 | floor)k"
        end
    else
      ($t / 1000000 | floor) as $m_int
      | "\($m_int).\(($t % 1000000) / 100000 | floor)M"
    end;

# --- Zero-pad to width 2 ---
def pad2:
  tostring | if length == 1 then "0" + . else . end;

# --- Elapsed: " · M:SS" / " · H:MM:SS"; empty when startTime missing ---
# `startTime` is Unix epoch milliseconds.
def fmt_elapsed($now_ms):
  if . == null or . == 0 then ""
  else (($now_ms - .) / 1000 | floor) as $e
       | if $e < 0 then ""
         else ($e / 3600 | floor) as $h
              | (($e % 3600) / 60 | floor) as $m
              | ($e % 60) as $s
              | if $h > 0
                then " · \($h):\($m | pad2):\($s | pad2)"
                else " · \($m):\($s | pad2)"
                end
         end
  end;

# --- Build content string for one task ---
def build_content($now_ms):
  (.status // "" | status_style) as $st
  | (.label // .description // .id // "") as $name
  | (.description // "") as $desc
  | (.tokenCount // 0) as $tokens
  | "\($st.color)\($st.icon)\(reset) \($name)"
  + (if $desc != "" and $desc != $name then " · \($desc)" else "" end)
  + " · \($tokens | fmt_tokens)"
  + (.startTime // 0 | fmt_elapsed($now_ms));

# --- Entry point ---
(now * 1000 | floor) as $now_ms
| .tasks[]?
| {id: .id, content: build_content($now_ms)}
| tojson
