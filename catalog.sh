#!/usr/bin/env bash
# shellcheck disable=SC2016

set -Ceuo pipefail

show() {
  printf "%s# %s%s\n" $'\e[2m' "$1" $'\e[0m'
  jq-jit -nc "$2" | ./statusline.sh
  echo
}

# --- Context color zones ---
show 'context: green (<20%)' '{
    model: {
        "display_name": "Opus 4.6 (1M context)"
    },
    workspace: {
        current_dir: "\(env.HOME)/src/github.com/m5d215/claude-statusline"
    },
    context_window: {
        context_window_size: 1000000,
        current_usage: {
            input_tokens: 50000
        }
    }
}'

show 'context: yellow (20-49%)' '{
    model: {
        "display_name": "Opus 4.6 (1M context)"
    },
    workspace: {
        current_dir: "\(env.HOME)/src/github.com/m5d215/claude-statusline"
    },
    context_window: {
        context_window_size: 1000000,
        current_usage: {
            input_tokens: 250000
        }
    }
}'

show 'context: red (50%+)' '{
    model: {
        "display_name": "Opus 4.6 (1M context)"
    },
    workspace: {
        current_dir: "\(env.HOME)/src/github.com/m5d215/claude-statusline"
    },
    context_window: {
        context_window_size: 1000000,
        current_usage: {
            input_tokens: 550000
        }
    }
}'

# --- Rate limit color zones ---
show 'rate limit: green (<50%)' '{
    model: {
        "display_name": "Opus 4.6 (1M context)"
    },
    workspace: {
        current_dir: "\(env.HOME)/src/github.com/m5d215/claude-statusline"
    },
    context_window: {
        context_window_size: 1000000,
        current_usage: {
            input_tokens: 50000
        }
    },
    rate_limits: {
        five_hour: {
            used_percentage: 30,
            resets_at: (now + 3*3600 | floor)
        }
    }
}'

show 'rate limit: yellow (50-79%), both 5h+7d' '{
    model: {
        "display_name": "Opus 4.6 (1M context)"
    },
    workspace: {
        current_dir: "\(env.HOME)/src/github.com/m5d215/claude-statusline"
    },
    context_window: {
        context_window_size: 1000000,
        current_usage: {
            input_tokens: 50000
        }
    },
    rate_limits: {
        five_hour: {
            used_percentage: 25.3,
            resets_at: (now + 3*3600 | floor)
        },
        seven_day: {
            used_percentage: 62.7,
            resets_at: (now + 3*86400 | floor)
        }
    }
}'

show 'rate limit: red (80%+)' '{
    model: {
        "display_name": "Opus 4.6 (1M context)"
    },
    workspace: {
        current_dir: "\(env.HOME)/src/github.com/m5d215/claude-statusline"
    },
    context_window: {
        context_window_size: 1000000,
        current_usage: {
            input_tokens: 50000
        }
    },
    rate_limits: {
        seven_day: {
            used_percentage: 92,
            resets_at: (now + 3*86400 | floor)
        }
    }
}'

# --- Directory variations ---

show 'dir: github' '{
    model: {
        "display_name": "Opus 4.6 (1M context)"
    },
    workspace: {
        current_dir: "\(env.HOME)/src/github.com/m5d215/claude-statusline"
    },
    context_window: {
        context_window_size: 1000000,
        current_usage: {
            input_tokens: 50000
        }
    }
}'

show 'dir: gitlab' '{
    model: {
        "display_name": "Opus 4.6 (1M context)"
    },
    workspace: {
        current_dir: "\(env.HOME)/src/gitlab.com/m5d215/claude-statusline"
    },
    context_window: {
        context_window_size: 1000000,
        current_usage: {
            input_tokens: 50000
        }
    }
}'

show 'dir: home' '{
    model: {
        "display_name": "Opus 4.6 (1M context)"
    },
    workspace: {
        current_dir: "\(env.HOME)"
    },
    context_window: {
        context_window_size: 200000,
        current_usage: {
            input_tokens: 10000
        }
    }
}'

show 'dir: non-git (/tmp)' '{
    model: {
        "display_name": "Haiku 4.5 (200K context)"
    },
    workspace: {
        current_dir: "/tmp"
    },
    context_window: {
        context_window_size: 200000,
        current_usage: {
            input_tokens: 10000
        }
    }
}'

# --- Edge cases ---

show 'minimal: all fields missing' '{}'

show 'no context usage' '{
    model: {
        "display_name": "Opus 4.6 (1M context)"
    },
    workspace: {
        current_dir: "\(env.HOME)"
    },
    context_window: {
        context_window_size: 1000000
    }
}'
