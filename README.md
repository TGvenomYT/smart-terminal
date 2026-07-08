# Smart Terminal

A local AI-powered shell assistant for macOS. Type natural language, get shell commands. Everything runs on-device using [Apfel](https://github.com/Arthur-Ficial/apfel) (Apple Intelligence from the command line).

No cloud. No API keys. No telemetry.

## What it does

```bash
? show disk usage by folder
# → du -sh */ 2>/dev/null | sort -hr | head -20

? stop process on port 3000
# → lsof -ti :3000 | xargs kill -9

? is docker running
# → docker info 2>/dev/null && echo 'Docker is running' || echo 'Docker is not running'
```

## Features

| Command | Description |
|---------|-------------|
| `? <query>` | Natural language → shell command (confirm before running) |
| `explain <error>` | Explain an error message |
| `port <number>` | Show what's using a port |
| `ai <question>` | Chat with local AI (markdown rendered) |
| `summarize <file>` | Summarize PDF, Word, Excel, or PPT documents |
| `git-changes` | Explain the intent behind your code changes |
| `smart-commit` | Generate commit messages from staged changes |
| `explain-last` | Explain why the last command failed |

## How it works

1. Your query is checked against a **local command dictionary** (instant, deterministic, correct)
2. If no match, it falls through to the **Apfel LLM** (on-device Apple Intelligence)
3. The command is shown to you for confirmation before execution
4. Dangerous commands (`rm -rf`, `dd`, etc.) require explicit `y`

## Requirements

- **macOS** (Apple Silicon or Intel)
- **[Apfel](https://github.com/Arthur-Ficial/apfel)** — Apple Intelligence CLI (required)
- **zsh** — default macOS shell (required)
- **Python 3** — for document summarizer (optional)
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
- Link CLI tools (`ai`, `git-changes`, `summarize`) to your PATH
- Add two lines to your `~/.zshrc`
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
? go to downloads
? find files larger than 100mb
? list running docker containers
? stop all docker containers
? docker status
? show my ip address
? battery
? what is on port 8080
? recent commits
? show cpu usage
```

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
ai "explain kubernetes"  # single question
ai                       # interactive chat mode
```

### Error explanation

```bash
explain "error: EACCES permission denied"
some-failing-command 2>&1 | explain
explain-last   # re-runs last failed command and explains the error
```

## Configuration

Edit `~/.smart-terminal/config.zsh`:

```bash
# Show hint when commands fail (set to 0 to disable)
export SMART_TERMINAL_AUTO_EXPLAIN=1

# Suppress startup message
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

## Built-in command coverage

The dictionary handles ~150 patterns across:

- **Navigation** — cd to common folders, go back, open in Finder
- **Docker** — status, start/stop/restart, containers, compose, images, logs, prune
- **Ports & Networking** — lsof, IP, public IP, WiFi, DNS, ping
- **System** — CPU, RAM, battery, disk, uptime, processes
- **Files** — find, grep, count, compress, permissions
- **Git** — status, log, diff, branches, stash, push/pull
- **Brew** — update, install, list, search
- **Common tasks** — versions, env vars, PATH, history, node_modules cleanup
- **macOS** — screenshot, lock, sleep, caffeinate, Finder, trash, hidden files

Anything not in the dictionary goes to Apfel's on-device model as a fallback.

## How safe is it?

- Commands are **always shown before execution** — you confirm with Enter
- Dangerous patterns (`rm -rf /`, `dd`, `mkfs`, etc.) get a red warning and require explicit `y`
- Everything runs locally — no data leaves your machine
- The LLM fallback uses `--permissive` mode but the dictionary handles most common cases deterministically

## License

MIT
