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
# → (Python) python3 -m venv venv && pip install -r requirements.txt && python3 main_api.py
# → (Node) npm run dev
# → (C++) cmake -B build && cmake --build build && ./build/myapp
# → (Docker) docker compose up -d
```

## Features

| Command | Description |
|---------|-------------|
| `? <query>` | Natural language → shell command (confirm before running) |
| `? run` / `? test` / `? build` | Context-aware — adapts to your project type |
| `? setup` | Create venv / cmake build / install deps (auto-detects project) |
| `recall <keyword>` | Recall previously executed commands from memory |
| `explain <error>` | Explain an error message |
| `port <number>` | Show what's using a port |
| `ai <question>` | Chat with local AI (markdown rendered) |
| `summarize <file>` | Summarize PDF, Word, Excel, or PPT documents |
| `git-changes` | Explain the intent behind your code changes |
| `ocr-explain` | Screenshot → OCR → AI explanation |
| `smart-terminal update` | Pull latest version and reinstall |
| `smart-terminal --version` | Show installed version |

## How it works

1. Your query is checked against a **local command dictionary** (~250+ patterns, instant, deterministic)
2. **Context-aware commands** like `run`, `test`, `build` scan your project files to determine the right command
3. If no dictionary match, falls through to **Apfel LLM** (on-device Apple Intelligence)
4. The command is shown for confirmation before execution
5. Dangerous commands (`rm -rf`, `dd`, etc.) require explicit `y`
6. **Failed commands are auto-explained** inline — no manual step needed
7. Every command you run via `?` is **saved to memory** for later recall

## Requirements

- **macOS 12+** (Apple Silicon or Intel)
- **[Apfel](https://github.com/Arthur-Ficial/apfel)** — Apple Intelligence CLI (required)
- **zsh** — default macOS shell (required)
- **Python 3** — for document summarizer (optional)
- **[glow](https://github.com/charmbracelet/glow)** — for rendered markdown output (optional)
- **Xcode Command Line Tools** — for OCR tool compilation and C/C++ support (optional, `xcode-select --install`)

## Install

```bash
git clone https://github.com/TGvenomYT/smart-terminal.git
cd smart-terminal
./install.sh
```

The installer will:
- Check all dependencies and offer to install missing ones via Homebrew
- Compile the native OCR tool (Swift → binary, for fast text extraction)
- Install files to `~/.smart-terminal/`
- Link CLI tools (`ai`, `git-changes`, `summarize`, `ocr-explain`) to your PATH
- Add source lines to your `~/.zshrc`
- Offer to install Python packages for document summarization

Then reload your shell:

```bash
source ~/.zshrc
```

## Update

```bash
smart-terminal update
```

Pulls the latest version from GitHub and reinstalls automatically.

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
? generate ssh key
? empty trash
```

### Context-aware project commands

Smart Terminal detects your project type (Python, Node, C, C++, Rust, Go, Java, Ruby, Docker) and runs the right command:

```bash
? run       # Python: creates venv if needed, installs deps if found, runs entry point
            # Node: npm run dev  |  C: gcc -o a.out main.c && ./a.out
            # C++: cmake -B build && cmake --build build && ./build/<name>
            # Rust: cargo run  |  Go: go run .  |  Docker: docker compose up -d
? test      # Python: pytest  |  Node: npm test  |  Rust: cargo test
            # C++ (CMake): ctest  |  Go: go test ./...
? build     # Python: python3 -m build  |  Node: npm run build
            # C: gcc -o a.out *.c  |  C++: cmake --build build  |  Rust: cargo build
? setup     # Python: python3 -m venv venv + pip install
            # Node: npm install  |  C++ (CMake): cmake -B build
            # Rust: cargo fetch  |  C++ (vcpkg): vcpkg install
? lint      # Python: ruff check  |  Node: npm run lint  |  Rust: cargo clippy
            # C/C++: cppcheck || clang-tidy
? format    # Python: ruff format  |  Node: prettier  |  Rust: cargo fmt
            # C/C++: clang-format
? clean     # Removes build artifacts per project type
? install   # Installs dependencies for the detected project type
```

**Supported project types:**

