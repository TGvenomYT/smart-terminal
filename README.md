# Smart Terminal

A local AI-powered shell assistant for macOS. Type natural language, get shell commands. Everything runs on-device using [Apfel](https://github.com/Arthur-Ficial/apfel) (Apple Intelligence from the command line).

No cloud. No API keys. No telemetry.

## What it does

```bash
? show disk usage by folder
# → du -sh */ 2>/dev/null | sort -hr | head -20

? stop process on port 3000
# → lsof -ti :3000 | xargs kill -9

? run
# → (in a Python project) venv/bin/python3 main_api.py
# → (in a Node project) npm run dev
# → (in a Docker project) docker compose up -d
```

## Features

| Command | Description |
|---------|-------------|
| `? <query>` | Natural language → shell command (confirm before running) |
| `? run` / `? test` / `? build` | Context-aware — adapts to your project type |
| `? setup` | Create venv + install dependencies (auto-detects project) |
| `recall <keyword>` | Recall previously executed commands |
| `explain <error>` | Explain an error message |
| `port <number>` | Show what's using a port |
| `ai <question>` | Chat with local AI (markdown rendered) |
| `summarize <file>` | Summarize PDF, Word, Excel, or PPT documents |
| `git-changes` | Explain the intent behind your code changes |
| `smart-commit` | Generate commit messages from staged changes |
| `ocr-explain` | Screenshot → OCR → AI explanation |

## How it works

1. Your query is checked against a **local command dictionary** (~250+ patterns, instant, deterministic)
2. **Context-aware commands** like `run`, `test`, `build` scan your project files to determine the right command
3. If no dictionary match, falls through to **Apfel LLM** (on-device Apple Intelligence)
4. The command is shown for confirmation before execution
5. Dangerous commands (`rm -rf`, `dd`, etc.) require explicit `y`
6. **Failed commands are auto-explained** inline — no manual step needed

## Requirements

- **macOS 12+** (Apple Silicon or Intel)
- **[Apfel](https://github.com/Arthur-Ficial/apfel)** — Apple Intelligence CLI (required)
- **zsh** — default macOS shell (required)
- **Python 3** — for document summarizer and OCR (optional)
- **[glow](https://github.com/charmbracelet/glow)** — for rendered markdown output (optional, `brew install glow`)

## Install

```bash
git clone https://github.com/TGvenomYT/smart-terminal.git
cd smart-terminal
./install.sh
```

The installer will:
- Check all dependencies and tell you what's missing
- Install files to `~/.smart-terminal/`
- Link CLI tools (`ai`, `git-changes`, `summarize`, `ocr-explain`) to your PATH
- Add source lines to your `~/.zshrc`
- Offer to install Python packages for document summarization

Then reload your shell:

```bash
source ~/.zshrc
```

## Uninstall

```bash
./uninstall.sh
```

Removes everything cleanly — files, symlinks, and the lines added to `.zshrc`.

## Usage

### Natural language commands

```bash
? go to downloads                    # smart path resolution
? devops-agent                       # finds folder anywhere in ~/
? find python files in downloads     # smart file search with location
? find files larger than 200mb       # extracts size from query
? list running docker containers
? docker status
? show my ip address
? battery
? what is on port 8080
? mute                               # macOS volume control
? dark mode on                       # system preferences
? keep mac awake                     # caffeinate
```

### Context-aware project commands

Smart Terminal detects your project type and runs the right command:

```bash
? run       # Python: creates venv if needed, installs deps if found, runs entry point
            # Node: npm run dev  |  Rust: cargo run  |  C/C++: gcc/g++/cmake → run
            # Docker: docker compose up -d  |  Go: go run .
? test      # Python: pytest  |  Node: npm test  |  Rust: cargo test  |  C++: ctest
? build     # Python: python3 -m build  |  Node: npm run build  |  C: gcc  |  C++: cmake/g++
? setup     # Creates venv + installs deps (or npm install, cmake -B build, cargo fetch, etc.)
? lint      # Python: ruff check  |  Node: npm run lint  |  Rust: cargo clippy
? format    # Python: ruff format  |  Node: prettier  |  Rust: cargo fmt
? clean     # Removes build artifacts per project type
? install   # Installs dependencies for the detected project type
```

**Python entry point detection** (checked in order):
1. `pyproject.toml` scripts section
2. `Makefile` run target
3. `Procfile` web entry
4. `ecosystem.config.js` (PM2)
5. `script.sh` run command
6. `README.md` run instructions
7. `docker-compose.yml` command
8. Files with `if __name__ == "__main__"`
9. Common names: main.py, app.py, main_api.py, server.py
10. Only `.py` file in directory (if just one, runs it directly)

**Auto venv handling**:
- No venv + has `requirements.txt` → creates venv, installs deps, runs
- No venv + has `pyproject.toml` → creates venv, installs with `pip install -e .`, runs
- No venv + no deps file → creates venv, runs directly (no pip install)
- Venv already exists → runs with `venv/bin/python3` directly

### Command memory

Every command you run via `?` is saved. Recall them later:

```bash
recall              # show last 10 commands
recall docker       # find commands matching "docker"
recall deploy       # find deploy-related commands
```

### Auto error interception

When a command fails, Smart Terminal automatically explains what went wrong:

```bash
$ npm rn dev
→ Command failed (exit 1). Explaining...
  "rn" is not a valid npm command. Did you mean "npm run dev"?
```

Set `SMART_TERMINAL_AUTO_EXPLAIN=0` in config to disable.

### Document summarizer

```bash
summarize report.pdf                    # default summary
summarize meeting.docx --bullets        # bullet points
summarize data.xlsx --tldr              # 2-3 sentence TL;DR
summarize slides.pptx --actions         # extract action items
summarize report.pdf -p "key risks?"    # custom question
summarize file.pdf --raw                # just extract text
```

Supports: PDF, DOCX, XLSX, PPTX, TXT, MD, CSV

### Git diff explainer

```bash
git-changes              # uncommitted changes
git-changes staged       # staged only
git-changes last         # last commit
git-changes last 3       # last 3 commits
git-changes today        # today's commits
git-changes week         # this week's commits
```

### AI chat

```bash
ai "explain kubernetes"  # single question (markdown rendered)
ai                       # interactive chat mode
```

### OCR Explain

Screenshot any region of your screen, OCR the text, and get an AI explanation:

```bash
ocr-explain              # select screen region interactively
ocr-explain image.png    # OCR an existing image
```

Requires macOS 12+ (uses Apple's Vision framework for OCR). Bind to a hotkey with Hammerspoon, Raycast, or Shortcuts — see `extras/hammerspoon-init.lua`.

### Error explanation

```bash
explain "error: EACCES permission denied"
some-failing-command 2>&1 | explain
explain-last   # re-runs last failed command and explains the error
```

## Configuration

Edit `~/.smart-terminal/config.zsh`:

```bash
# Auto-explain failed commands inline (1 = on, 0 = hint only)
export SMART_TERMINAL_AUTO_EXPLAIN=1

# Suppress "Smart Terminal loaded" startup message
export SMART_TERMINAL_QUIET=0
```

## Adding your own commands

Edit `~/.smart-terminal/custom-commands.zsh`:

```bash
_st_custom_lookup() {
    local q="${(L)1}"
    case "$q" in
        *"deploy staging"*)
            echo "kubectl apply -f k8s/staging/"; return 0 ;;
        *"my project"*)
            echo "cd ~/Projects/myapp && code ."; return 0 ;;
        *"vpn"*)
            echo "open -a 'Cisco AnyConnect'"; return 0 ;;
        *)
            return 1 ;;
    esac
}
```

Custom commands are checked first, so you can override built-in patterns too. This file is never overwritten by updates.

## Hotkey setup (optional)

### Hammerspoon

Copy `extras/hammerspoon-init.lua` to your `~/.hammerspoon/init.lua`:

- `Ctrl+Shift+E` — OCR Explain (screenshot → read → explain)
- `Ctrl+Shift+A` — Ask (natural language prompt → command)

### Raycast

Add `ocr-explain` or `ai` as Script Commands in Raycast preferences.

### macOS Shortcuts (recommended)

Run the setup script to create a Quick Action:

```bash
cd smart-terminal
./extras/setup-shortcut.sh
```

Then assign a hotkey in System Settings → Keyboard → Keyboard Shortcuts → Services → find "OCR Explain" → set `⌃⇧E` (or your preference).

## Built-in command coverage

The dictionary handles ~250+ patterns across:

- **Navigation** — dynamic path resolution, finds folders anywhere in ~/
- **Context-aware** — run, test, build, setup, lint, format, clean (adapts to Python, Node, Rust, Go, C, C++, Java, Ruby, Docker)
- **Docker** — status, start/stop/restart Desktop app, containers, compose, images, logs, prune, exec, stats
- **Ports & Networking** — lsof, kill port, IP, public IP, WiFi, DNS, ping, speed test
- **System** — CPU, RAM, battery, disk, uptime, processes, serial number
- **Files** — find by type/size/date, grep with location, count, compress, permissions, tree
- **Git** — full workflow: status, log, diff, branches, stash, push/pull, blame, tags, create/switch/delete branch
- **Package managers** — brew, npm, pip, venv, cargo
- **Common tasks** — versions, env vars, PATH, history, aliases, node_modules cleanup
- **macOS** — screenshot, lock, sleep, caffeinate, dark mode, volume, bluetooth, brightness, Finder, trash, hidden files, force quit, apps
- **SSH** — generate, show, copy key

Anything not in the dictionary goes to Apfel's on-device model as a fallback.

## How safe is it?

- Commands are **always shown before execution** — you confirm with Enter
- Dangerous patterns (`rm -rf /`, `dd`, `mkfs`, etc.) get a red warning and require explicit `y`
- Everything runs locally — no data leaves your machine
- The LLM fallback uses `--permissive` mode but the dictionary handles most common cases deterministically

## License

MIT
