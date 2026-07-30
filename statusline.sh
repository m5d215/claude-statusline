#!/usr/bin/env -S jq-jit -rf
# Powerline status line for Claude Code (single jq-jit program)
# Segments: Model | Directory | Git Branch | Profile | Meters (Context % + Rate Limits)

# --- Icons (Nerd Font) ---
def icons:
  { lc:  "\ue0b6",   # Left round cap
    rc:  "\ue0b4",   # Right round cap
    thin: "\ue0b1",  # Thin separator (same-color boundary)
    git: "\ue0a0",   # Powerline branch
    gh:  "\uf09b",   # nf-fa-github
    gl:  "\uf316",   # nf-md-gitlab
    ctx: "\uf2db",   # nf-fa-microchip
    user: "\uf007" };  # nf-fa-user (profile)

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
    else ($dir | split("/") | last)
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

# --- Format timestamp to local time ---
# Input: ISO string, Unix epoch number, or null; Output: formatted string or empty
def fmt_reset(fmt):
  if . == null or . == "" then ""
  elif type == "number" then try (localtime | strftime(fmt)) catch ""
  else try (fromisodate | localtime | strftime(fmt)) catch ""
  end;

# --- Rate limit part ---
# Output: {pct, label} or null (reset time shown when the part itself is >= 50)
def rate_limit_part($pct; $reset; prefix; fmt):
  if $pct == null then null
  else
    {pct: $pct,
     label: (prefix + ":\($pct)%"
             + (if $pct >= 50 and $reset != null
                then ($reset | fmt_reset(fmt)) as $r
                     | if $r != "" then " \($r)" else "" end
                else "" end))}
  end;

# --- Rate limit parts ---
# Input: root JSON; Output: {p5, p7} (each {pct, label} or null), or null if no rate limits
def rate_limit_parts:
  (.rate_limits.five_hour.used_percentage // null | if . then round else null end) as $rl5h
  | (.rate_limits.seven_day.used_percentage // null | if . then round else null end) as $rl7d
  | if $rl5h == null and $rl7d == null then null
    else
      { p5: rate_limit_part($rl5h; .rate_limits.five_hour.resets_at // null; "5h"; "%H:%M"),
        p7: rate_limit_part($rl7d; .rate_limits.seven_day.resets_at // null; "7d"; "%-m/%-d %H:%M") }
    end;

# --- Profile label (from CLAUDE_CONFIG_DIR) ---
# Output: basename of CLAUDE_CONFIG_DIR, or empty when unset / default (~/.claude)
def profile_label:
  (env.CLAUDE_CONFIG_DIR // "" | rtrimstr("/")) as $ccd
  | env.HOME as $home
  | if $ccd == "" or $ccd == "\($home)/.claude"
    then ""
    else ($ccd | split("/") | last)
    end;

# --- Meter parts: context % and rate limits, rendered as one pill ---
# Input: root JSON; Output: array of {label, c: {bg, fg}}
def meter_parts:
  icons as $i
  | context_pct as $pct
  | ([rate_limit_parts | .p5, .p7]
     | map(select(. != null))
     | map({label, c: (.pct | rate_limit_color)})) as $rls
  | [{label: "\($i.ctx) \($pct)%", c: ($pct | context_color)}] + $rls;

# --- Pill renderer ---
# Input: non-empty array of {label, c: {bg, fg}}; Output: one rounded pill.
# Adjacent same-color parts are joined with a thin separator, different-color
# parts with a right-cap color transition.
def pill:
  icons as $i
  | . as $parts
  | fg($parts[0].c.bg) + $i.lc
  + (reduce $parts[] as $p ({out: "", prev: null};
       if .prev == null
       then {out: (bg($p.c.bg) + fg($p.c.fg) + $p.label), prev: $p.c.bg}
       elif .prev == $p.c.bg
       then {out: (.out + " \($i.thin) \($p.label)"), prev: .prev}
       else {out: (.out + fg(.prev) + bg($p.c.bg) + $i.rc + fg($p.c.fg) + " \($p.label)"),
             prev: $p.c.bg}
       end)
     | .out)
  + rst + fg($parts | last | .c.bg) + $i.rc + rst;

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
  | ($cwd | git_branch) as $branch
  | profile_label as $profile
  | ($cwd | shorten_dir) as $dir_label
  | meter_parts as $meters

  # Segments: single-part pills plus the meters pill
  | [ [{label: $model, c: {bg: 67, fg: 255}}],
      [{label: $dir_label, c: {bg: 238, fg: 252}}],
      (if $branch != "" then [{label: "\($i.git) \($branch)", c: {bg: 73, fg: 234}}] else empty end),
      (if $profile != "" then [{label: "\($i.user) \($profile)", c: {bg: 97, fg: 255}}] else empty end),
      $meters ]
  | map(pill)
  | join(" ");

# --- Entry point ---
build
