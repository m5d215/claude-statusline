#!/usr/bin/env -S jq-jit -rf
# Powerline status line for Claude Code (single jq-jit program)
# Segments: Model | Directory | Git Branch | Context % | Rate Limits

# --- Icons (Nerd Font) ---
def icons:
  { lc:  "\ue0b6",   # Left round cap
    rc:  "\ue0b4",   # Right round cap
    thin: "\ue0b1",  # Thin separator (same-color boundary)
    git: "\ue0a0",   # Powerline branch
    gh:  "\uf09b",   # nf-fa-github
    gl:  "\uf316",   # nf-md-gitlab
    ctx: "\uf2db",   # nf-fa-microchip
    rl:  "\uf074" };  # nf-fa-random (rate limit)

# --- ANSI helpers ---
def fg(n): "\u001b[38;5;\(n)m";
def bg(n): "\u001b[48;5;\(n)m";
def rst:   "\u001b[0m";

# --- Shorten directory path ---
# Input: directory string; Output: display label
def shorten_dir:
  icons as $i
  | . as $dir
  | env.HOME as $home
  | if ($dir | startswith($home))
    then ($dir | ltrimstr($home) | "~" + .) as $short
         | if ($short | test("^~/src/github\\.com/(.+)$"))
           then $i.gh + " " + ($short | capture("^~/src/github\\.com/(?<rest>.+)$").rest)
           elif ($short | test("^~/src/gitlab\\.com/(.+)$"))
           then $i.gl + " " + ($short | capture("^~/src/gitlab\\.com/(?<rest>.+)$").rest)
           else $short
           end
    else $dir
    end;

# --- Git branch detection ---
# Input: directory string; Output: branch name or empty string
def git_branch:
  . as $dir
  | (try (execv("git -C \($dir) rev-parse --git-dir") | .exitcode) catch 1) as $rc
  | if $rc == 0
    then try (exec("git -C \($dir) branch --show-current") | rtrimstr("\n")) catch ""
    else ""
    end;

# --- Context percentage ---
# Input: the root JSON object; Output: integer percentage
def context_pct:
  (.context_window.context_window_size // 200000) as $size
  | (.context_window.current_usage // null) as $usage
  | if $usage != null
    then (($usage.input_tokens // 0)
        + ($usage.cache_creation_input_tokens // 0)
        + ($usage.cache_read_input_tokens // 0)) * 100 / $size | floor
    else 0
    end;

# --- Context color: green -> yellow -> red ---
# Input: percentage; Output: {bg, fg}
def context_color:
  if . >= 50 then {bg: 167, fg: 255}
  elif . >= 20 then {bg: 179, fg: 234}
  else              {bg: 108, fg: 234}
  end;

# --- Rate limit color ---
# Input: max percentage; Output: {bg, fg}
def rate_limit_color:
  if . >= 80 then {bg: 167, fg: 255}
  elif . >= 50 then {bg: 179, fg: 234}
  else              {bg: 108, fg: 234}
  end;

# --- Format ISO timestamp to local time ---
# Input: ISO timestamp string or null; Output: formatted string or empty
def fmt_reset(fmt):
  if . == null or . == "" then ""
  else try (fromisodate | localtime | strftime(fmt)) catch ""
  end;

# --- Rate limit label ---
# Input: root JSON; Output: {label, max} or null if no rate limits
def rate_limit_label:
  icons as $i
  | (.rate_limits.five_hour.used_percentage // null | if . then round else null end) as $rl5h
  | (.rate_limits.seven_day.used_percentage // null | if . then round else null end) as $rl7d
  | (.rate_limits.five_hour.resets_at // null) as $rl5h_reset
  | (.rate_limits.seven_day.resets_at // null) as $rl7d_reset
  | if $rl5h == null and $rl7d == null then null
    else
      ([($rl5h // 0), ($rl7d // 0)] | max) as $rl_max
      # 5h part
      | (if $rl5h != null
         then "5h:\($rl5h)%"
              + (if $rl_max >= 50 and $rl5h_reset != null
                 then ($rl5h_reset | fmt_reset("%H:%M")) as $r
                      | if $r != "" then " \($r)" else "" end
                 else "" end)
         else "" end) as $part5h
      # 7d part
      | (if $rl7d != null
         then "7d:\($rl7d)%"
              + (if $rl_max >= 50 and $rl7d_reset != null
                 then ($rl7d_reset | fmt_reset("%-m/%-d %H:%M")) as $r
                      | if $r != "" then " \($r)" else "" end
                 else "" end)
         else "" end) as $part7d
      # combine
      | (if $part5h != "" and $part7d != ""
         then $part5h + " " + $part7d
         else $part5h + $part7d
         end) as $label
      | {label: $label, max: $rl_max}
    end;

# --- Main builder ---
# Input: root JSON object; Output: formatted Powerline string
def build:
  icons as $i

  # Parse fields
  | (.model.display_name // "?"
     | if test("\\([^)]+ context\\)")
       then capture("(?<base>.*) \\((?<n>[^)]+) context\\)") | "\(.base) \(.n)"
       else . end) as $model
  | (.workspace.current_dir // ".") as $cwd
  | context_pct as $pct
  | ($cwd | git_branch) as $branch
  | ($pct | context_color) as $c4
  | rate_limit_label as $rl

  # Shorten directory (pass cwd through shorten_dir via label/0 trick)
  | ($cwd | shorten_dir) as $dir_label

  # Static colors
  | {c1_bg: 67, c1_fg: 255} as $c1    # Model
  | {c2_bg: 238, c2_fg: 252} as $c2   # Dir
  | {c3_bg: 73, c3_fg: 234} as $c3    # Git

  # pill: left-cap content right-cap (each segment is an independent rounded pill)
  # Segment 1: Model
  | fg($c1.c1_bg) + $i.lc
  + bg($c1.c1_bg) + fg($c1.c1_fg) + "\($model)"
  + rst + fg($c1.c1_bg) + $i.rc + rst

  # Segment 2: Directory
  + " " + fg($c2.c2_bg) + $i.lc
  + bg($c2.c2_bg) + fg($c2.c2_fg) + "\($dir_label)"
  + rst + fg($c2.c2_bg) + $i.rc + rst

  # Segment 3: Git branch (optional)
  + (if $branch != ""
     then " " + fg($c3.c3_bg) + $i.lc
        + bg($c3.c3_bg) + fg($c3.c3_fg) + "\($i.git) \($branch)"
        + rst + fg($c3.c3_bg) + $i.rc + rst
     else ""
     end)

  # Segment 4: Context %
  + " " + fg($c4.bg) + $i.lc
  + bg($c4.bg) + fg($c4.fg) + "\($i.ctx) \($pct)%"
  + rst + fg($c4.bg) + $i.rc + rst

  # Segment 5: Rate limits (optional)
  + (if $rl != null
     then ($rl.max | rate_limit_color) as $c5
        | " " + fg($c5.bg) + $i.lc
        + bg($c5.bg) + fg($c5.fg) + "\($i.rl) \($rl.label)"
        + rst + fg($c5.bg) + $i.rc + rst
     else ""
     end);

# --- Entry point ---
build