| Type | Detected by | Run | Build | Setup |
|------|-------------|-----|-------|-------|
| Python | `requirements.txt`, `pyproject.toml`, `Pipfile`, or `.py` files | `python3 <entry>` | `python3 -m build` | `python3 -m venv venv && pip install` |
| Node.js | `package.json` | `npm run dev` / `npm start` | `npm run build` | `npm install` |
| C | `.c` files | `gcc -o a.out && ./a.out` | `gcc -o a.out *.c` | — |
| C++ | `CMakeLists.txt` or `.cpp` files | `cmake → build → run` | `cmake --build build` | `cmake -B build` |
| Rust | `Cargo.toml` | `cargo run` | `cargo build` | `cargo fetch` |
| Go | `go.mod` | `go run .` | `go build ./...` | `go mod download` |
| Java | `pom.xml` / `build.gradle` | `./gradlew run` | `./gradlew build` | `./gradlew build` |
| Ruby | `Gemfile` | `rails server` | — | `bundle install` |
| Docker | `docker-compose.yml` / `Dockerfile` | `docker compose up -d` | `docker compose build` | `docker compose pull && build` |

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

**Auto venv handling** (Python):
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

Uses a precompiled Swift binary (built during install) with Apple's Vision framework. No Python dependencies needed for OCR.

### Error explanation

```bash
explain "error: EACCES permission denied"
some-failing-command 2>&1 | explain
explain-last   # re-runs last failed command and explains the error
```

### Meta commands

```bash
smart-terminal --version    # show installed version
smart-terminal update       # pull latest + reinstall
smart-terminal help         # show all available commands
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

## Built-in command coverage

The dictionary handles ~250+ patterns across:

- **Navigation** — dynamic path resolution, finds folders anywhere in ~/
- **Context-aware** — run, test, build, setup, lint, format, clean (Python, Node, C, C++, Rust, Go, Java, Ruby, Docker)
- **Docker** — status, start/stop/restart Desktop app, containers, compose, images, logs, prune, exec, stats
- **Ports & Networking** — lsof, kill port, IP, public IP, WiFi, DNS, ping, speed test
- **System** — CPU, RAM, battery, disk, uptime, processes, serial number
- **Files** — find by type/size/date, grep with location, count, compress, permissions, tree
- **Git** — full workflow: status, log, diff, branches, stash, push/pull, blame, tags, create/switch/delete branch
- **Package managers** — brew, npm, pip, venv, cargo, cmake, vcpkg, conan
- **Common tasks** — versions, env vars, PATH, history, aliases, node_modules cleanup
- **macOS** — screenshot, lock, sleep, caffeinate, dark mode, volume, bluetooth, brightness, Finder, trash, hidden files, force quit, apps
- **SSH** — generate, show, copy key

Anything not in the dictionary goes to Apfel's on-device model as a fallback.

## How safe is it?

- Commands are **always shown before execution** — you confirm with Enter
- Dangerous patterns (`rm -rf /`, `dd`, `mkfs`, etc.) get a red warning and require explicit `y`
- Everything runs locally — no data leaves your machine
- The LLM fallback uses `--permissive` mode but the dictionary handles most common cases deterministically

## Changelog

### v1.2.0
- **Critical fix:** Single-word commands (`test`, `build`, `install`, `lint`, `docker`, etc.) no longer get hijacked by folder navigation
- **Critical fix:** Auto-explain no longer fires on `?` commands
- Added `--` separator to all apfel calls to handle text with dashes
- OCR uses precompiled Swift binary (fast, reliable)
- C/C++ project support (gcc, g++, cmake, vcpkg, conan)
- Smart Python entry point detection (reads README, ecosystem.config.js, Procfile)
- Auto venv handling skips pip when no deps file exists
- `smart-terminal update` command
- `smart-terminal --version` command
- `recall` command memory
- Auto error interception

### v1.0.0
- Initial release
- ~250+ command dictionary
- Dynamic folder resolution
- Context-aware run/test/build/setup
- Document summarizer
- Git diff explainer
- AI chat with markdown rendering
- OCR Explain
- Auto-install dependencies via Homebrew

## License

MIT
