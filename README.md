# claude-statusline

A Powerline-style status line for [Claude Code](https://claude.ai/code), written as a single [jq-jit](https://github.com/m5d215/jq-jit) program.

## Segments

![catalog](catalog.png)

| Segment | Description |
|---------|-------------|
| Model | Claude model name and context window size |
| Directory | Current working directory (`~/src/github.com/` and `~/src/gitlab.com/` are shortened with icons) |
| Git branch | Current branch (hidden when not in a git repo) |
| Context % | Context window usage — green → yellow → red as it fills |
| Rate limits | 5-hour and 7-day usage with reset time (hidden when no data) |

## Requirements

- macOS (Linux is not currently supported)
- [jq-jit](https://github.com/m5d215/jq-jit) — a jq interpreter with `exec`/`execv` builtins
- [Nerd Font](https://www.nerdfonts.com/) — for Powerline and icon glyphs
- [Claude Code](https://claude.ai/code)

## Installation

**1. Install jq-jit**

```sh
cargo install --git https://github.com/m5d215/jq-jit
```

**2. Download the script**

```sh
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/m5d215/claude-statusline/main/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Or clone this repo and symlink it wherever you like.

**3. Configure Claude Code**

Add to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```

## License

MIT
